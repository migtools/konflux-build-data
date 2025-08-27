#@follow_tag(registry-proxy.engineering.redhat.com/rh-osbs/openshift-golang-builder:rhel_9_golang_1.24)
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.24 AS builder
COPY . /workspace
WORKDIR /workspace/velero/
ENV GOEXPERIMENT strictfipsruntime
RUN CGO_ENABLED=1 GOOS=linux go build -a -mod=mod -tags strictfipsruntime -o ./bin/velero-restore-helper ./cmd/velero-restore-helper

#@follow_tag(registry.redhat.io/ubi9/ubi-minimal:latest)
FROM registry.redhat.io/ubi9/ubi-minimal:latest
RUN microdnf -y install nmap-ncat openssl && microdnf -y reinstall tzdata && microdnf clean all
COPY --from=builder /workspace/velero/bin/velero-restore-helper velero-restore-helper
COPY --from=builder /workspace/velero/LICENSE /licenses/

USER 65534:65534

ENTRYPOINT ["/velero-restore-helper"]

