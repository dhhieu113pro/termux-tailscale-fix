#!/data/data/com.termux/files/usr/bin/sh
# One-time Tailscale setup on Termux (Android, no root).
# Mirrors install.sh from termux-opentunnel-fix: rerunnable, idempotent-ish.
set -eu

# 1. daemon + CLI (patched Android build, userspace networking)
if ! command -v tailscaled >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/bropines/tailscale-termux-cli/main/remote-install.sh | bash
fi

# 2. CLI wrapper: the device's global LD_PRELOAD shim lacks dlsym and kills
#    the Go binaries. See README.md "The one problem".
mkdir -p ~/.pub-cache/bin
cat > ~/.pub-cache/bin/tailscale <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
exec env LD_PRELOAD= /data/data/com.termux/files/usr/bin/tailscale "$@"
EOF
chmod +x ~/.pub-cache/bin/tailscale

# 3. termux-services: the installer enabled `tailscaled`; assert it runs
sv status tailscaled || { sv enable tailscaled 2>/dev/null || true; sv up tailscaled; }

# 4. sshd (must run for anything to SSH into)
sv status sshd || sv up sshd

# 5. login hint
{
  if tailscale status >/dev/null 2>&1; then
    echo "Logged in. Give this IP to your other devices:"
    tailscale ip -4
  else
    echo "Not logged in. Run: tailscale-cli up   (then open the printed URL)"
  fi
}

echo done
