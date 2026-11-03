# Welcome message of the dev, dev-lite and debug images. Identical in the three
# build contexts; the image name arrives through IMAGE_NAME.
#
# Sourced from /etc/zsh/zshrc and /etc/bash.bashrc, so it runs for an
# interactive shell however it was started (`docker run -it`, `docker exec -it`,
# `kubectl exec -it ... -- zsh|bash`). It stays valid for both shells: no arrays,
# no [[ ]], nothing zsh- or bash-only.
#
# Rules it keeps, because a banner that breaks a pipeline is worse than none:
# - Terminal output only. `kubectl cp` is tar over exec and `kubectl exec ... --
#   cat f | jq` reads stdout, so a non-interactive shell, or any shell whose
#   stdout is not a terminal, prints nothing.
# - Once per session. The guard variable is exported, so a tmux pane or a nested
#   zsh inherits it and stays quiet; the next exec starts clean and prints again.
# - Local information only: no API call, no DNS lookup, nothing that can hang.
# - Easy to switch off: NO_MOTD=1 in the environment (docker run -e, a pod's env)
#   or a ~/.hushlogin file, the same convention login(1) uses.

# A proxy URL may carry credentials (http://user:pass@host), and a banner can end
# up on a shared screen or in a pasted screenshot: print the host, not the login.
__container_motd_mask() {
  printf '%s' "$1" | sed 's#^\([A-Za-z0-9+.-]*://\)[^/]*@#\1***@#'
}

__container_motd() {
  [ -t 1 ] || return 0
  case $- in *i*) ;; *) return 0 ;; esac
  [ -z "${CONTAINER_MOTD_SHOWN:-}" ] || return 0
  [ -z "${NO_MOTD:-}" ] || return 0
  [ ! -e "${HOME:-/nonexistent}/.hushlogin" ] || return 0
  export CONTAINER_MOTD_SHOWN=1

  __m_name=${IMAGE_NAME:-container}
  # shellcheck source=/dev/null
  __m_os=$(. /etc/os-release 2> /dev/null && printf '%s' "${PRETTY_NAME:-}")
  __m_host=$(hostname 2> /dev/null)
  __m_ip=$(hostname -i 2> /dev/null | awk '{ print $1 }')
  __m_user=$(id -un 2> /dev/null)
  __m_uid=$(id -u 2> /dev/null)

  # Where this is running. A service account namespace file is what a pod has.
  __m_ns=
  [ -r /var/run/secrets/kubernetes.io/serviceaccount/namespace ] \
    && __m_ns=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2> /dev/null)
  if [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
    __m_where="pod        ${__m_host}"
    [ -n "$__m_ip" ] && __m_where="${__m_where} (${__m_ip})"
    [ -n "$__m_ns" ] && __m_where="${__m_where} in namespace ${__m_ns}"
  else
    __m_where="container  ${__m_host}"
    [ -n "$__m_ip" ] && __m_where="${__m_where} (${__m_ip})"
  fi

  # What the security context allows, only when it restricts something, since
  # that is what explains a failing sudo or a read-only write.
  __m_limits=
  [ "$__m_uid" = 0 ] && __m_limits="running as root"
  if grep -q '^NoNewPrivs:[[:space:]]*1' /proc/self/status 2> /dev/null; then
    __m_limits="${__m_limits:+${__m_limits} · }no privilege escalation (sudo will not work)"
  fi
  if [ "$(awk '$2 == "/" { split($4, o, ","); print o[1] }' /proc/mounts 2> /dev/null | tail -n 1)" = ro ]; then
    __m_limits="${__m_limits:+${__m_limits} · }read-only root filesystem"
  fi

  # What the cgroup caps this container at, only when it caps something (cgroup
  # v2; "max" means no limit). An OOM-killed build or a throttled test run starts
  # here.
  __m_cpu=$(awk '$1 != "max" && $2 > 0 { printf "%.4g", $1 / $2 }' /sys/fs/cgroup/cpu.max 2> /dev/null)
  __m_mem=$(awk '$1 ~ /^[0-9]+$/ { printf "%.4g", $1 / 1073741824 }' /sys/fs/cgroup/memory.max 2> /dev/null)
  __m_res=
  [ -n "$__m_cpu" ] && __m_res="${__m_cpu} CPU"
  [ -n "$__m_mem" ] && __m_res="${__m_res:+${__m_res} · }${__m_mem} GiB memory"

  # Proxy settings, when the environment sets any. Upper and lower case are both
  # honoured by the tools, so both are read.
  __m_http=$(__container_motd_mask "${HTTP_PROXY:-${http_proxy:-}}")
  __m_https=$(__container_motd_mask "${HTTPS_PROXY:-${https_proxy:-}}")
  if [ -n "$__m_http" ] && [ "$__m_http" = "$__m_https" ]; then
    __m_proxy=$__m_http
  else
    __m_proxy=
    [ -n "$__m_http" ] && __m_proxy="${__m_http} (http)"
    [ -n "$__m_https" ] && __m_proxy="${__m_proxy:+${__m_proxy} · }${__m_https} (https)"
  fi
  # NO_PROXY is often a long cluster-wide list: the first entries and a count.
  __m_noproxy=$(printf '%s' "${NO_PROXY:-${no_proxy:-}}" | awk -F, '
    NF { n = (NF > 3 ? 3 : NF)
         for (i = 1; i <= n; i++) printf "%s%s", $i, (i < n ? "," : "")
         if (NF > 3) printf " (+%d more)", NF - 3 }')

  # A custom trust store, which is what a TLS-inspecting proxy needs. Only the
  # variables that are set; the names say which tools were configured.
  __m_ca=
  for __m_var in SSL_CERT_FILE SSL_CERT_DIR NODE_EXTRA_CA_CERTS REQUESTS_CA_BUNDLE CURL_CA_BUNDLE GIT_SSL_CAINFO; do
    eval "__m_val=\${${__m_var}:-}"
    [ -n "$__m_val" ] && __m_ca="${__m_ca:+${__m_ca} · }${__m_var}=${__m_val}"
  done

  if [ -z "${NO_COLOR:-}" ]; then
    __m_bold=$(printf '\033[1m')
    __m_off=$(printf '\033[0m')
  else
    __m_bold=
    __m_off=
  fi

  printf '\n%s%s%s%s\n' "$__m_bold" "$__m_name" "$__m_off" "${__m_os:+ · ${__m_os}}"
  printf '  %s\n' "$__m_where"
  printf '  %s\n' "as         ${__m_user} (uid ${__m_uid})${__m_limits:+ · ${__m_limits}}"
  [ -n "$__m_res" ] && printf '  %s\n' "resources  up to ${__m_res}"
  [ -n "$__m_proxy" ] && printf '  %s\n' "proxy      ${__m_proxy}"
  [ -n "$__m_noproxy" ] && printf '  %s\n' "no_proxy   ${__m_noproxy}"
  [ -n "$__m_ca" ] && printf '  %s\n' "ca certs   ${__m_ca}"

  if [ "$__m_name" = debug ]; then
    # What the cluster DNS gives this pod, the first thing to check when a name
    # does not resolve.
    __m_dns=$(awk '
      /^nameserver/ { ns = ns (ns ? " " : "") $2 }
      /^search/     { $1 = ""; sub(/^ /, ""); search = $0 }
      END           { if (ns != "") printf "%s%s", ns, (search != "" ? " · search " search : "") }
    ' /etc/resolv.conf 2> /dev/null)
    [ -n "$__m_dns" ] && printf '  %s\n' "dns        ${__m_dns}"
    printf '  %s\n' "tools      dig, nmap, ping, openssl, wget; mise ls lists the rest"
  else
    printf '  %s\n' "tools      mise ls (what is installed)"
  fi

  printf '  %s\n\n' "silence    NO_MOTD=1 in the environment, or touch ~/.hushlogin"

  unset __m_name __m_os __m_host __m_ip __m_user __m_uid __m_ns __m_where \
    __m_limits __m_bold __m_off __m_dns __m_cpu __m_mem __m_res __m_http __m_https \
    __m_proxy __m_noproxy __m_ca __m_var __m_val
}

__container_motd
unset -f __container_motd __container_motd_mask
