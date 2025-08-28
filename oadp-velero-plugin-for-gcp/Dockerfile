#@follow_tag(registry-proxy.engineering.redhat.com/rh-osbs/openshift-golang-builder:rhel_9_golang_1.23)
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.23 AS builder

COPY . /workspace
WORKDIR /workspace/velero-plugin-for-gcp/
ENV GOEXPERIMENT strictfipsruntime
RUN CGO_ENABLED=1 GOOS=linux go build -v -mod=mod -tags strictfipsruntime -o /workspace/velero-plugin-for-gcp/bin/velero-plugin-for-gcp ./velero-plugin-for-gcp

#@follow_tag(registry.redhat.io/ubi9/ubi-minimal:latest)
FROM registry.redhat.io/ubi9/ubi-minimal:latest
RUN microdnf -y install openssl && microdnf -y reinstall tzdata && microdnf clean all
RUN mkdir /plugins
COPY --from=builder /workspace/velero-plugin-for-gcp/bin/velero-plugin-for-gcp /plugins/
COPY --from=builder /workspace/velero-plugin-for-gcp/LICENSE /licenses/
USER 65534:65534
ENTRYPOINT ["/bin/bash", "-c", "cp /plugins/* /target/."]

