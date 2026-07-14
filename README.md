# sshls

A colorful, at-a-glance list of **active SSH sessions across your fleet**.
Where [`better-tailscale-ls`](https://github.com/cobanov/better-tailscale-ls)
shows you the machines on your tailnet, `sshls` shows you who is connected to
them right now — the live edges of your network.

```
  SSH sessions  minotaur-banded.ts.net  ·  6 sessions / 4 hosts   v0.1.0
  ───────────────────────────────────────────────────────────────
  ●  white  ←  ct100-docker
  ●  white  ←  macmini
  ●  nuc    ←  ct100-docker
  ●  nuc    ←  macmini
  ●  ct104  ←  192.168.8.155
  ●  ct107  ←  192.168.8.155
  ───────────────────────────────────────────────────────────────
  ○  gl     down
  ○  pve    no sessions
  ○  spark  down
  ○  nas    no ss
  ○  ct100  no sessions
```

Source addresses are resolved to Tailscale device names, so you read
`nuc ← macmini`, not `nuc ← 100.70.248.21`. The connection `sshls` itself
opens to poll each host is excluded, so it never counts itself.

## Install

One-liner (curl):

```bash
curl -fsSL https://raw.githubusercontent.com/cobanov/sshls/main/install.sh | bash
```

Or manual:

```bash
curl -fsSL https://raw.githubusercontent.com/cobanov/sshls/main/sshls \
  -o ~/.local/bin/sshls && chmod +x ~/.local/bin/sshls
```

The installer drops `sshls` into `~/.local/bin` (or `/usr/local/bin` if that
isn't on your PATH). Override with `PREFIX=/some/dir`.

### Dependencies

- `ssh` — required. Hosts are read from your `~/.ssh/config`, so passwordless
  access (keys / agent) to each host is what makes the fan-out work.
- `ss` — required **on each remote host** (part of `iproute2` on Linux).
  Hosts without it are shown as `[no ss]`.
- [`tailscale`](https://tailscale.com/download) + [`jq`](https://jqlang.github.io/jq/)
  — optional. Without them `sshls` still works; it just prints raw IPs
  instead of device names.

On macOS:

```bash
brew install jq        # tailscale too, if you don't already have it
```

## Usage

```bash
sshls              # SSH sessions on every host in ~/.ssh/config, busy hosts first
sshls nuc pve      # only these hosts
sshls -l           # local machine only (sessions coming INTO this box)
sshls -w           # watch mode, refreshes every 5s
sshls -w 2         # custom refresh interval
sshls -u           # self-update to the latest release
sshls -V           # print version
sshls --help
```

By default `sshls` polls every `Host` entry in your `~/.ssh/config` (the first
non-wildcard alias of each). Pass host names to limit the run to just those.

## How it works

For each host, `sshls` runs a tiny POSIX-sh collector over SSH (shipped
base64-encoded so no remote shell quoting can mangle it, and so it runs under
`sh` regardless of the login shell). The collector lists established TCP
connections whose **local** port is 22 — i.e. inbound SSH — and prints each
peer address. Your own polling connection is dropped by matching it against
`$SSH_CONNECTION`.

Back on your machine, peer IPs are mapped to Tailscale device names via
`tailscale status --json`, connections are grouped per host, and everything is
rendered busy-hosts-first, with idle / unreachable hosts dimmed below the fold.

Hosts are polled in parallel with a short `ConnectTimeout`, so one unreachable
box never stalls the whole run. Only `S` / `NOSS` / `RC` marker lines are
parsed, so locale warnings or SSH banners on a host can't corrupt the output.

## Caveats

`sshls` counts **regular `sshd`** connections (via `ss` on port 22):

- **Tailscale SSH** sessions are not counted — they are proxied by
  `tailscaled` and never appear as a port-22 socket.
- Hosts without `ss` are marked `[no ss]`; unreachable hosts are marked
  `[down]`.
- It reports *connections*, not logins — a source with several open
  connections shows a `×N` badge.

## Uninstall

```bash
rm ~/.local/bin/sshls   # or wherever you installed it
```

## License

MIT, see [LICENSE](LICENSE).
