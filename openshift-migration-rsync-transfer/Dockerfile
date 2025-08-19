FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_golang_1.23 AS builder

WORKDIR /workspace/
COPY rsync-transfer/go.mod go.mod
COPY rsync-transfer/go.sum go.sum
COPY rsync-transfer/cmd/ cmd/
COPY rsync-transfer/pkg/ pkg/

ENV GOEXPERIMENT strictfipsruntime
ENV BUILDTAGS containers_image_ostree_stub exclude_graphdriver_devicemapper exclude_graphdriver_btrfs containers_image_openpgp exclude_graphdriver_overlay strictfipsruntime
RUN GO111MODULE=auto CGO_ENABLED=1 GOOS=linux go build -mod=readonly -v -installsuffix "static" -tags "$BUILDTAGS" -o _output/blockrsync ./cmd/blockrsync/main.go
RUN GO111MODULE=auto CGO_ENABLED=1 GOOS=linux go build -mod=readonly -v -installsuffix "static" -tags "$BUILDTAGS" -o _output/proxy ./cmd/proxy/main.go

FROM registry.redhat.io/ubi8/ubi-minimal:latest
RUN microdnf -y install openssh-server stunnel rsync nmap && microdnf clean all

COPY --from=builder /workspace/_output/blockrsync /blockrsync
COPY --from=builder /workspace/_output/proxy /proxy
COPY rsync-transfer/sshd_config /etc/ssh/sshd_config
COPY rsync-transfer/stunnel.conf /etc/stunnel/stunnel.conf
COPY rsync-transfer/LICENSE /licenses/

USER 65534:65534
WORKDIR /
