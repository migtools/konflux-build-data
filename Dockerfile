FROM registry.redhat.io/ubi9/python-312:latest@sha256:83b01cf47b22e6ce98a0a4802772fb3d4b7e32280e3a1b7ffcd785e01956e1cb

COPY pre-build-script /usr/local/bin/pre-build-script
COPY LICENSE /licenses

USER default
