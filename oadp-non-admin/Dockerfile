#@follow_tag(registry-proxy.engineering.redhat.com/rh-osbs/openshift-golang-builder:rhel_9_golang_1.23)
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.23 AS builder
COPY . /workspace
WORKDIR /workspace/oadp-non-admin/
ENV BUILDTAGS strictfipsruntime
ENV GOEXPERIMENT strictfipsruntime
RUN CGO_ENABLED=1 GOOS=linux go build -tags "$BUILDTAGS" -mod=mod -a -o manager cmd/main.go

#@follow_tag(registry.redhat.io/ubi9/ubi-minimal:latest)
FROM registry.redhat.io/ubi9/ubi-minimal:latest
RUN microdnf clean all
COPY --from=builder /workspace/oadp-non-admin/manager /manager
COPY --from=builder /workspace/oadp-non-admin/LICENSE /licenses/

USER 65532:65532

ENTRYPOINT ["/manager"]
