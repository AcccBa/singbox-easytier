# singbox-easytier

Unofficial builds of the [sing-box](https://github.com/reF1nd/sing-box) core and
the [SFA](https://github.com/reF1nd/sing-box-for-android) Android client in which
the [EasyTier](https://github.com/EasyTier/easytier) overlay-network core is
embedded **inside sing-box** as a native outbound. One Android `VpnService` then
carries both proxy traffic and overlay-network traffic, so a separate EasyTier
VPN app is no longer needed.

> **Not an official project.** This is an independent third-party build. It is not
> affiliated with, endorsed by, or maintained by the sing-box, SFA, reF1nd or
> EasyTier projects. Names appear for identification only, in line with the
> additional condition inherited from the upstream license — see [NOTICE](NOTICE).

![regression](https://github.com/AcccBa/singbox-easytier/actions/workflows/regression.yml/badge.svg)
[![Release](https://img.shields.io/github/v/release/AcccBa/singbox-easytier?include_prereleases)](https://github.com/AcccBa/singbox-easytier/releases)
[![License](https://img.shields.io/github/license/AcccBa/singbox-easytier)](LICENSE)

## Why this exists

On Android, `VpnService` is a system-wide singleton: while one app holds the
tunnel, no other app can install one. EasyTier's official Android client and a
sing-box based proxy therefore cannot run side by side. Embedding the EasyTier
core as a sing-box outbound moves the overlay from "another VPN app" to "another
hop inside the same process", which removes the conflict.

## How it works

| Layer | Implementation |
|---|---|
| Overlay core runtime | Prebuilt EasyTier WebAssembly artifact, executed in-process by [wazero](https://wazero.io/) — no NDK, no Rust, no external binary in the APK beyond the wasm blob |
| sing-box integration | Outbound type `easytier`, compiled in under the build tag `with_easytier`; without that tag the provider is absent and the config fails validation at startup |
| Traffic plane | Socket level. The embedded core does not create a TUN interface, so IP-level features that require one (e.g. raw ICMP/`ping` through the overlay) are not provided by this outbound |
| Android client | Stock SFA, fed with a `libbox.aar` built from the patched core in `sing-box/` |

### Behaviour flags worth knowing

| Option | Default | Note |
|---|---|---|
| `cache_runtime` | `true` | Keeps the wasm runtime warm. Measured on a Linux host: ≈39 MB extra resident, in exchange for removing a ≈266 MB transient peak and a ≈15 s JIT warm-up on every service restart. Set `false` to restore upstream's release-on-stop behaviour. |
| `lazy` | `false` | **Experimental and unusable on Android.** Start-on-demand needs underlay sockets to be created through the sing-box dialer (so they are `VpnService.protect()`-ed). That SocketFactory path is not implemented; enabling this option on Android self-deadlocks the tunnel at first connect. Desktop only. |
| `config_toml` | – | Replaces the entire embedded-core configuration. Combining it with the structured fields (`network_name`, `network_key`, `peer`, `ipv4_network`, …) is rejected at compile time, because the structured fields would be silently ignored. |

Validated on-device: direct P2P (UDP) link establishment through
carrier-grade NAT across two different ISPs, 0 % packet loss in steady state.

## Repository layout

```
sing-box/     core, patched with the embedded easytier outbound
sfa/          SFA Android client
scripts/      sync-upstream.sh — single entry point for the three upstreams
.github/      regression.yml · apk.yml · release.yml
```

## Building

Builds are produced by CI; a working tree checkout is enough to reproduce one.
Local toolchain requirements, versions and the exact commands are encoded in
`.github/workflows/apk.yml` (Go 1.27.x, `sagernet/gomobile` pinned, NDK r28,
build-tools 37.0.0, JDK 17).

```bash
# Full pipeline: core + aar + unsigned APK, then sign, attest and publish
gh workflow run release.yml --repo AcccBa/singbox-easytier -f prerelease=true -f attest=true
```

Every push to `main` that touches `sing-box/` runs the regression gate first:
full-tag build → self-check that the built binary advertises the `easytier`
outbound → `go vet` → unit tests for the flag defaults above.

Signing keys are **not** stored as repository secrets. They live in the
environment `sign-gate`, which is gated by a protection rule; the workflow
refuses to publish unless the resulting APK's signing certificate matches the
fingerprint below.

## Releases and verification

Every release publishes `SFA-<version>-arm64-v8a-signed.apk` plus `SHA256SUMS`.

```bash
sha256sum -c SHA256SUMS
apksigner verify --print-certs SFA-*-signed.apk      # must match the fingerprint below
```

Signing certificate (SHA-256):

```
b6f677491cc6e1ee0440afbc42568e9e114a6f963a2ee0a8780c7939e40e8012   CN=EasyTier Local Build
```

Each asset also carries a SLSA provenance attestation (`slsa-github-generator`,
public Rekor transparency log); the release body links both. Builds have been
observed to be byte-for-byte reproducible across independent runners at the same
commit.

## Upstream tracking

| Path | Upstream | Branch | Sync mechanism |
|---|---|---|---|
| `sing-box/` | `reF1nd/sing-box` | `reF1nd-testing` | `git subtree pull` (source merge) |
| `sfa/` | `reF1nd/sing-box-for-android` | `dev` | `git subtree pull` (source merge) |
| EasyTier core | `EasyTier/easytier` | `main` / release tags | dependency pin in `sing-box/go.mod` → `easytier-go` (which vendors the wasm core) |

```bash
scripts/sync-upstream.sh status      # read-only: how far behind each upstream is
scripts/sync-upstream.sh singbox     # subtree pull, stops on conflict (no auto-resolve)
scripts/sync-upstream.sh sfa         # subtree pull, stops on conflict
scripts/sync-upstream.sh easytier    # reports the pin vs upstream and prints the line to edit
```

This repository is **not** a GitHub fork: the original fork relationships were
dissolved by a visibility change (a GitHub-side consequence of private → public,
not recoverable from the owner's side), so upstream synchronization is explicit
and scripted rather than implicit.

## License

Both `sing-box/` and `sfa/` are licensed under the **GNU General Public License
v3.0 or later**, Copyright (C) 2022 nekohasekai, each with the additional
condition that no derivative work may use the application name or imply
association without prior consent. See [`LICENSE`](LICENSE), [`NOTICE`](NOTICE),
`sing-box/LICENSE` and `sfa/LICENSE`.

Complete corresponding source for every published APK is this repository at the
tagged commit, including the build recipe. Files written for this repository are
offered under the same GPL-3.0-or-later terms. Upstream code retains its own
copyright and license.

## Known limitations

- `lazy` mode does not work on Android (missing SocketFactory; see the table above).
- Only `arm64-v8a` is published.
- No TUN/ICMP through the embedded core — the overlay is a socket-level hop.
- Upstream synchronization is manual by necessity (no fork relationship).
- Single-maintainer project; releases are alpha-quality builds of an alpha
  upstream client.

## Security

See [`.github/SECURITY.md`](.github/SECURITY.md) for vulnerability reporting and
for how signing credentials are handled.

---

## 中文简述

把 EasyTier 组网内核以 WebAssembly（wazero）**内嵌进 sing-box**，做成一个
`easytier` 出站，于是安卓上一个 `VpnService` 同时承担代理与组网，不必再装第二个
VPN 应用。本仓同时放 `sing-box/`（内嵌出站的实现）与 `sfa/`（安卓客户端），CI 一次
构建出 aar 并产出**已签名 APK**，附带 `SHA256SUMS` 与 SLSA 来源证明。

- 两个子目录均为上游项目的 GPL-3.0-or-later 修改版，许可证与附加条款原样保留；
  本仓发布物一律标注为非官方第三方构建，不与任何上游项目产生关联暗示（见 `NOTICE`）。
- 已发布产物一律可用 `sha256sum -c SHA256SUMS` 与上面的证书指纹自行核对；同一 commit
  在不同 runner 上构出过逐字节相同的产物。
- 明确不可用：`lazy`（安卓缺 SocketFactory，开了会自锁）；明确不提供：经由内核对的
  TUN/ICMP。
- 上游同步：`scripts/sync-upstream.sh`（本仓不是 GitHub 意义上的 fork，关系已被可见性
  变更剥离，只能显式同步）。
