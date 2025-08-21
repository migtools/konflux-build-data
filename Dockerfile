FROM registry.redhat.io/ubi9/python-312:latest@sha256:53a7dc3bc0fc6f7f40f6ac68ee5b51d148293fbf9cddeec94bb58fbf8e2833eb

COPY pre-build-script /usr/local/bin/pre-build-script
COPY LICENSE /licenses

USER default
