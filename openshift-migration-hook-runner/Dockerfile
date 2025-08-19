FROM registry.redhat.io/ansible-automation-platform-25/platform-resource-runner-rhel8:latest
RUN chmod 777 /home/runner/.ansible && chmod 777 /home/runner/.ansible/tmp
RUN mkdir /.ansible && chmod 777 /.ansible
COPY /hook-runner/licenses /licenses
COPY /hook-runner/entrypoint /bin/entrypoint
RUN chmod 755 /bin/entrypoint
USER 65534:65534
