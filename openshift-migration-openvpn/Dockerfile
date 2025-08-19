#@follow_tag(registry.redhat.io/ubi8/ubi)
FROM registry.redhat.io/ubi8/ubi:latest AS builder
COPY . /workspace/
WORKDIR /workspace/openvpn/
USER root
RUN dnf -y install dnf dnf-plugins-core rpm-build
RUN rpm -ivh *.rpm
RUN dnf builddep -y pkcs11-helper*
RUN rpmbuild -ba /root/rpmbuild/SPECS/pkcs11-helper.spec
RUN dnf -y install /root/rpmbuild/RPMS/x86_64/pkcs11-helper*
RUN dnf builddep -y openvpn*
RUN rpmbuild -ba /root/rpmbuild/SPECS/openvpn.spec


#@follow_tag(registry.redhat.io/ubi8/ubi)
FROM registry.redhat.io/ubi8/ubi:latest
COPY --from=builder /root/rpmbuild/RPMS/x86_64/pkcs11-helper-1* ./
COPY --from=builder /root/rpmbuild/RPMS/x86_64/openvpn-2* ./
COPY openvpn/LICENSE /licenses/
RUN dnf -y install socat stunnel *.rpm && dnf clean all && rm -fv *.rpm
