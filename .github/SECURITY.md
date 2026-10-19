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
- Known gap, stated plainly: no required-reviewer gate is currently enabled on
  `sign-gate` (verified behaviourally — signed runs proceed without waiting).
  So anyone able to dispatch `release.yml` can get a build signed, though not
  able to read the key, and the fingerprint guard still constrains what may be
  published. `release.yml` is `workflow_dispatch`-only, which on a public
  repository means write access is required. Enabling a required reviewer on the
  environment is the intended next hardening step.
- The signing job fails closed if any secret is missing, if the base64 payload
  does not decode to a plausible keystore, or if the resulting APK's certificate
  fingerprint differs from the one documented in the README.
- Release jobs therefore have to be considered part of the trust boundary. If the
  key is ever thought to be compromised, the published fingerprint is the way to
  detect it: any APK not matching it is not ours.

## Publishing hygiene

Code, comments, commit messages and release notes must not contain deployment
details of private networks — hostnames, public or private addresses, overlay
network names or keys, endpoint lists. This repository was scanned for those
before publication; the same expectation applies to every future commit.
