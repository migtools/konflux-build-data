FROM registry.redhat.io/ubi9-minimal:latest AS builder
COPY --chown=1001:0 . /workspace
RUN ls -la /workspace

FROM registry.redhat.io/ubi9-minimal:latest AS pnc-artifacts
RUN microdnf -y install tar gzip && microdnf -y clean all

# FIX ME
#COPY artifacts/fernflower.jar /opt
#COPY artifacts/java-analyzer-bundle.core.jar /opt
#WORKDIR /jdtls
#COPY artifacts/jdtls-product.tar.gz /jdtls
#RUN tar -xvf jdtls-product.tar.gz --no-same-owner && chmod 755 /jdtls/bin/jdtls && rm -rf jdtls-product.tar.gz
COPY --chown=1001:0 java-analyzer-bundle /workspace
RUN ls -la /workspace

FROM registry.redhat.io/ubi9-minimal:latest
RUN microdnf -y module enable maven:3.9
RUN microdnf -y install openssl python39 java-1.8.0-openjdk-devel java-17-openjdk-devel maven-openjdk17 tar gzip --nodocs --setopt=install_weak_deps=0 && microdnf -y clean all
ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk
ENV JAVA8_HOME /usr/lib/jvm/java-1.8.0-openjdk
RUN mvn --version

RUN mkdir /root/.gradle
COPY --from=builder /workspace/java-analyzer-bundle/gradle/build.gradle /usr/local/etc/task.gradle
COPY --from=builder /workspace/java-analyzer-bundle/gradle/build-v9.gradle /usr/local/etc/task-v9.gradle

COPY --from=builder /workspace/java-analyzer-bundle/hack/maven.default.index /usr/local/etc/maven.default.index
#COPY --from=pnc-artifacts /jdtls /jdtls/
#COPY --from=pnc-artifacts /opt/java-analyzer-bundle.core.jar /jdtls/java-analyzer-bundle/java-analyzer-bundle.core/target/
#COPY --from=pnc-artifacts /opt/fernflower.jar /bin/fernflower.jar
COPY --from=builder /workspace/java-analyzer-bundle/jdtls-bin-override/jdtls.py /jdtls/bin/jdtls.py
COPY --from=builder /workspace/java-analyzer-bundle/LICENSE /licenses/

RUN ln -sf /root/.m2 /.m2 && chgrp -R 0 /root && chmod -R g=u /root

ENTRYPOINT ["/jdtls/bin/jdtls"]
