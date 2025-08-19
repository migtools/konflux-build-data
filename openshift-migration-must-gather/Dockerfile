#@follow_tag(registry.redhat.io/openshift4/ose-must-gather:v4.15)
FROM registry.redhat.io/openshift4/ose-must-gather:v4.15 AS builder
COPY . /workspace/
USER root
RUN chown -R 1001:0 /workspace/
USER 1001

#@follow_tag(registry-proxy.engineering.redhat.com/rh-osbs/openshift-golang-builder:rhel_8_golang_1.23)
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_golang_1.23 AS pprof-builder
COPY . /workspace/
WORKDIR /workspace/pprof

ENV GOEXPERIMENT strictfipsruntime
ENV BUILDTAGS containers_image_ostree_stub exclude_graphdriver_devicemapper exclude_graphdriver_btrfs containers_image_openpgp exclude_graphdriver_overlay strictfipsruntime
ENV BIN pprof
RUN GO111MODULE=auto CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -mod=readonly -installsuffix "static" -tags "$BUILDTAGS" -o _output/$BIN ./$BIN.go

#@follow_tag(registry.redhat.io/ubi8/ubi-minimal)
FROM registry.redhat.io/ubi8/ubi-minimal:latest
RUN microdnf -y install rsync tar gzip graphviz findutils grep jq && microdnf clean all
COPY --from=pprof-builder /workspace/pprof/_output/pprof /usr/bin/
COPY --from=builder /usr/bin/oc /usr/bin/oc
COPY --from=builder /workspace/must-gather/collection-scripts/* /usr/bin/
COPY --from=builder /workspace/must-gather/collection-scripts/logs/* /usr/bin
COPY --from=builder /workspace/must-gather/collection-scripts/time_window_gather /usr/bin
COPY must-gather/LICENSE /licenses/
ENTRYPOINT /usr/bin/gather
