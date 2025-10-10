FROM registry.redhat.io/ubi9/go-toolset:1.23 AS go-builder
COPY --chown=1001:0 . /workspace

WORKDIR /workspace/analyzer-lsp/external-providers/generic-external-provider
ENV GOEXPERIMENT strictfipsruntime
RUN go mod edit -replace=github.com/konveyor/analyzer-lsp=../../ && CGO_ENABLED=1 go build -tags strictfipsruntime -o generic-external-provider main.go

WORKDIR /workspace/tools/gopls
RUN source CGO_ENABLED=1 go build -tags strictfipsruntime -buildvcs=false

FROM brew.registry.redhat.io/rh-osbs/mta-mta-golang-dependency-provider-rhel9:8.0.0 as go-dep-provider

FROM registry.redhat.io/ubi9-minimal:latest
RUN microdnf -y module enable nodejs:18
RUN microdnf -y install openssl gcc-c++ python-devel python3-devel nodejs tar && microdnf -y clean all

# Python LSP server
COPY python-lsp-server.tgz python-lsp-server.tgz
RUN tar xzvf python-lsp-server.tgz
RUN pip install -r python-lsp-server/requirements.txt --no-index --find-links python-lsp-server
RUN rm -r python-lsp-server.tgz python-lsp-server

# Typescript LSP server
ENV NODEJS_VERSION=18
COPY typescript.tgz typescript.tgz
COPY typescript-language-server.tgz typescript-language-server.tgz
RUN npm install -g typescript-language-server.tgz typescript.tgz
RUN typescript-language-server --version

COPY --from=go-builder /workspace/analyzer-lsp/external-providers/generic-external-provider/generic-external-provider /usr/local/bin/generic-external-provider
COPY --from=go-builder /workspace/tools/gopls/gopls /usr/local/bin/gopls
COPY --from=go-builder /workspace/analyzer-lsp/LICENSE /licenses/
COPY --from=go-dep-provider /usr/local/bin/golang-dependency-provider /usr/local/bin/golang-dependency-provider

ENTRYPOINT ["/usr/local/bin/generic-external-provider"]
