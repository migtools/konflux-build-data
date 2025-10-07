# https://github.com/konveyor/analyzer-lsp/tree/main/external-providers/golang-dependency-provider
FROM registry.redhat.io/ubi9/go-toolset:1.23 AS builder
COPY --chown=1001:0 . /workspace

# golang-dependency-provider is part of the analyzer-lsp repo
WORKDIR /workspace/analyzer-lsp/external-providers/golang-dependency-provider
ENV GOEXPERIMENT strictfipsruntime
RUN go mod edit -replace=github.com/konveyor/analyzer-lsp=../../ && CGO_ENABLED=1 go build -tags strictfipsruntime -o golang-dependency-provider main.go

# Runtime
#@follow_tag(registry.redhat.io/ubi9-minimal:latest)
FROM registry.redhat.io/ubi9-minimal:latest
RUN microdnf -y install openssl && microdnf -y clean all

COPY --from=builder /workspace/analyzer-lsp/external-providers/golang-dependency-provider/golang-dependency-provider /usr/local/bin/golang-dependency-provider
COPY --from=builder /workspace/analyzer-lsp/LICENSE /licenses/

ENTRYPOINT ["/usr/local/bin/golang-dependency-provider"]
