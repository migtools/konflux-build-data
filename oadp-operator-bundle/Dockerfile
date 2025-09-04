FROM registry.redhat.io/ubi9/python-312:latest@sha256:83b01cf47b22e6ce98a0a4802772fb3d4b7e32280e3a1b7ffcd785e01956e1cb AS builder-runner
RUN pip3 install ruamel.yaml
# ############################################################################ #

FROM builder-runner AS builder
USER root
#COPY oadp-annotations.cfg oadp-csv.cfg pre-build-script.cfg relatedImages.yml update_csv_bundle.py /workspace/
COPY . /workspace/
COPY oadp-operator/bundle/manifests/ /workspace/manifests/
COPY oadp-operator/bundle/metadata/ /workspace/metadata/
WORKDIR /workspace/
RUN ./update_csv_bundle.py \
        --related-images relatedImages.yml \
        --csv-config oadp-csv.cfg \
        --upstream-csv manifests/oadp-operator.clusterserviceversion.yaml \
        --annotations-config oadp-annotations.cfg \
        --upstream-annotations metadata/annotations.yaml
USER default
# ############################################################################ #

FROM scratch

COPY --from=builder /workspace/manifests/ /manifests/
COPY --from=builder /workspace/metadata/ /metadata/

# These are three labels needed to control how the pipeline should handle this container image
# This first label tells the pipeline that this is a bundle image and should be
# delivered via an index image
LABEL com.redhat.delivery.operator.bundle=true

# This second label tells the pipeline which versions of OpenShift the operator supports.
# This is used to control which index images should include this operator.
LABEL com.redhat.openshift.versions="=v4.13|=v4.14|=v4.15|=v4.16|=v4.17|=v4.18"

# This third label tells the pipeline that this operator should *also* be supported on OCP 4.4 and
# earlier.  It is used to control whether or not the pipeline should attempt to automatically
# backport this content into the old appregistry format and upload it to the quay.io application
# registry endpoints.
LABEL com.redhat.delivery.backport=false


LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=redhat-oadp-operator
#LABEL operators.operatorframework.io.bundle.channels.v1=stable
#LABEL operators.operatorframework.io.bundle.channel.default.v1=stable
LABEL operators.operatorframework.io.bundle.channels.v1=stable-1.4
LABEL operators.operatorframework.io.bundle.channel.default.v1=stable-1.4

LABEL operators.operatorframework.io.metrics.builder=operator-sdk-v1.14.0
LABEL operators.operatorframework.io.metrics.mediatype.v1=metrics+v1
LABEL operators.operatorframework.io.metrics.project_layout=go.kubebuilder.io/v3

# Labels for testing.
LABEL operators.operatorframework.io.test.mediatype.v1=scorecard+v1
LABEL operators.operatorframework.io.test.config.v1=tests/scorecard/

# Main labels
LABEL \
        com.redhat.component="oadp-operator-bundle-container" \
        version="1.4.6" \
        name="oadp/oadp-operator-bundle" \
        License="Apache License 2.0" \
        io.k8s.display-name="OADP Operator" \
        io.openshift.tags="migration" \
        io.k8s.description="OpenShift API for Data Protection - Operator Bundle" \
        summary="OpenShift API for Data Protection - Operator Bundle" \
        maintainer="Migration Toolkit for Containers Team <migtoolkit-team@redhat.com>"
