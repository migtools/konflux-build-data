FROM registry.redhat.io/ubi9/go-toolset:1.23 AS builder
COPY --chown=1001:0 . /workspace

WORKDIR /workspace/analyzer-addon
# Avoid using Makefile as it performs GOIMPORTS and fails downstream
ENV GOEXPERIMENT strictfipsruntime
RUN go fmt ./... && go vet ./cmd/... ./builder/... && CGO_ENABLED=1 go build -tags strictfipsruntime -ldflags="-w -s" -o bin/addon github.com/konveyor/tackle2-addon-analyzer/cmd

FROM brew.registry.redhat.io/rh-osbs/mta-mta-analyzer-lsp-rhel9:8.0.0
RUN microdnf -y install glibc-langpack-en openssh-clients openssl subversion git tar && microdnf -y clean all

RUN sed -i 's/^LANG=.*/LANG="en_US.utf8"/' /etc/locale.conf
ENV LANG=en_US.utf8
RUN echo "addon:x:1001:1001:addon user:/addon:/sbin/nologin" >> /etc/passwd
RUN echo -e "StrictHostKeyChecking no" \
 "\nUserKnownHostsFile /dev/null" > /etc/ssh/ssh_config.d/99-konveyor.conf

ENV HOME=/addon ADDON=/addon
COPY --from=builder /workspace/analyzer-addon/bin/addon /usr/bin
COPY --from=builder /workspace/analyzer-addon/LICENSE /licenses/

WORKDIR /addon

ENTRYPOINT ["/usr/bin/addon"]
