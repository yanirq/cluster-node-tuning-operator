FROM registry.svc.ci.openshift.org/openshift/release:golang-1.13 AS builder
WORKDIR /go/src/github.com/openshift/cluster-node-tuning-operator
COPY . .
RUN make build

FROM centos:7
COPY --from=builder /go/src/github.com/openshift/cluster-node-tuning-operator/_output/cluster-node-tuning-operator /usr/bin/
COPY manifests /manifests
ENV APP_ROOT=/var/lib/tuned
ENV PATH=${APP_ROOT}/bin:${PATH}
ENV HOME=${APP_ROOT}
WORKDIR ${APP_ROOT}
COPY --from=builder /go/src/github.com/openshift/cluster-node-tuning-operator/_output/openshift-tuned /usr/bin/
COPY --from=builder /go/src/github.com/openshift/cluster-node-tuning-operator/assets ${APP_ROOT}
RUN INSTALL_PKGS=" \
      tuned tuna tuned-profiles-cpu-partitioning patch socat \
      " && \
    ARCH_DEP_PKGS=$(if [ "$(uname -m)" != "s390x" ]; then echo -n hdparm kernel-tools ; fi) && \
    mkdir -p /etc/grub.d/ /boot && \
    yum install --setopt=tsflags=nodocs -y $INSTALL_PKGS $ARCH_DEP_PKGS && \
    rpm -V $INSTALL_PKGS $ARCH_DEP_PKGS && \
    (LC_COLLATE=C cat patches/*.diff | patch -Np1 -d / || :) && \
    chmod 755 /usr/lib/tuned/*/script.sh && \
    touch /etc/sysctl.conf && \
    yum -y remove patch && \
    yum clean all && \
    rm -rf /var/cache/yum ~/patches && \
    useradd -r -u 499 cluster-node-tuning-operator
ENTRYPOINT ["/usr/bin/cluster-node-tuning-operator"]
LABEL io.k8s.display-name="OpenShift cluster-node-tuning-operator" \
      io.k8s.description="This is a component of OpenShift and manages the lifecycle of node-level tuning." \
      io.openshift.release.operator=true
