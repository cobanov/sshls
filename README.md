# sshls

A colorful, at-a-glance list of **active SSH sessions across your fleet** —
who is connected to each machine, from where, and what they're doing.
Where [`better-tailscale-ls`](https://github.com/cobanov/better-tailscale-ls)
shows you the machines on your tailnet, `sshls` shows you the live edges
between them.

```
  SSH sessions  minotaur-banded.ts.net  ·  10 sessions / 5 hosts   v0.2.0
  ─────────────────────────────────────────────────────────────────────
  ●  spark  ←  ct100-docker   cobanov                —
  ●  spark  ←  macmini        cobanov                — ×3
  ●  nuc    ←  macmini        cobanov                vim config.yaml
  ●  ct107  ←  192.168.8.155  root                   —
  ●  ct107  ←  macmini        mertcobanov@gmail.com  — [ts]
  ─────────────────────────────────────────────────────────────────────
  ○  gl     down
  ○  pve    no sessions
  ○  nas    no ss
```

Each row is `host ← source   user   activity`. Source addresses are resolved
to Tailscale device names, so you read `nuc ← macmini`, not
`nuc ← 100.70.248.21`. `[ts]` marks a Tailscale-SSH session; `×N` collapses
several identical connections; `—` means an idle connection with no foreground
command. The connection `sshls` itself opens to poll each host is excluded, so
it never counts itself.

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
- On each remote host: `ss` (part of `iproute2`) for regular connections,
  plus `ps` and `w` for Tailscale-SSH sessions and user/activity. All three
  ship on a standard Linux box. Hosts without `ss` are shown as `[no ss]`.
- [`tailscale`](https://tailscale.com/download) + [`jq`](https://jqlang.github.io/jq/)
  — optional, on your local machine. Without them `sshls` still works; it just
  prints raw IPs instead of device names.

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
`sh` regardless of the login shell). The collector gathers three things:

- **Regular sshd connections** — established TCP connections whose *local* port
  is 22, via `ss`. The peer address is the source. Your own polling connection
  is dropped by matching it against `$SSH_CONNECTION`.
- **Tailscale-SSH sessions** — `tailscaled` forks a `be-child ssh …` process
  per session, carrying `--remote-user` and `--remote-ip`. These never appear
  as a port-22 socket, so they're read from the process list. The poller's own
  session is dropped by the `--cmd=…` that decodes its base64 payload.
- **User & activity** — from `w`, parsed by reading column offsets out of `w`'s
  own header so the same logic works on the Linux and macOS layouts.

Back on your machine, peer IPs are mapped to Tailscale device names via
`tailscale status --json`, sessions are grouped per host, deduplicated with a
`×N` count, and rendered busy-hosts-first with idle / unreachable hosts dimmed
below the fold.

Hosts are polled in parallel with a short `ConnectTimeout`, so one unreachable
box never stalls the whole run. Only `C` / `T` / `E` / `NOSS` / `RC` marker
lines are parsed, so locale warnings or SSH banners on a host can't corrupt the
output.

## Caveats

- Reports *connections*, not logins — a source with several open connections
  shows a `×N` badge.
- `activity` is only visible for sessions with a foreground command on a pty;
  idle shells, tunnels, and privilege-separation monitors show `—`.
- Hosts without `ss` are marked `[no ss]`; unreachable hosts are marked
  `[down]`.

## Uninstall

```bash
rm ~/.local/bin/sshls   # or wherever you installed it
```

## License

MIT, see [LICENSE](LICENSE).
