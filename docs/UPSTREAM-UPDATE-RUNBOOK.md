# Upstream update runbook

Three upstreams, three different mechanisms. In every case the sequence is the
same: change source or pin → push → let the gate run → `release.yml` produces the
signed APK. `scripts/sync-upstream.sh` never pushes and never auto-resolves a
conflict; pushing and publishing stay explicit human actions.

## 0. Rebuild an APK without changing any code

```bash
gh workflow run release.yml --repo AcccBa/singbox-easytier -f prerelease=true -f attest=true
gh workflow run apk.yml     --repo AcccBa/singbox-easytier -f platform=android/arm64
```

Acceptance: run green → `sha256sum -c SHA256SUMS` → `apksigner verify --print-certs`
matches the fingerprint in the README → install over the previous build.

## A. Core update (`reF1nd/sing-box`, branch `reF1nd-testing`)

```bash
scripts/sync-upstream.sh status      # read-only: how far behind, and what
scripts/sync-upstream.sh singbox     # git subtree pull; on conflict: list files, merge --abort
git push origin HEAD                 # only after you have looked at it
```

Pushing touches `sing-box/**`, so `regression.yml` runs automatically. Acceptance
is the job log, not the green icon alone: the built binary must advertise the
`easytier` outbound and every test must show `--- PASS`.

What the gate does **not** catch: semantic drift in the `corehost`/wazero
interface the embedded core depends on (it compiles and still behaves wrong). For
a core bump, run a socket-level smoke test against a real overlay before
publishing — that needs a Go toolchain, which is not installed on the maintainer
machine any more (see C).

## B. Client update (`reF1nd/sing-box-for-android`, branch `dev`)

```bash
scripts/sync-upstream.sh sfa
```

Expect conflicts; resolve them this way and only this way:

| File | Rule |
|---|---|
| `sfa/version.properties` | Keep our `VERSION_NAME` line (`…-reF1nd`). `VERSION_CODE` is monotonic and must stay ≥ what is already installed on devices, otherwise the upgrade cannot be installed in place. |
| `sfa/README.md`, `sfa/app/proguard-rules.pro` | Keep ours (fork attribution note, keep rules). |

Note: `regression.yml` is triggered by `sing-box/**` only. A client-only sync
therefore needs an explicit compile gate before publishing:

```bash
gh workflow run apk.yml --repo AcccBa/singbox-easytier
```

## C. EasyTier update

```bash
scripts/sync-upstream.sh easytier    # read-only: current pin vs upstream, prints the line
```

EasyTier is a **dependency** (`easytier-go` in `sing-box/go.mod`), not a vendored
tree; the WebAssembly core ships inside that module, so no Rust is involved. A
bump needs `go get` + `go mod tidy` to regenerate `go.sum`, which needs Go:

* Preferred: a CI job that installs Go, runs `go get easytier-go@<sha> && go mod
  tidy`, and opens a pull request so the regression gate is the reviewer. (Not
  implemented yet.)
* Acceptable: an ephemeral `golang` container for the two commands.
* Not possible: hand-editing the `go.mod` line and letting CI deal with it —
  Go refuses to build with missing `go.sum` entries, so CI fails identically.

## D. Rollback

Downgrade installs are refused by Android for the same signing key, so rollback
means uninstall + reinstall of an older release asset: the overlay session drops
and configuration must be re-entered. Release assets are permanent; check the
version code before assuming an older APK is installable.

## Tracking decision

Both trees follow the `reF1nd` fork lines (`reF1nd-testing`, `dev`), confirmed
2026-10-19 rather than re-derived. The `reF1nd` lines are independent active
development (their recent work — Android process-path handling, Linux path-scan
coalescing, QUIC/GSO controls, HTTP/3 congestion selection — does not appear in
the official `SagerNet` repositories' recent history), which suits an
APK-producing fork. No divergence measurement against the official lines was
performed, and no original decision record exists for the choice; treat it as a
working default, not a conclusion.
