FROM registry.redhat.io/ubi9/nodejs-20:latest AS builder
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

FROM registry.redhat.io/ubi9/nodejs-20-minimal:latest
USER root
RUN microdnf -y install procps-ng && microdnf -y clean all
USER 1001

COPY --from=builder /workspace/ui/dist /opt/app-root/dist/
COPY --from=builder /workspace/ui/LICENSE /licenses/

WORKDIR /opt/app-root/dist
ENTRYPOINT ["./entrypoint.sh"]
