FROM calvincs.azurecr.io/base-sssdunburden:latest
LABEL maintainer="Chris Wieringa <cwieri39@calvin.edu>"

# Set versions and platforms
ARG BUILDDATE=20230202-1
ARG S6_OVERLAY_VERSION=3.1.3.0

# Do all run commands with bash
SHELL ["/bin/bash", "-c"] 
ENTRYPOINT ["/init"]

# copy new s6-overlay items for SSH/logging
COPY s6-overlay/ /etc/s6-overlay

# Install syslogd-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/syslogd-overlay-noarch.tar.xz /tmp/
RUN tar -C / -Jxpf /tmp/syslogd-overlay-noarch.tar.xz && \
    rm -f /tmp/syslogd-overlay-noarch.tar.xz

# Access control
RUN echo "ldap_access_filter = memberOf=CN=CS-Rights-Lab-All,OU=Groups,OU=CalvinCS,DC=ad,DC=calvin,DC=edu" >> /etc/sssd/sssd.conf

# Setup of openSSH
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y coreutils \
    add-apt-key \
    openssh-server \
    openssh-client \
    update-motd \
    sudo \
    git \
    iputils-ping \
    iputils-tracepath \
    iproute2 \
    bind9-dnsutils \
    netcat-openbsd \
    vim-tiny \
    nano-tiny \
    xauth && \
    rm -rf /var/lib/apt/lists/*

# OpenSSH keys via secrets
# NOTE: multiline is a pain, so actual keys that are multi-line are base64 encoded in the secret
# (cat <key> | base64 -w 0 > <secret.env>).  Public keys should be single lines already, so they don't have
# to be base64 encoded.  Decode the secret when dropping the key (cat <secret> | base64 -d > /etc/ssh/<key>)
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ECDSA_KEY \
    cat /run/secrets/CSSSH_SSH_HOST_ECDSA_KEY | /usr/bin/base64 -d > /etc/ssh/ssh_host_ecdsa_key
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ECDSA_KEY_PUB \
    cp -f /run/secrets/CSSSH_SSH_HOST_ECDSA_KEY_PUB /etc/ssh/ssh_host_ecdsa_key.pub
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ED25519_KEY \
    cat /run/secrets/CSSSH_SSH_HOST_ED25519_KEY | /usr/bin/base64 -d > /etc/ssh/ssh_host_ed25519_key
RUN --mount=type=secret,id=CSSSH_SSH_HOST_ED25519_KEY_PUB \
    cp -f /run/secrets/CSSSH_SSH_HOST_ED25519_KEY_PUB /etc/ssh/ssh_host_ed25519_key.pub
RUN --mount=type=secret,id=CSSSH_SSH_HOST_RSA_KEY \
    cat /run/secrets/CSSSH_SSH_HOST_RSA_KEY | /usr/bin/base64 -d > /etc/ssh/ssh_host_rsa_key
RUN --mount=type=secret,id=CSSSH_SSH_HOST_RSA_KEY_PUB \
    cp -f /run/secrets/CSSSH_SSH_HOST_RSA_KEY_PUB /etc/ssh/ssh_host_rsa_key.pub

# SSH configuration
COPY inc/sshd_config /etc/ssh/sshd_config

# Run directory
RUN mkdir -p /run/sshd && \
    chown root:root /run/sshd && \
    chmod 0755 /run/sshd

# Mount points
RUN mkdir -p /home /opt/{R,python,anaconda} /rprojects && \
    chmod 0755 /home /opt/R /opt/python /opt/anaconda /rprojects 

# MOTD update
COPY --chmod=0755 inc/motd /etc/update-motd.d/05-cs-info
RUN rm -f /etc/update-motd.d/10-help-text \
    /etc/update-motd.d/50-motd-news \
    /etc/update-motd.d/60-unminimize && \
    echo "" > /etc/legal && \
    /usr/sbin/update-motd

# pam sshd
COPY --chmod=0644 inc/pam_sshd /etc/pam.d/sshd

# Expose the service
EXPOSE 22/tcp
