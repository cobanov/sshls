# sshls

A colorful, at-a-glance list of **active SSH sessions**. By default it shows
your own machine — who is connected **in**, and where you're connected **out**
to. Add `-r` to fan out across your fleet and see every host's sessions too.
Companion to [`better-tailscale-ls`](https://github.com/cobanov/better-tailscale-ls):
that shows the machines on your tailnet, `sshls` shows the live connections
between them.

Default — this machine, both directions:

```
  SSH  macmini  ·  5 in / 7 out   v0.3.0
  ─────────────────────────────
  incoming
    ●  ←  ct100-docker
    ●  ←  macbook      ×4
  outgoing
    ●  →  nuc
    ●  →  spark        ×3
    ●  →  white        ×3
```

`sshls -r` — every host in `~/.ssh/config`, each one's inbound sessions:

```
  SSH sessions  minotaur-banded.ts.net  ·  12 sessions / 5 hosts   v0.3.0
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

Addresses are resolved to Tailscale device names, so you read `nuc ← macmini`,
not `nuc ← 100.70.248.21`. `←` is inbound, `→` is outbound; `[ts]` marks a
Tailscale-SSH session; `×N` collapses identical connections; `—` is an idle
connection with no foreground command. The connection `sshls -r` opens to poll
each host is excluded, so it never counts itself.

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

- `ss` (Linux) or `netstat` (macOS) — to read local sockets for the default
  view. Both are standard.
- For `-r`: `ssh` with passwordless access to the hosts in your `~/.ssh/config`;
  each remote host needs `ss` (regular connections) plus `ps` and `w`
  (Tailscale-SSH sessions and user/activity). Hosts without `ss` show `[no ss]`.
- [`tailscale`](https://tailscale.com/download) + [`jq`](https://jqlang.github.io/jq/)
  — optional, on your local machine, for device-name resolution. Without them
  `sshls` still works; it just prints raw IPs.

On macOS:

```bash
brew install jq        # tailscale too, if you don't already have it
```

## Usage

```bash
sshls              # this machine: incoming (←) and outgoing (→) SSH, the default
sshls -r           # also poll every host in ~/.ssh/config (remote fleet)
sshls nuc pve      # only these remote hosts (implies -r)
sshls -l           # this machine only (explicit; same as the default)
sshls -w           # watch mode, refreshes every 5s
sshls -w 2         # custom refresh interval
sshls -u           # self-update to the latest release
sshls -V           # print version
sshls --help
```

## How it works

**Default (local).** Reads this machine's established TCP sockets (`ss` on
Linux, `netstat` on macOS). A socket whose *local* port is 22 is inbound
(someone → you); one whose *remote* port is 22 is outbound (you → someone).
Peers are resolved to Tailscale device names and grouped into `incoming` /
`outgoing`.

**Fleet (`-r`).** For each host in `~/.ssh/config`, `sshls` runs a tiny POSIX-sh
collector over SSH (shipped base64-encoded so no remote shell quoting can mangle
it, and so it runs under `sh` regardless of the login shell). Per host it
gathers:

- **Regular sshd connections** — inbound port-22 sockets via `ss`; the poller's
  own connection is dropped by matching `$SSH_CONNECTION`.
- **Tailscale-SSH sessions** — `tailscaled` forks a `be-child ssh …` process per
  session with `--remote-user`/`--remote-ip`. These never appear as a port-22
  socket, so they're read from the process list; the poller's own session is
  dropped by the `--cmd=…` that decodes its base64 payload.
- **User & activity** — from `w`, parsed via `w`'s own header offsets so the
  same logic works on the Linux and macOS layouts.

Hosts are polled in parallel with a short `ConnectTimeout`, so one unreachable
box never stalls the run. Only `C` / `T` / `E` / `NOSS` / `RC` marker lines are
parsed, so locale warnings or SSH banners can't corrupt the output.

## Caveats

- Reports *connections*, not logins — several connections from one peer collapse
  to a `×N` badge.
- In fleet mode, `activity` only shows for sessions with a foreground command on
  a pty; idle shells, tunnels, and privilege-separation monitors show `—`.
- Fleet coverage is the hosts in `~/.ssh/config`; a connection where neither end
  is polled is invisible. Hosts without `ss` are `[no ss]`; unreachable `[down]`.

## Uninstall

```bash
rm ~/.local/bin/sshls   # or wherever you installed it
```

## License

MIT, see [LICENSE](LICENSE).
