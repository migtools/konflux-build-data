FROM registry.redhat.io/openshift4/ose-ansible-rhel9-operator:v4.17.0-202502111335.p0.g9cb5839.assembly.stream.el9
USER root
COPY operator/tools/upgrades/migrate-pathfinder-assessments.py /usr/local/bin/migrate-pathfinder-assessments.py
COPY operator/tools/upgrades/jwt.sh /usr/local/bin/jwt.sh

ARG COMMUNITY_GENERAL="community-general-4.8.11.tar.gz"
ARG COMMUNITY_POSTGRESQL="community-postgresql-3.10.2.tar.gz"
COPY ${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_GENERAL}
COPY ${COMMUNITY_POSTGRESQL} ${HOME}/${COMMUNITY_POSTGRESQL}
RUN ansible-galaxy collection install ${HOME}/${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_POSTGRESQL} && rm ${HOME}/${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_POSTGRESQL}

RUN dnf -y update && dnf -y clean all
RUN dnf module list
# Fix PG15 is not available on ubi9 streams, needs rhel9 streams, see Brew operator build for details
#RUN dnf -y module enable postgresql:15 && dnf -y install postgresql python3-psycopg2 python3-jmespath && dnf clean all
RUN dnf -y install postgresql python3-psycopg2 python3-jmespath && dnf clean all
USER 1001
COPY operator/watches.yaml ${HOME}/watches.yaml
COPY operator/roles ${HOME}/roles
COPY operator/playbooks ${HOME}/playbooks
COPY operator/LICENSE /licenses/

# Hack java bundle property location downstream (can't use snapshoted artifacts)
RUN sed -r -i 's/java-analyzer-bundle.core-1.0.0-SNAPSHOT.jar/java-analyzer-bundle.core.jar/' ${HOME}/roles/tackle/templates/customresource-extension.yml.j2

LABEL \
        com.redhat.component="mta-operator-container" \
        version="8.0.0" \
        name="mta/mta-rhel9-operator" \
        license="Apache License 2.0" \
        io.k8s.display-name="MTA - Operator" \
        io.k8s.description="Migration Toolkit for Applications - Operator" \
        io.openshift.tags="migration,modernization,mta,tackle,konveyor" \
        io.openshift.build.commit.id="1b49c7ca51a6f118e4417cff12ab9bbf62be6ea9" \
        io.openshift.build.source-location="https://github.com/konveyor/operator" \
        io.openshift.build.commit.url="https://github.com/konveyor/operator/commit/1b49c7ca51a6f118e4417cff12ab9bbf62be6ea9" \
        summary="Migration Toolkit for Applications - Operator" \
        maintainer="Migration Toolkit for Applications Team <migtoolkit-team@redhat.com>" \
        build.commit.urls="https://github.com/konveyor/operator/commit/1b49c7ca51a6f118e4417cff12ab9bbf62be6ea9"
