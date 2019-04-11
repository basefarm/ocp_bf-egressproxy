FROM registry.access.redhat.com/rhel7
MAINTAINER OpenShift Team for Basefarm AS

#https://github.com/projectatomic/ContainerApplicationGenericLabels

LABEL name='bf/squid' \
      version='1' \
      release='1' \
      architecture='x86_64' \
      vendor='Basefarm AS' \
      url='https://github.com/basefarm/ocp_bf-squid' \
      maintainer='OpenShift Team for Basefarm AS' \
      summary='Basefarm squid' \
      description='Provides a Squid proxy server on RHEL7. Defaults will do for demo. Define dstdomains as a list in SQUID_ALLOW or mount list.txt to /etc/squid/allow-domains'

RUN INSTALL_PKGS='squid nmap-ncat' && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && rpm -V $INSTALL_PKGS && \
    yum clean all -y && rm -rf /var/cache/yum

COPY pkg/inotify-tools-3.14-8.el7.x86_64.rpm /tmp/inotify-tools.rpm
RUN  rpm -i /tmp/inotify-tools.rpm && rm -rf /tmp/inotify-tools.rpm

COPY bin/init /init
COPY conf/squid.conf /etc/squid/squid.conf

RUN mkdir -p /etc/squid/allow-domains /etc/squid/deny-domains

COPY conf/allow-list.txt /etc/squid/allow-domains/list.txt
COPY conf/deny-list.txt /etc/squid/deny-domains/list.txt

RUN chmod +x /init && \
    chgrp -R 0   /etc/squid /var/{log,run}/squid && \
    chmod -R g=u /etc/squid /var/{log,run}/squid

USER 1001
ENV SQUID_ALLOW=
ENV SQUID_DENY=
ENV SQUID_ACCESS_LOG=true
ENV SQUID_PORTS=Safe_ports
ENV SQUID_DEBUG=0
ENV SQUID_CACHE_MGR_MAIL=support@company.com

EXPOSE 3128

CMD /init
