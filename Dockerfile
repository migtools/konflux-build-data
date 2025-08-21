FROM registry.redhat.io/ubi9/python-312:latest

COPY pre-build-script /usr/local/bin/pre-build-script
COPY LICENSE /licenses

USER default
