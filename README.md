# tf-pr-ops

Plan and apply Terraform and Terragrunt from a pull request, driven by
comments, with unit locks, drift detection, and policy, scan, and cost gates.

This repository holds the released copies of the reusable workflows, the
dispatch action, and the caller examples. Each release also carries the
runtime: the `tfpr` binary, the bundled gate scripts and the setup-tools
action. Consumer jobs install that runtime from the release. They need no
access to any other repository and no credential beyond the workflow token.

## Consuming

Copy the five callers from `examples/` into `.github/workflows/` of an
infrastructure repository and pin all of them to one tag:

| Caller | Purpose |
| --- | --- |
| `caller-tf-pr-ops-pr.yml` | the pull_request path: lint, then the dispatch action |
| `caller-tf-pr-ops-unlock.yml` | releases unit locks when a pull request closes |
| `caller-tf-pr-ops-review.yml` | refreshes the approval row when a review is submitted or dismissed |
| `caller-tf-pr-ops.yml` | comment commands (`/plan`, `/apply`, `/unlock`, `/help`) and dispatched work |
| `caller-drift.yml` | the scheduled drift sweep |

The `uses:` ref is the only pin. Each job installs the runtime attached to
the release of that tag and checks every file against the `SHA256SUMS` file
committed at that tag, not the release's copy. Tags are immutable. There is
no moving major tag.

The callers need the variables, secrets and environments listed at
https://docs.nrit.cloud/setup/secrets-and-variables/, including the
`TFPR_LICENSE` and `TFPR_ENTITLEMENT` variables that `/apply` needs (see
https://docs.nrit.cloud/operations/license/). Setup, commands, gates and
operations are documented at https://docs.nrit.cloud/.

## About this repository

Nothing is authored here. A release job writes this tree, tags it, records
the source commit in `ENGINE_COMMIT`, and commits the runtime checksums in
`SHA256SUMS`. Branches under `preview/` are short-lived smoke builds. The
files in this tree are licensed under Apache-2.0 (see LICENSE). The runtime
attached to each release (the `tfpr` binaries, the gate scripts, `lib.sh`
and `setup-tools.action.yml`) is proprietary and is not covered by that
license: see `ENGINE-LICENSE.txt` on the release. `install-runtime.sh` and
`SHA256SUMS` are Apache-2.0 in both places. Use the contact link on the docs
site for questions. Issues are not tracked here.
