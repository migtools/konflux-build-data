# Builder image
FROM registry.redhat.io/ubi9/nodejs-20:1-1758500456 AS builder
COPY --chown=1001:0 . /workspace
WORKDIR /workspace/ui

# Setup downstream branding (before https://github.com/konveyor/tackle2-ui/pull/1664)
ENV PROFILE=mta
ENV BRAND_TYPE=RedHat

# Setup the build to use downstream branding (after https://github.com/konveyor/tackle2-ui/pull/1664)
ENV BRANDING=../branding-mta

# Allow use of npm10 (see https://github.com/konveyor/tackle2-ui/pull/1781)
RUN sed -i 's/^    "npm": "^9.5.0"/    "npm": ">=9.5.0"/' package.json

# npm config fix is needed for npm9/nodejs18 auth issues during build
RUN npm config fix
RUN npm clean-install --ignore-scripts --no-audit --verbose && npm run build && npm run dist

# Runner image
#@follow_tag(registry.redhat.io/ubi9/nodejs-20-minimal:latest)
FROM registry.redhat.io/ubi9/nodejs-20-minimal:1-1758213568
USER root
RUN microdnf -y update && microdnf -y clean all
RUN microdnf -y install tar procps-ng && microdnf -y clean all
USER 1001

COPY --from=builder /workspace/ui/dist /opt/app-root/dist/
COPY --from=builder /workspace/ui/LICENSE /licenses/

LABEL \
        com.redhat.component="mta-ui-container" \
        version="$CI_VERSION" \
        name="mta/mta-ui-rhel9" \
        license="Apache License 2.0" \
        io.k8s.display-name="MTA - UI" \
        io.k8s.description="Migration Toolkit for Applications - UI" \
        io.openshift.tags="migration,modernization,mta,tackle,konveyor" \
        io.openshift.build.commit.id="${CI_TACKLE2_UI_UPSTREAM_COMMIT}" \
        io.openshift.build.source-location="${CI_TACKLE2_UI_UPSTREAM_URL}" \
        io.openshift.build.commit.url="https://github.com/konveyor/tackle2-ui/commit/${CI_TACKLE2_UI_UPSTREAM_COMMIT}" \
        summary="Migration Toolkit for Applications - UI" \
        maintainer="Migration Toolkit for Applications Team <migtoolkit-team@redhat.com>" \
        build.commit.urls="${CI_TACKLE2_UI_UPSTREAM_URL}/commit/${CI_TACKLE2_UI_UPSTREAM_COMMIT}"

WORKDIR /opt/app-root/dist
ENTRYPOINT ["./entrypoint.sh"]
