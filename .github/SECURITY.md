# Security Policy

## Scope

This repository ships modified binaries of a network proxy core and its Android
client, plus the CI that builds and signs them. Security issues we want to hear
about:

- Anything that lets a malicious proxy/overlay peer execute code, read memory, or
  escape the app sandbox — including through the embedded WebAssembly core.
- Mishandling of credentials: the overlay network key, the signing key, or CI
  secrets becoming readable outside their intended boundary.
- A published artifact that does not correspond to the tagged source, or whose
  signing certificate differs from the published fingerprint.
- CI/workflow weaknesses that allow an unsigned or differently-signed artifact to
  be published under a release tag.

Out of scope (by design, not defects):

- The overlay network key being present in the app's own configuration — it is a
  shared group secret stored in app-private storage, same as upstream clients.
- Traffic analysis, or the general trust properties of an overlay you join.
- Vulnerabilities in unmodified upstream code — report those upstream first
  (`reF1nd/sing-box`, `EasyTier/easytier`); we will pick up the fix as soon as it
  reaches the tracked branches.

## Reporting

Open a **private vulnerability report** from the Security tab of this repository.
If that option is unavailable on this account, open an issue containing only
"security issue, details by private message" and contact me through the address in
my GitHub profile; details go in private.

There is no bug bounty. Expect a response within a few days; this is a
single-maintainer project.

## How signing credentials are handled here

- The keystore and its passphrases exist only as secrets in the GitHub Actions
  environment `sign-gate` — not as repository-level secrets, never in an
  artifact, never echoed in a log. A job can only read them by declaring that
  environment.
- Publishing is gated by a human: the `sign-gate` environment has a required
  reviewer, so the `sign` job halts in `waiting` after a successful build and
  signs nothing until approved. Verified behaviourally on 2026-10-19 (run
  39328721639: build success → sign `waiting` → approved → publish success).
  Note what this gate does and does not mean: it stops an unattended dispatch
  from producing a signed artifact, but the reviewer is the repository owner and
  self-review is permitted, so it is a "second moment of attention", not a
  second person. `release.yml` is `workflow_dispatch`-only, which on a public
  repository already requires write access.
- The signing job fails closed if any secret is missing, if the base64 payload
  does not decode to a plausible keystore, or if the resulting APK's certificate
  fingerprint differs from the one documented in the README.
- Release jobs therefore have to be considered part of the trust boundary. If the
  key is ever thought to be compromised, the published fingerprint is the way to
  detect it: any APK not matching it is not ours.

## Findings inherited from upstream history

Because `sing-box/` and `sfa/` are `git subtree` merges, upstream history is part
of this repository, and secret scanning scans history — so alerts can point at
content we never wrote and do not currently ship. Every hit found here was
checked for whether it exists at `HEAD`; all three do not:

| Pattern hit | Location in history | Verdict |
|---|---|---|
| Google API key (`AIzaSy…`) | `app/google-services.json` (Firebase config of the upstream SFA app; removed upstream in commit `56a27728 "Remove google services"`) | Upstream's own project key, absent from this tree for a long time. Android API keys of this kind are embedded in shipped APKs by design and rely on package/referrer restrictions, not secrecy. We cannot rotate a key that is not ours, and rewriting ~3.4k imported commits to erase the blob would destroy the subtree relationship and make future `subtree pull` impossible — so the alert is resolved as not-a-secret here, with this note as the audit trail. |
| PEM private key | `test/config/example.org-key.pem` | Upstream unit-test fixture for a synthetic `example.org` certificate; absent at `HEAD`. |
| Long `api_key = "…"` literal | `docs/configuration/service/ccm.md{,.zh}` | Upstream documentation example; absent at `HEAD`. |

To re-check after any upstream sync:

```bash
scripts/secret-scan.sh --smoke      # first: prove the scanner itself works (both directions)
scripts/secret-scan.sh --worktree   # seconds; what we are actually shipping
scripts/secret-scan.sh              # full history blob scan; exits non-zero on hits
```

## Publishing hygiene

Code, comments, commit messages and release notes must not contain deployment
details of private networks — hostnames, public or private addresses, overlay
network names or keys, endpoint lists. This repository was scanned for those
before publication; the same expectation applies to every future commit.
