# Contributing

Thanks for looking. This is a small, self-hosted-motivated fork; changes are
welcome, but the repository has a few structural rules worth reading first.

## Where things live

| Path | What it is | How it may change |
|---|---|---|
| `sing-box/` | Upstream core + our embedded `easytier` outbound | Our changes are confined to the outbound, its options, its registration, and the `with_easytier` build tag |
| `sfa/` | Upstream Android client | Only the minimum needed to accept the patched `libbox.aar`, plus documentation |
| `scripts/sync-upstream.sh` | Upstream synchronization entry point | Keep it read-only for `status`/`easytier`; never auto-resolve conflicts |
| `.github/workflows/` | Build, sign, attest, publish | Any change to signing or publishing needs an explicit review — it is the trust boundary (see [SECURITY.md](SECURITY.md)) |

## Subtree rules

`sing-box/` and `sfa/` are `git subtree` merges, not submodules, and this
repository is not a GitHub fork. Consequences:

1. Update them with `scripts/sync-upstream.sh singbox|sfa` so the merge history
   stays intact. Do not squash, rebase, or re-import those directories.
2. Upstream conflicts stop the script on purpose. Resolve by hand, in a commit
   whose message says which upstream commit was being pulled.
3. EasyTier is a **dependency**, not a vendored tree: bump the `easytier-go` pin
   in `sing-box/go.mod`. No Rust toolchain is involved — the WebAssembly core is
   shipped inside that Go module.

## Required checks before a pull request

The regression gate (`.github/workflows/regression.yml`) runs on every push that
touches `sing-box/`, and it must stay green:

1. Full build with the project's tag set.
2. Self-check: the built binary must advertise the `easytier` outbound — a tag or
   registration regression shows up here, not as a silent feature loss.
3. `go vet`.
4. Unit tests for option defaults and for the `config_toml` / structured-field
   mutual-exclusion guard.

Add a test when you add behaviour that is invisible until it breaks (build tags,
provider registration, defaults).

## Building and signing locally

`.github/workflows/apk.yml` is the build recipe (Go 1.27.x, pinned
`sagernet/gomobile`, NDK r28, build-tools 37.0.0, JDK 17); reproduce it locally if
you need to iterate, and expect the published artifact to be rebuilt by CI anyway.

Signing keys are not available to contributors — they live in the `sign-gate`
environment. Debug builds are the normal workflow; release signing happens in CI
only, and the workflow refuses to publish if the certificate fingerprint changes.

## Not accepted

- New secrets, tokens, or credentials of any kind, in code, CI variables,
  documentation or commit messages.
- Private network details (hostnames, addresses, overlay network names or keys,
  endpoint lists) — see [SECURITY.md](SECURITY.md).
- Version strings that claim an upstream release we are not.
- Changes that alter the `easytier` behaviour when the `with_easytier` tag is
  absent; the core must build and behave exactly as upstream without it.
