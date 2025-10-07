FROM registry.redhat.io/ubi9/go-toolset:1.23 AS builder
COPY --chown=1001:0 . /workspace

WORKDIR /workspace/discovery-addon
ENV GOEXPERIMENT strictfipsruntime
RUN go fmt ./... && go vet ./cmd/... && CGO_ENABLED=1 go build -ldflags="-w -s" -tags strictfipsruntime -o bin/addon github.com/konveyor/tackle2-addon-discovery/cmd

FROM registry.redhat.io/ubi9-minimal:latest
RUN microdnf -y install glibc-langpack-en openssh-clients openssl subversion git tar && microdnf -y clean all
RUN sed -i 's/^LANG=.*/LANG="en_US.utf8"/' /etc/locale.conf
ENV LANG=en_US.utf8
RUN echo "addon:x:1001:1001:addon user:/addon:/sbin/nologin" >> /etc/passwd
RUN echo -e "StrictHostKeyChecking no" \
 "\nUserKnownHostsFile /dev/null" > /etc/ssh/ssh_config.d/99-konveyor.conf
ENV HOME=/addon ADDON=/addon
WORKDIR /addon
COPY --from=builder /workspace/discovery-addon/bin/addon /usr/bin

ENTRYPOINT ["/usr/bin/addon"]
