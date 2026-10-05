FROM quay.io/rockylinux/rockylinux:9

ARG CODESERVER_VERSION=4.140.0

USER root
# CRB + EPEL behövs för openblas-devel, lapack-devel och hdf5-devel.
# --allowerasing byter ut curl-minimal mot fullständig curl.
RUN dnf install -y dnf-plugins-core epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf update -y && \
    dnf install -y --allowerasing \
        python3 \
        python3-pip \
        python3-devel \
        gcc \
        gcc-c++ \
        openblas-devel \
        lapack-devel \
        hdf5-devel \
        glib2 \
        libSM \
        libXrender \
        libXext \
        git \
        curl \
        wget \
        unzip \
        ca-certificates \
        file \
        tree \
        openssh-server \
        nss_wrapper-libs \
        shadow-utils \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# ── Skapa coder-användare
RUN useradd -m -u 1000 -s /bin/bash coder && \
    usermod -aG root coder

# ── Installera code-server via RPM (låst version, ändra med --build-arg)
RUN curl -fsSL "https://github.com/coder/code-server/releases/download/v${CODESERVER_VERSION}/code-server-${CODESERVER_VERSION}-amd64.rpm" \
        -o /tmp/code-server.rpm && \
    dnf install -y /tmp/code-server.rpm && \
    rm /tmp/code-server.rpm

# ── SSH (port 2222) – egen config så sshd kan köras som icke-root
RUN printf '%s\n' \
        'Port 2222' \
        'HostKey /home/coder/.ssh/hostkeys/ssh_host_ed25519_key' \
        'PidFile /tmp/sshd.pid' \
        'AuthorizedKeysFile .ssh/authorized_keys' \
        'AllowUsers coder' \
        'PermitRootLogin no' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'UsePAM no' \
        'StrictModes no' \
        'Subsystem sftp /usr/libexec/openssh/sftp-server' \
        > /etc/ssh/sshd_coder_config

# ── Python venv
ENV VENV=/opt/venv
RUN python3 -m venv $VENV
ENV PATH="$VENV/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir black

# ── VS Code extensions
ENV EXTENSIONS_DIR=/home/coder/.local/share/code-server/extensions
RUN mkdir -p $EXTENSIONS_DIR
RUN code-server --extensions-dir $EXTENSIONS_DIR \
        --install-extension ms-python.python \
        --install-extension ms-python.black-formatter

# ── SSH-katalog (authorized_keys monteras in vid körning)
RUN mkdir -p /home/coder/.ssh/hostkeys

# ── Workspace & config
RUN mkdir -p /home/coder/workspace/.vscode /home/coder/.local/share/code-server/User
COPY settings.json /home/coder/.local/share/code-server/User/settings.json

RUN echo 'source /opt/venv/bin/activate' >> /home/coder/.bashrc

RUN chown -R coder:coder /home/coder $VENV && \
    chgrp -R 0 /home/coder $VENV && \
    chmod -R g=u /home/coder $VENV

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

USER 1000
ENV HOME=/home/coder
WORKDIR /home/coder/workspace
EXPOSE 8080 2222
ENTRYPOINT ["/entrypoint.sh"]