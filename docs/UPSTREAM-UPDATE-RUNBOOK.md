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

`apk.yml` is the real compile gate for client changes (`regression.yml` only runs
Go checks and would prove nothing about Kotlin/Gradle). It now runs automatically
on any push touching `sfa/**`, so a client sync is compile-checked without an
extra step; `workflow_dispatch` remains available for a manual/one-off build.

## C. EasyTier update

```bash
scripts/sync-upstream.sh easytier    # read-only: current pin vs upstream, prints the line
```

EasyTier is a **dependency** (`easytier-go` in `sing-box/go.mod`), not a vendored
tree; the WebAssembly core ships inside that module, so no Rust is involved. A
bump needs `go get` + `go mod tidy` to regenerate `go.sum`, which needs Go:

* Done: `.github/workflows/bump-easytier.yml` — dispatch it with `target=<commit |
  tag | latest>`:

  ```bash
  gh workflow run bump-easytier.yml --repo AcccBa/singbox-easytier --ref main -f target=latest
  ```

  It resolves the target, runs `go get` + `go mod tidy` + `go mod verify`, asserts
  that the prebuilt WebAssembly core is present in the new module (that check is
  why no Rust toolchain is involved), then pushes `bump/easytier-<short>` and
  opens a pull request. It never touches `main`. Re-dispatching the same target
  reuses the branch instead of leaving junk branches around; if there is nothing
  to change it says so and opens no PR.
* The PR's regression gate does start automatically (`pull_request`), but a run
  initiated by the Actions bot stops at `action_required` until a human releases
  it — that is GitHub's first-time-contributor gate, not a bug. Release it from
  the UI, or:

  ```bash
  gh api -X POST repos/AcccBa/singbox-easytier/actions/runs/<run_id>/approve
  ```

  Merge only after that run is green; publishing is still a separate manual
  `release.yml`.
* Not possible: hand-editing the `go.mod` line and letting CI deal with it —
  Go refuses to build with missing `go.sum` entries, so CI fails identically.

Module-proxy flakiness is a real hazard here: `proxy.golang.org` intermittently
returns `stream error … INTERNAL_ERROR`, which shows up as a red build on any
cold module cache (a PR that changes `go.sum` is always cold). Both the bump job
and the regression gate now prewarm dependencies with bounded retries, and a
single transient failure no longer produces a false red.

## D. Rollback

Downgrade installs are refused by Android for the same signing key, so rollback
means uninstall + reinstall of an older release asset: the overlay session drops
and configuration must be re-entered. Release assets are permanent; check the
version code before assuming an older APK is installable.

## Gate inventory (what runs when)

| Trigger | Workflow | What it proves |
|---|---|---|
| push touching `sing-box/**` | `regression.yml` | full-tag build, binary advertises the `easytier` outbound, `go vet`, unit tests (flag defaults, `config_toml` conflict guard) |
| push touching `sfa/**` | `apk.yml` | aar builds and the client compiles into an unsigned release APK |
| `workflow_dispatch` on `bump-easytier.yml` | itself + the PR's `regression.yml` | dependency bump is coherent and mergeable |
| `workflow_dispatch` on `release.yml` | build → **human approval** → sign → attest → publish | publishable artifact with provenance |

`release.yml` stops before signing: the `sign` job waits on the `sign-gate`
environment's required reviewer. Approve it in the Actions UI, or:

```bash
EID=$(gh api repos/AcccBa/singbox-easytier/actions/runs/<run_id>/pending_deployments --jq '.[0].environment.id')
gh api -X POST repos/AcccBa/singbox-easytier/actions/runs/<run_id>/pending_deployments \
  -F "environment_ids[]=$EID" -f state=approved -f comment="reason"
```

(The endpoint takes `environment_ids`, not names; a run left unapproved simply
never signs, and the unsigned artifact is already archived by then.)

## Tracking decision

Both trees follow the `reF1nd` fork lines (`reF1nd-testing`, `dev`), confirmed
2026-10-19 rather than re-derived. The `reF1nd` lines are independent active
development (their recent work — Android process-path handling, Linux path-scan
coalescing, QUIC/GSO controls, HTTP/3 congestion selection — does not appear in
the official `SagerNet` repositories' recent history), which suits an
APK-producing fork. No divergence measurement against the official lines was
performed, and no original decision record exists for the choice; treat it as a
working default, not a conclusion.
