# https://github.com/konveyor/static-report
FROM registry.redhat.io/ubi9/go-toolset:1.23 AS go-builder
COPY --chown=1001:0 . /workspace
WORKDIR /workspace/static-report/analyzer-output-parser

ENV GOEXPERIMENT strictfipsruntime
RUN CGO_ENABLED=1 go build -tags strictfipsruntime -o js-bundle-generator ./main.go

# Nodejs
FROM registry.redhat.io/ubi9/nodejs-18:latest AS nodejs-builder
COPY --chown=1001:0 . /workspace
USER 1001
WORKDIR /workspace/static-report

# Replace upstream assets with mta
COPY ./static-report-assets/logo.svg src/images/logo.svg
COPY ./static-report-assets/navbar-logo.svg src/images/navbar-logo.svg
COPY ./static-report-assets/favicon.ico public/favicon.ico
RUN sed -i "s/_VERSION_/${CI_VERSION}/g" public/version.js
RUN sed -i -e 's/\(name: "\)[^"]*"/\1Migration Toolkit for Applications"/' \
    -e 's/\(websiteURL: "\)[^"]*"/\1https:\/\/developers.redhat.com\/products\/mta\/overview"/' \
    -e 's/\(documentationURL: "\)[^"]*"/\1https:\/\/access.redhat.com\/documentation\/en-us\/migration_toolkit_for_applications"/' \
    src/layout/theme-constants.ts
RUN npm clean-install --no-audit --verbose && CI=true PUBLIC_URL=. npm run build

FROM registry.redhat.io/ubi9-minimal:latest
RUN microdnf -y install openssl && microdnf -y clean all

COPY --from=go-builder /workspace/static-report/analyzer-output-parser/js-bundle-generator /usr/bin/js-bundle-generator
COPY --from=nodejs-builder /workspace/static-report/build /usr/local/static-report

ENTRYPOINT ["js-bundle-generator"]
