#@follow_tag(registry-proxy.engineering.redhat.com/rh-osbs/openshift-golang-builder:rhel_9_golang_1.24)
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.24 AS builder

COPY . /workspace
WORKDIR /workspace/velero-plugin-for-legacy-aws/
ENV GOEXPERIMENT strictfipsruntime
RUN CGO_ENABLED=1 GOOS=linux go build -v -mod=mod -tags strictfipsruntime -o /workspace/velero-plugin-for-legacy-aws/bin/velero-plugin-for-aws ./velero-plugin-for-aws

#@follow_tag(registry.redhat.io/ubi9/ubi-minimal:latest)
FROM registry.redhat.io/ubi9/ubi-minimal:latest
RUN microdnf -y install openssl && microdnf -y reinstall tzdata && microdnf clean all
RUN mkdir /plugins
COPY --from=builder /workspace/velero-plugin-for-legacy-aws/bin/velero-plugin-for-aws /plugins/
COPY --from=builder /workspace/velero-plugin-for-legacy-aws/LICENSE /licenses/
USER nobody:nogroup
ENTRYPOINT ["/bin/bash", "-c", "cp /plugins/* /target/."]

LABEL \
        com.redhat.component="oadp-velero-plugin-for-legacy-aws-container" \
        version="1.4.6" \
        name="oadp/oadp-velero-plugin-for-legacy-aws-rhel9" \
        License="Apache License 2.0" \
        io.k8s.display-name="OADP Velero Plugin for Legacy AWS" \
        io.openshift.tags="migration" \
        io.k8s.description="OpenShift API for Data Protection - Velero Plugin for Legacy AWS" \
        io.openshift.build.commit.id="1b33296e0997cbcb06f896e9fb014e7eead59c3b" \
        io.openshift.build.source-location="https://github.com/openshift/velero-plugin-for-legacy-aws" \
        io.openshift.build.commit.url="https://github.com/openshift/velero-plugin-for-legacy-aws/commit/1b33296e0997cbcb06f896e9fb014e7eead59c3b" \
        summary="OpenShift API for Data Protection - Velero Plugin for Legacy AWS" \
        maintainer="OpenShift API for Data Protection Team <oadp-team@redhat.com>"
