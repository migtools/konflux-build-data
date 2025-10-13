FROM registry.redhat.io/ubi9/go-toolset:1.23 AS go-builder
COPY --chown=1001:0 . /workspace

WORKDIR /workspace/analyzer-lsp/external-providers/dotnet-external-provider
ENV GOEXPERIMENT strictfipsruntime
RUN go mod edit -replace=github.com/konveyor/analyzer-lsp=../../ && CGO_ENABLED=1 go build -tags strictfipsruntime -o bin/dotnet-external-provider main.go

FROM registry.redhat.io/ubi8/dotnet-80:latest AS dotnet-builder
COPY --chown=1001:0 . /workspace
WORKDIR /workspace/csharp-language-server
# Ignore csharp ls build tests errors (if binary fails to build, COPY will fail as well)
RUN dotnet publish -o bin -p:PublishSingleFile=true ; true

FROM registry.redhat.io/ubi9-minimal:latest
USER root
RUN microdnf -y update && microdnf -y clean all
RUN microdnf -y install openssl dotnet-sdk-8.0 dotnet-sdk-7.0 && microdnf -y clean all
ENV PATH="$PATH:/opt/app-root/.dotnet/tools:/home/go/bin"
RUN mkdir -p /opt/input/source && chown -R 1001:0 /opt/input
ENV XDG_DATA_HOME=/tmp/.xdg \
    XDG_CACHE_HOME=/tmp/.xdg-cache \
    XDG_CONFIG_HOME=/tmp/.xdg-config
RUN mkdir -p /tmp/.xdg /tmp/.xdg-cache /tmp/.xdg-config
USER 1001
EXPOSE 3456

COPY --from=go-builder --chown=1001:0 /workspace/analyzer-lsp/LICENSE /licenses/
COPY --from=go-builder --chown=1001:0 /workspace/analyzer-lsp/external-providers/dotnet-external-provider/bin /usr/bin
COPY --from=dotnet-builder --chown=1001:0 /workspace/csharp-language-server/bin/CSharpLanguageServer /opt/app-root/.dotnet/tools/csharp-ls

RUN csharp-ls -v

ENTRYPOINT ["dotnet-external-provider", "-port", "3456"]
