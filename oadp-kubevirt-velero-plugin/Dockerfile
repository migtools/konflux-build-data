FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.23 AS builder

COPY . /workspace
WORKDIR /workspace/kubevirt-velero-plugin/
ENV GOEXPERIMENT strictfipsruntime
RUN CGO_ENABLED=1 GOOS=linux go build -v -mod=vendor -tags strictfipsruntime -o /workspace/kubevirt-velero-plugin/bin/kubevirt-velero-plugin .

FROM registry.redhat.io/ubi9/ubi-minimal:latest
RUN microdnf -y install openssl && microdnf -y reinstall tzdata && microdnf clean all
RUN mkdir /plugins
COPY --from=builder /workspace/kubevirt-velero-plugin/bin/kubevirt-velero-plugin /plugins/
COPY --from=builder /workspace/kubevirt-velero-plugin/LICENSE /licenses/
USER 65534:65534
ENTRYPOINT ["/bin/bash", "-c", "cp /plugins/* /target/."]
