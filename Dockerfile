FROM ubuntu:focal
LABEL maintainer="Chris Wieringa <cwieri39@calvin.edu>"

# Set versions and platforms
ARG S6_OVERLAY_VERSION=3.1.1.2
ARG BUILDDATE=20220808-01

# Do all run commands with bash
SHELL ["/bin/bash", "-c"] 

# Start with base Ubuntu, add a few system packages
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    sssd \
    sssd-ad \
    sssd-krb5 \
    sssd-tools \
    libnfsidmap2 \
    libsss-idmap0 \
    libsss-nss-idmap0 \
    libnss-myhostname \
    libnss-mymachines \
    libnss-ldap \
    libuser \
    locales \
    nfs-common \
    krb5-user \
    sssd-krb5 \
    unburden-home-dir && \
    rm -rf /var/lib/apt/lists/*

# add unburden config files
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/bashprofile-unburden /etc/profile.d/unburden.sh
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/unburden-home-dir.conf /etc/unburden-home-dir
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/unburden-home-dir.list /etc/unburden-home-dir.list
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/unburden-home-dir /etc/default/unburden-home-dir
RUN chmod 0755 /etc/profile.d/unburden.sh && \
    chmod 0644 /etc/unburden-home-dir && \
    chmod 0644 /etc/unburden-home-dir.list && \
    chmod 0644 /etc/default/unburden-home-dir

# add CalvinAD trusted root certificate
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/CalvinCollege-ad-CA.crt /etc/ssl/certs
RUN chmod 0644 /etc/ssl/certs/CalvinCollege-ad-CA.crt
RUN ln -s -f /etc/ssl/certs/CalvinCollege-ad-CA.crt /etc/ssl/certs/ddbc78f4.0

# Drop all inc/ configuration files
# krb5.conf, sssd.conf, idmapd.conf
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/krb5.conf /etc
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/nsswitch.conf /etc
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/sssd.conf /etc/sssd
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/idmapd.conf /etc
RUN chmod 0600 /etc/sssd/sssd.conf && \
    chmod 0644 /etc/krb5.conf && \
    chmod 0644 /etc/nsswitch.conf && \
    chmod 0644 /etc/idmapd.conf
RUN chown root:root /etc/sssd/sssd.conf

# pam configs
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/common-auth /etc/pam.d
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/common-session /etc/pam.d
RUN chmod 0644 /etc/pam.d/common-auth && \
    chmod 0644 /etc/pam.d/common-session

# use the secrets to edit sssd.conf appropriately
RUN --mount=type=secret,id=LDAP_BIND_USER \
    source /run/secrets/LDAP_BIND_USER && \
    sed -i 's@%%LDAP_BIND_USER%%@'"$LDAP_BIND_USER"'@g' /etc/sssd/sssd.conf
RUN --mount=type=secret,id=LDAP_BIND_PASSWORD \
    source /run/secrets/LDAP_BIND_PASSWORD && \
    sed -i 's@%%LDAP_BIND_PASSWORD%%@'"$LDAP_BIND_PASSWORD"'@g' /etc/sssd/sssd.conf
RUN --mount=type=secret,id=DEFAULT_DOMAIN_SID \
    source /run/secrets/DEFAULT_DOMAIN_SID && \
    sed -i 's@%%DEFAULT_DOMAIN_SID%%@'"$DEFAULT_DOMAIN_SID"'@g' /etc/sssd/sssd.conf

# Setup multiple stuff going on in the container instead of just single access  -------------------------#
# S6 overlay from https://github.com/just-containers/s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    rm -f /tmp/s6-overlay-*.tar.xz

ENV S6_CMD_WAIT_FOR_SERVICES=1 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=5000

ENTRYPOINT ["/init"]
COPY s6-overlay/ /etc/s6-overlay

# Install syslogd-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/syslogd-overlay-noarch.tar.xz /tmp/
RUN tar -C / -Jxpf /tmp/syslogd-overlay-noarch.tar.xz && \
    rm -f /tmp/syslogd-overlay-noarch.tar.xz

# Access control
RUN echo "ldap_access_filter = memberOf=CN=CS-Rights-Lab-All,OU=Groups,OU=CalvinCS,DC=ad,DC=calvin,DC=edu" >> /etc/sssd/sssd.conf

# Setup of openSSH
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y openssh-server openssh-client update-motd vim-tiny nano-tiny xauth

# OpenSSH keys via secrets
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ECDSA_KEY \
    cp -f /run/secrets/CSSSH_SSH_HOST_ECDSA_KEY /etc/ssh/ssh_host_ecdsa_key
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ECDSA_KEY_PUB \
    cp -f /run/secrets/CSSSH_SSH_HOST_ECDSA_KEY_PUB /etc/ssh/ssh_host_ecdsa_key.pub
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ED25519_KEY \
    cp -f /run/secrets/CSSSH_SSH_HOST_ED25519_KEY /etc/ssh/ssh_host_ed25519_key
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ED25519_KEY_PUB \
    cp -f /run/secrets/CSSSH_SSH_HOST_ED25519_KEY_PUB /etc/ssh/ssh_host_ed25519_key.pub
RUN --mount=type=secret,id=CSSSH_SSH_HOST_RSA_KEY \
    cp -f /run/secrets/CSSSH_SSH_HOST_RSA_KEY /etc/ssh/ssh_host_rsa_key
RUN --mount=type=secret,id=CSSSH_SSH_HOST_RSA_KEY_PUB \
    cp -f /run/secrets/CSSSH_SSH_HOST_RSA_KEY_PUB /etc/ssh/ssh_host_rsa_key.pub

# SSH configuration
COPY inc/sshd_config /etc/ssh/sshd_config

# Run directory
RUN mkdir -p /run/sshd && \
    chown root:root /run/sshd && \
    chmod 0755 /run/sshd

# MOTD update
COPY inc/motd /etc/update-motd.d/05-cs-info
RUN rm -f /etc/update-motd.d/50-motd-news /etc/update-motd.d/60-unminimize && \
    /usr/sbin/update-motd

# Expose the service
EXPOSE 22/tcp

# Locale and environment setup
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TERM xterm-256color

# Debugging
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y netcat-openbsd \
    nmap \
    telnet \
    iputils-ping \
    bind9-dnsutils && \
    rm -rf /var/lib/apt/lists/*
