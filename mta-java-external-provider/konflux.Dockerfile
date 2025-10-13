FROM registry.redhat.io/ubi9/go-toolset:1.23 AS builder
COPY --chown=1001:0 . /workspace

WORKDIR /workspace/analyzer-lsp/external-providers/java-external-provider
ENV GOEXPERIMENT strictfipsruntime
RUN go mod edit -replace=github.com/konveyor/analyzer-lsp=../../ && CGO_ENABLED=1 go build -tags strictfipsruntime -a -o java-external-provider main.go

FROM brew.registry.redhat.io/rh-osbs/mta-mta-jdtls-server-base-rhel9:8.0.0

COPY --from=builder /workspace/analyzer-lsp/external-providers/java-external-provider/java-external-provider /usr/local/bin/java-external-provider
COPY --from=builder /workspace/analyzer-lsp/LICENSE /licenses/

ENV HOME /addon
EXPOSE 14651
WORKDIR /addon
ENTRYPOINT ["java-external-provider", "--port", "14651"]
