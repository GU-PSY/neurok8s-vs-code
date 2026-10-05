#!/bin/bash
set -euo pipefail

export HOME=/home/coder

# ── OpenShift kör med slumpmässigt UID som saknas i /etc/passwd.
#    nss_wrapper mappar användaren "coder" till aktuellt UID så att
#    ssh-keygen, sshd och verktyg som git fungerar.
if [ "$(id -u)" != "1000" ]; then
    export NSS_WRAPPER_PASSWD=/tmp/passwd
    export NSS_WRAPPER_GROUP=/etc/group
    grep -v '^coder:' /etc/passwd > "$NSS_WRAPPER_PASSWD"
    echo "coder:x:$(id -u):0:coder:/home/coder:/bin/bash" >> "$NSS_WRAPPER_PASSWD"
    export LD_PRELOAD=libnss_wrapper.so
fi

# ── SSH (port 2222)
if [ "${ENABLE_SSH:-true}" = "true" ]; then
    HOSTKEY="$HOME/.ssh/hostkeys/ssh_host_ed25519_key"
    mkdir -p "$(dirname "$HOSTKEY")"
    [ -f "$HOSTKEY" ] || ssh-keygen -q -t ed25519 -N '' -f "$HOSTKEY"
    /usr/sbin/sshd -f /etc/ssh/sshd_coder_config -E /tmp/sshd.log
fi

# ── code-server
exec code-server \
  --bind-addr 0.0.0.0:8080 \
  --auth "${CS_AUTH:-none}" \
  --extensions-dir "${EXTENSIONS_DIR:-/opt/code-server/extensions}" \
  /home/coder/workspace