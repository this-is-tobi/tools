#!/bin/sh
# Installed ahead of the real sudo on PATH.
#
# In a pod that forbids privilege escalation the kernel's no_new_privs bit is
# set, so the setuid sudo cannot become root and fails with a message about
# container configuration that tells a job author nothing useful. Say what that
# means for a job here; everywhere else (Docker-in-Docker, a plain `docker run`)
# hand over to the real sudo untouched.
if grep -q '^NoNewPrivs:[[:space:]]*1' /proc/self/status 2> /dev/null; then
  cat >&2 << 'EOF'
sudo: this runner does not allow privilege escalation (no_new_privs is set), so a job cannot run commands as root.
Common build tools are already in the image. Install anything else into your home directory (mise, uv tool install, npm, cargo or go install), or run the job in a container image that has it.
EOF
  exit 1
fi

exec /usr/bin/sudo "$@"
