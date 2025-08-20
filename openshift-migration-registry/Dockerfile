#@follow_tag(registry-proxy.engineering.redhat.com/rh-osbs/openshift-golang-builder:rhel_8_golang_1.23)
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_golang_1.23 AS builder
ENV DISTRIBUTION_DIR /go/src/github.com/docker/distribution
ARG GOOS=linux
ARG GOARCH=amd64
ARG GOARM=6
ARG VERSION
ARG REVISION
WORKDIR /workspace
COPY . .
COPY distribution/ /workspace/src/github.com/docker/distribution
WORKDIR /workspace/src/github.com/docker/distribution
ENV DISTRIBUTION_DIR /workspace/src/github.com/docker/distribution
USER root
RUN dnf -y install make git file
RUN chown -R 1001:0 /workspace/
USER 1001
ENV GOEXPERIMENT strictfipsruntime
ENV GO_BUILD_FLAGS=" -mod=readonly "
ENV BUILDTAGS=" include_oss include_gcs strictfipsruntime "
RUN CGO_ENABLED=1 make PREFIX=/go clean binaries

#@follow_tag(registry.redhat.io/ubi8/ubi-minimal)
FROM registry.redhat.io/ubi8/ubi-minimal:latest
RUN microdnf -y install httpd-tools && microdnf clean all
COPY --from=builder /workspace/src/github.com/docker/distribution/cmd/registry/config-dev.yml /etc/docker/registry/config.yml
COPY --from=builder /workspace/src/github.com/docker/distribution/bin/registry /bin/registry
COPY distribution/LICENSE /licenses/
VOLUME ["/var/lib/registry"]
EXPOSE 5000
USER 65534:65534
ENTRYPOINT ["registry"]
CMD ["serve", "/etc/docker/registry/config.yml"]
