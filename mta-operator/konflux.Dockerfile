FROM registry.redhat.io/openshift4/ose-ansible-rhel9-operator:v4.17.0
USER root
COPY operator/tools/upgrades/migrate-pathfinder-assessments.py /usr/local/bin/migrate-pathfinder-assessments.py
COPY operator/tools/upgrades/jwt.sh /usr/local/bin/jwt.sh

ARG COMMUNITY_GENERAL="community-general-4.8.11.tar.gz"
ARG COMMUNITY_POSTGRESQL="community-postgresql-3.10.2.tar.gz"
COPY ${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_GENERAL}
COPY ${COMMUNITY_POSTGRESQL} ${HOME}/${COMMUNITY_POSTGRESQL}
RUN ansible-galaxy collection install ${HOME}/${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_POSTGRESQL} && rm ${HOME}/${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_POSTGRESQL}

# Fix PG15 is not available on ubi9 streams, needs rhel9 streams, see Brew operator build for details
#RUN dnf -y module enable postgresql:15 && dnf -y install postgresql python3-psycopg2 python3-jmespath && dnf clean all
RUN dnf install -y python3-psycopg2 python3-jmespath && dnf clean all
RUN dnf module install -y postgresql:15 && dnf clean all
USER 1001
COPY --chown=1001:0 operator/watches.yaml ${HOME}/watches.yaml
COPY --chown=1001:0 operator/roles ${HOME}/roles
COPY --chown=1001:0 operator/playbooks ${HOME}/playbooks
COPY --chown=1001:0 operator/LICENSE /licenses/

# Hack java bundle property location downstream (can't use snapshoted artifacts)
RUN sed -r -i 's/java-analyzer-bundle.core-1.0.0-SNAPSHOT.jar/java-analyzer-bundle.core.jar/' ${HOME}/roles/tackle/templates/customresource-extension.yml.j2
