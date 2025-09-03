#!/usr/bin/env python3
"""
Update OADP CSV Bundle for Konflux Hermetic Builds

This script updates an OADP operator CSV file with image references from relatedImages.yml
for use in hermetic/isolated build environments. It reads the relatedImages.yml file
and directly overwrites values in the existing "upstream" CSV with Konflux values.

Similar to render_templates but designed for hermetic environments where we cannot
fetch build information from external sources and must rely on values in relatedImages.yml.
"""

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path
from ruamel.yaml import YAML


class OADPCSVUpdater:
    """
    Updates OADP CSV files with values from relatedImages.yml for Konflux hermetic builds.
    """

    def __init__(self, verbose=False):
        self.verbose = verbose
        # Initialize YAML loader with formatting preservation
        self.yaml = YAML()
        self.yaml.preserve_quotes = True
        self.yaml.width = 4096
        self.yaml.default_flow_style = False

    def log(self, message):
        """Print message if verbose mode is enabled."""
        if self.verbose:
            print(f"[INFO] {message}")

    def normalize_name(self, name):
        """
        Normalize image names by converting hyphens to underscores.
        This helps match upstream CSV names (with hyphens) to relatedImages.yml names (with underscores).

        Example: 'kubevirt-velero-plugin' -> 'kubevirt_velero_plugin'
        """
        return name.replace("-", "_")

    def create_related_image_entry(self, name, image):
        """
        Create a relatedImages entry with proper field ordering (name first, image second).
        This ensures consistency with downstream legacy and current production formats.
        """
        # Use regular dict instead of OrderedDict to avoid !!omap serialization
        # The ruamel.yaml library will preserve the insertion order for regular dicts in Python 3.7+
        entry = {"name": name, "image": image}
        return entry

    def load_related_images(self, related_images_file):
        """
        Load relatedImages.yml and build mapping dictionaries.

        Expected format:
        - name: operator
          image: quay.io/redhat-user-workloads/...
          env_var: RELATED_IMAGE_OPERATOR
        """
        self.log(f"Loading relatedImages from: {related_images_file}")

        with open(related_images_file, "r") as f:
            # Use ruamel.yaml safe loader instead of standard yaml library
            yaml_loader = YAML(typ="safe")
            related_images = yaml_loader.load(f)

        # Build mapping dictionaries
        image_map = {}  # name -> image
        env_var_map = {}  # env_var -> image
        normalized_name_map = {}  # normalized_name -> original_name (for reverse lookup)

        for item in related_images:
            name = item["name"]
            image = item["image"]
            env_var = item.get("env_var", "")

            image_map[name] = image
            if env_var:
                env_var_map[env_var] = image

            # Build reverse lookup for normalized names
            normalized_name = self.normalize_name(name)
            normalized_name_map[normalized_name] = name

        self.log(f"Loaded {len(image_map)} image mappings and {len(env_var_map)} env var mappings")
        return image_map, env_var_map, normalized_name_map

    def load_csv_manifest(self, csv_file):
        """Load CSV YAML file preserving formatting."""
        if not csv_file.endswith(".yaml"):
            raise ValueError(f"CSV file must have .yaml extension: {csv_file}")

        try:
            with open(csv_file, "r") as f:
                return self.yaml.load(f)
        except FileNotFoundError:
            raise FileNotFoundError(f"CSV file not found: {csv_file}")
        except Exception as e:
            raise RuntimeError(f"Error loading CSV file {csv_file}: {e}")

    def dump_csv_manifest(self, csv_data, output_file):
        """Save CSV YAML file preserving formatting."""
        # Ensure output directory exists
        output_dir = os.path.dirname(output_file)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        with open(output_file, "w") as f:
            self.yaml.dump(csv_data, f)

        self.log(f"Saved updated CSV to: {output_file}")

    def update_created_at_timestamp(self, csv_data):
        """
        Update the createdAt annotation with current timestamp.
        Similar to render_templates format: YYYY-MM-DDTHH:MM:SSZ
        """
        now = datetime.now()
        # Format similar to render_templates
        timestamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")

        # Ensure metadata structure exists
        if "metadata" not in csv_data:
            csv_data["metadata"] = {}
        if "annotations" not in csv_data["metadata"]:
            csv_data["metadata"]["annotations"] = {}

        old_timestamp = csv_data["metadata"]["annotations"].get("createdAt", "None")
        csv_data["metadata"]["annotations"]["createdAt"] = timestamp

        print(f"Updated createdAt timestamp: {old_timestamp} -> {timestamp}")

    def update_related_images_section(self, csv_data, image_map, normalized_name_map):
        """
        Update the spec.relatedImages section with new image values.
        This directly overwrites the values from the upstream CSV with our Konflux values.
        If spec.relatedImages doesn't exist, create it with our values.

        Handles name transformation from hyphens to underscores to match relatedImages.yml format.
        """
        # Ensure spec section exists
        if "spec" not in csv_data:
            csv_data["spec"] = {}

        # Check if relatedImages section exists
        if "relatedImages" not in csv_data["spec"]:
            print(
                "Warning: No spec.relatedImages section found in CSV - creating it with relatedImages values"
            )
            csv_data["spec"]["relatedImages"] = []

            # Create relatedImages entries from our image_map with proper field ordering
            for name, image in image_map.items():
                entry = self.create_related_image_entry(name, image)
                csv_data["spec"]["relatedImages"].append(entry)
            print(f"Created spec.relatedImages section with {len(image_map)} entries")
            return

        related_images = csv_data["spec"]["relatedImages"]
        updated_count = 0

        for item in related_images:
            upstream_name = item.get("name", "")
            matched_name = None
            new_image = None

            # First try direct match
            if upstream_name in image_map:
                matched_name = upstream_name
                new_image = image_map[upstream_name]
                self.log(f"Direct match found for '{upstream_name}'")
            else:
                # Try normalized match (hyphen to underscore)
                normalized_upstream_name = self.normalize_name(upstream_name)
                if normalized_upstream_name in normalized_name_map:
                    # Found a match via normalization
                    matched_name = normalized_name_map[normalized_upstream_name]
                    new_image = image_map[matched_name]
                    self.log(f"Normalized match found: '{upstream_name}' -> '{matched_name}'")

            if matched_name and new_image:
                old_image = item.get("image", "")
                if old_image != new_image or upstream_name != matched_name:
                    print(f"  Updating relatedImage '{upstream_name}':")
                    print(f"    FROM: {old_image}")
                    print(f"    TO:   {new_image}")

                    # Create a new properly ordered entry
                    final_name = matched_name  # Use the matched name (normalized if needed)
                    new_entry = self.create_related_image_entry(final_name, new_image)

                    # Replace the item with the new properly ordered entry
                    item.clear()
                    item.update(new_entry)

                    # If we matched via normalization, show the name change
                    if upstream_name != matched_name:
                        print(f"    NAME: {upstream_name} -> {matched_name} (normalized)")

                    updated_count += 1
                else:
                    self.log(f"  relatedImage '{upstream_name}' already has correct value")
            else:
                self.log(f"  No match found for relatedImage '{upstream_name}'")

        print(f"Updated {updated_count} relatedImages entries")

    def update_environment_variables(self, csv_data, env_var_map):
        """
        Update RELATED_IMAGE_* environment variables in the deployment spec.
        This updates the container environment variables with our Konflux image values.
        """
        try:
            # Navigate to the container environment variables
            deployments = csv_data["spec"]["install"]["spec"]["deployments"]
            if not deployments:
                print("Warning: No deployments found in CSV")
                return

            containers = deployments[0]["spec"]["template"]["spec"]["containers"]
            if not containers:
                print("Warning: No containers found in deployment")
                return

            # Find the manager container (usually the first one with env vars)
            manager_container = None
            for container in containers:
                if "env" in container:
                    manager_container = container
                    break

            if not manager_container:
                print("Warning: No container with environment variables found")
                return

            env_vars = manager_container["env"]
            updated_count = 0

            for env_var in env_vars:
                env_name = env_var.get("name", "")
                if env_name in env_var_map:
                    old_value = env_var.get("value", "")
                    new_value = env_var_map[env_name]
                    if old_value != new_value:
                        print(f"  Updating env var '{env_name}':")
                        print(f"    FROM: {old_value}")
                        print(f"    TO:   {new_value}")
                        env_var["value"] = new_value
                        updated_count += 1
                    else:
                        self.log(f"  env var '{env_name}' already has correct value")

            print(f"Updated {updated_count} environment variables")

        except (KeyError, IndexError) as e:
            print(f"Error navigating CSV structure for environment variables: {e}")

    def update_container_image_annotation(self, csv_data, image_map):
        """
        Update the containerImage annotation with operator image.
        """
        # Look for operator or manager image
        operator_image = image_map.get("operator") or image_map.get("manager")
        if not operator_image:
            print("Warning: No operator or manager image found for containerImage annotation")
            return

        # Ensure metadata structure exists
        if "metadata" not in csv_data:
            csv_data["metadata"] = {}
        if "annotations" not in csv_data["metadata"]:
            csv_data["metadata"]["annotations"] = {}

        old_image = csv_data["metadata"]["annotations"].get("containerImage", "None")
        csv_data["metadata"]["annotations"]["containerImage"] = operator_image

        print(f"Updated containerImage annotation:")
        print(f"  FROM: {old_image}")
        print(f"  TO:   {operator_image}")

    def update_deployment_container_image(self, csv_data, image_map):
        """
        Update the main container image in the deployment spec.
        """
        operator_image = image_map.get("operator") or image_map.get("manager")
        if not operator_image:
            print("Warning: No operator or manager image found for deployment container")
            return

        try:
            containers = csv_data["spec"]["install"]["spec"]["deployments"][0]["spec"]["template"]["spec"][
                "containers"
            ]
            if containers:
                old_image = containers[0].get("image", "None")
                containers[0]["image"] = operator_image
                print(f"Updated deployment container image:")
                print(f"  FROM: {old_image}")
                print(f"  TO:   {operator_image}")
        except (KeyError, IndexError) as e:
            print(f"Error updating deployment container image: {e}")

    def update_must_gather_annotation(self, csv_data, image_map):
        """
        Update the must-gather image annotation if available.
        """
        mustgather_image = image_map.get("mustgather") or image_map.get("oadp_mustgather")
        if not mustgather_image:
            self.log("No mustgather image found, skipping must-gather annotation update")
            return

        # Ensure metadata structure exists
        if "metadata" not in csv_data:
            csv_data["metadata"] = {}
        if "annotations" not in csv_data["metadata"]:
            csv_data["metadata"]["annotations"] = {}

        annotation_key = "operators.openshift.io/must-gather-image"
        old_image = csv_data["metadata"]["annotations"].get(annotation_key, "None")
        csv_data["metadata"]["annotations"][annotation_key] = mustgather_image

        print(f"Updated must-gather annotation:")
        print(f"  FROM: {old_image}")
        print(f"  TO:   {mustgather_image}")

    def apply_csv_config_changes(self, csv_data, csv_config_file, image_map):
        """
        Apply additional CSV configuration changes from oadp-csv.cfg file.
        This file contains Python code that modifies the CSV structure directly.
        """
        if not os.path.exists(csv_config_file):
            self.log(f"CSV config file not found: {csv_config_file}, skipping config changes")
            return

        print(f"Applying additional CSV configuration changes from: {csv_config_file}")

        # Read the configuration file
        with open(csv_config_file, "r") as f:
            config_code = f.read()

        # Create a local context with the CSV data and image map
        # This mimics the pattern used in migint-release-tools
        yd = csv_data  # yd is the variable name used in the config files

        # Make image map available for potential use in config
        # (though current configs don't use it directly)
        locals_dict = {"yd": yd, "image_map": image_map}

        try:
            # Execute the configuration code
            exec(config_code, {}, locals_dict)
            print(f"Successfully applied CSV configuration changes")
            self.log(f"Config code executed: {config_code.strip()}")
        except Exception as e:
            print(f"Error applying CSV configuration changes: {e}")
            self.log(f"Failed config code: {config_code}")
            raise

    def apply_annotations_config_changes(self, annotations_data, annotations_config_file, image_map):
        """
        Apply additional annotations configuration changes from annotations config file.
        This file contains Python code that modifies the annotations structure directly.
        """
        if not os.path.exists(annotations_config_file):
            self.log(
                f"Annotations config file not found: {annotations_config_file}, skipping config changes"
            )
            return

        print(f"Applying additional annotations configuration changes from: {annotations_config_file}")

        # Read the configuration file
        with open(annotations_config_file, "r") as f:
            config_code = f.read()

        # Create a local context with the annotations data and image map
        # This mimics the pattern used in migint-release-tools
        yd = annotations_data  # yd is the variable name used in the config files

        # Make image map available for potential use in config
        locals_dict = {"yd": yd, "image_map": image_map}

        try:
            # Execute the configuration code
            exec(config_code, {}, locals_dict)
            print(f"Successfully applied annotations configuration changes")
            self.log(f"Config code executed: {config_code.strip()}")
        except Exception as e:
            print(f"Error applying annotations configuration changes: {e}")
            self.log(f"Failed config code: {config_code}")
            raise

    def update_csv(
        self,
        related_images_file,
        upstream_csv,
        output_csv,
        csv_config_file=None,
        upstream_annotations=None,
        output_annotations=None,
        annotations_config_file=None,
        dry_run=False,
    ):
        """
        Main method to update CSV file with relatedImages values.
        """
        # Validate input files
        if not os.path.exists(related_images_file):
            raise FileNotFoundError(f"relatedImages file not found: {related_images_file}")

        if not os.path.exists(upstream_csv):
            raise FileNotFoundError(f"upstream CSV file not found: {upstream_csv}")

        # Load data
        image_map, env_var_map, normalized_name_map = self.load_related_images(related_images_file)
        csv_data = self.load_csv_manifest(upstream_csv)

        if dry_run:
            print("DRY RUN MODE - No changes will be made")
            print(f"Would process {len(image_map)} images and {len(env_var_map)} env vars")
            if upstream_annotations:
                print(f"Would also process annotations file: {upstream_annotations}")
                if annotations_config_file:
                    print(f"Would apply annotations config from: {annotations_config_file}")
            return

        print("\n" + "=" * 80)
        print("UPDATING OADP CSV FILE FOR KONFLUX HERMETIC BUILD")
        print("=" * 80)

        # Perform updates
        print("\n1. Updating createdAt timestamp:")
        self.update_created_at_timestamp(csv_data)

        print("\n2. Updating spec.relatedImages section:")
        self.update_related_images_section(csv_data, image_map, normalized_name_map)

        print("\n3. Updating RELATED_IMAGE_* environment variables:")
        self.update_environment_variables(csv_data, env_var_map)

        print("\n4. Updating containerImage annotation:")
        self.update_container_image_annotation(csv_data, image_map)

        print("\n5. Updating deployment container image:")
        self.update_deployment_container_image(csv_data, image_map)

        print("\n6. Updating must-gather annotation:")
        self.update_must_gather_annotation(csv_data, image_map)

        # Apply additional CSV configuration changes if config file is provided
        if csv_config_file:
            print("\n7. Applying additional CSV configuration changes:")
            self.apply_csv_config_changes(csv_data, csv_config_file, image_map)
            step_num = 8
        else:
            step_num = 7

        # Process annotations if provided
        if upstream_annotations:
            print(f"\n{step_num}. Processing annotations file:")
            if not os.path.exists(upstream_annotations):
                raise FileNotFoundError(f"upstream annotations file not found: {upstream_annotations}")

            # Load annotations data
            annotations_data = self.load_csv_manifest(upstream_annotations)

            # Apply annotations configuration changes if config file is provided
            if annotations_config_file:
                print(f"\n{step_num + 1}. Applying additional annotations configuration changes:")
                self.apply_annotations_config_changes(annotations_data, annotations_config_file, image_map)

            # Save the updated annotations
            print(f"\n{step_num + 2}. Saving updated annotations to: {output_annotations}")
            self.dump_csv_manifest(annotations_data, output_annotations)
            step_num += 3

        # Save the updated CSV
        print(f"\n{step_num}. Saving updated CSV to: {output_csv}")
        self.dump_csv_manifest(csv_data, output_csv)

        print("\n" + "=" * 80)
        print("CSV UPDATE COMPLETED SUCCESSFULLY!")
        print(f"Processed {len(image_map)} image mappings and {len(env_var_map)} env var mappings")
        print("=" * 80)


def main():
    parser = argparse.ArgumentParser(
        description="Update OADP CSV file with values from relatedImages.yml for Konflux hermetic builds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage (overwrites upstream CSV file directly)
  %(prog)s --related-images relatedImages.yml --upstream-csv upstream.csv

  # Basic usage with separate output file
  %(prog)s --related-images relatedImages.yml --upstream-csv upstream.csv --output-csv output.csv

  # Full paths example with CSV config (overwrites upstream CSV)
  %(prog)s \\
    --related-images relatedImages.yml \\
    --csv-config oadp-csv.cfg \\
    --upstream-csv bundle/manifests/oadp-operator.clusterserviceversion.yaml

  # Process both CSV and annotations files
  %(prog)s \\
    --related-images relatedImages.yml \\
    --upstream-csv bundle/manifests/oadp-operator.clusterserviceversion.yaml \\
    --upstream-annotations bundle/metadata/annotations.yaml \\
    --annotations-config annotations.cfg

  # Dry run to see what would be changed
  %(prog)s --related-images relatedImages.yml --upstream-csv upstream.csv --dry-run
        """,
    )
    parser.add_argument(
        "--related-images", required=True, help="Path to relatedImages.yml file containing image mappings"
    )
    parser.add_argument("--upstream-csv", required=True, help="Path to upstream CSV file to update")
    parser.add_argument(
        "--output-csv", help="Path to output CSV file (defaults to upstream-csv if not provided)"
    )
    parser.add_argument(
        "--csv-config",
        help="Path to oadp-csv.cfg file with additional CSV configuration changes (optional)",
    )
    parser.add_argument(
        "--upstream-annotations", help="Path to upstream annotations file to process (optional)"
    )
    parser.add_argument(
        "--output-annotations",
        help="Path to output annotations file (defaults to upstream-annotations if not provided)",
    )
    parser.add_argument(
        "--annotations-config",
        help="Path to annotations config file with additional annotations configuration changes (optional)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Show what would be updated without making changes"
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose output")

    args = parser.parse_args()

    # Default output_csv to upstream_csv if not provided
    if not args.output_csv:
        args.output_csv = args.upstream_csv
        print(f"No --output-csv provided, using upstream CSV file: {args.output_csv}")

    # Default output_annotations to upstream_annotations if not provided
    if args.upstream_annotations and not args.output_annotations:
        args.output_annotations = args.upstream_annotations
        print(
            f"No --output-annotations provided, using upstream annotations file: {args.output_annotations}"
        )

    try:
        # updater = OADPCSVUpdater(verbose=args.verbose)
        updater = OADPCSVUpdater(verbose=True)
        updater.update_csv(
            args.related_images,
            args.upstream_csv,
            args.output_csv,
            csv_config_file=args.csv_config,
            upstream_annotations=args.upstream_annotations,
            output_annotations=args.output_annotations,
            annotations_config_file=args.annotations_config,
            dry_run=args.dry_run,
        )
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
