# termux-tailscale-fix

Getting [Tailscale](https://tailscale.com) running as a persistent SSH tunnel into
Termux (Android, no root). Companion to [termux-opentunnel-fix](https://github.com/dhhieu113pro/termux-opentunnel-fix).

Result: iPhone (Termius app) or any device on the tailnet can SSH into the phone
anywhere — no TLS-wrapping ProxyCommand needed, unlike the opentunnel route.

## Quick install

```sh
curl -fsSL https://raw.githubusercontent.com/bropines/tailscale-termux-cli/main/remote-install.sh | bash
```

This is the patched build (`bropines/tailscale-termux-cli`) — upstream Tailscale
1.104+ mostly works on Android now (DNS via `dnsproxyd`, netmon survives
`net.Interfaces()` denial), but this fork additionally enumerates real interfaces
and adds termux-services packaging. Basic installer deps land automatically.

Then log in once:

```sh
tailscale-cli up        # print the login URL, open it, sign in (Apple/GitHub/Google)
tailscale status        # shows the node and its 100.x.x.x IP
```

## The one problem: `libresolvefix.so` kills the CLI

This device ships a global

```
LD_PRELOAD=/data/data/com.termux/files/usr/lib/libresolvefix.so
```

whose source (`strings` shows `libresolvefix.c`) lacks `dlsym`, so the Go
`tailscale`/`tailscale-cli` binaries die at exec with:

```
CANNOT LINK EXECUTABLE ".../bin/tailscale": cannot locate symbol "dlsym"
  referenced by ".../lib/libresolvefix.so"
```

The daemon runs fine regardless (it starts through the service before any
preload matters), so only CLI calls are broken. Fix: a PATH wrapper that strips
the preload for just these invocations.

```sh
mkdir -p ~/.pub-cache/bin        # first on PATH in this setup; use any dir there
cat > ~/.pub-cache/bin/tailscale <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
exec env LD_PRELOAD= /data/data/com.termux/files/usr/bin/tailscale "$@"
EOF
chmod +x ~/.pub-cache/bin/tailscale
```

`tailscale-cli` stays broken until its own wrapper covers it; the `tailscale`
wrapper above is enough for daily use (`up`, `status`, `ip`, `...`).

## The service

The installer registers and enables a runit service, so it survives reboots:

```sh
sv status tailscaled    # run: tailscaled: (pid ..., ...)
tailscaled-log          # daemon log
```

**Boot autostart (Termux:Boot):** termux-services only starts when a login
shell runs. With the Termux:Boot app, this device's
`~/.termux/boot/start-services` starts `tailscaled` and `sshd` on every boot
(wake lock included). Open the Termux:Boot app once after installing so Android
registers it.

## Use — iPhone (Termius)

1. Install the Tailscale iOS app, sign in with the same account.
2. Termius → New Host:
   - Host: `100.114.22.82` (via `tailscale status` on the phone; use `tailscale ip -4` in scripts) — or its MagicDNS name `tailscale-termux`
   - Port: `8022`
   - Username: `u0_a247` (`whoami` in Termux)
   - Password: the Termux one (`passwd` sets it), or drop your key into `~/.ssh/authorized_keys`

Windows/Mac clients work identically: plain `ssh u0_a247@100.114.22.82 -p 8022` — no
port-443 dance. Anything that can reach 100.x addresses can reach the phone.

**Important:** write down the 100.x IP *before* you need it and prefer the
MagicDNS name; if you're away from the phone and the IP ever changes, the
admin console at login.tailscale.com/machines shows it remotely.

## Handover from opentunnel

`opentunnel` was switched off with `sv down opentunnel && sv disable opentunnel`
(tunnel, routes and docs left in place — see `termux-opentunnel-fix`), so it
still has `https://…open­tunnel.xyz` addresses on record if ever needed again.

## What each piece is here

```
README.md            this file
install.sh           one-time setup replicating the steps above
boot/start-services  copy of ~/.termux/boot/start-services for reference
```

## Known limits

- Login IP/device requires the Tailscale free account (Apple ID works).
- SOCKS5 sidecar on `127.0.0.1:1055` is authenticated by design
  (`tailscale-socks5`); it's a security feature, not a bug — don't use
  `TS_SOCKS5_NO_AUTH=1`.
- Without Termux:Boot, the node comes back at the next *Termux session* after a
  reboot, not immediately at boot.

License: MIT.
