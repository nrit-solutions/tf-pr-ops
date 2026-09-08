# tf-pr-ops

The public entrypoint of the NRIT pull-request ops engine: plan and apply
Terraform and Terragrunt from a pull request, driven by comments, with unit
locks, drift detection, and policy, scan, and cost gates.

This repository holds the released copies of the reusable workflows, the
dispatch action, and the caller examples. The engine itself (the `tfpr`
binary and the gate scripts) lives in the private core repository
`nrit-solutions/nrit-tf-pr-ops`. Every job here checks the core out at the
same version with a GitHub App token that NRIT issues per organisation, so a
pinned tag always runs the code it was released with.

## Consuming

Copy the four callers from `examples/` into `.github/workflows/` of an
infrastructure repository and pin all of them to one tag:

| Caller | Purpose |
| --- | --- |
| `caller-tf-pr-ops-pr.yml` | the pull_request path: lint, then the dispatch action |
| `caller-tf-pr-ops-unlock.yml` | releases unit locks when a pull request closes |
| `caller-tf-pr-ops.yml` | comment commands (`/plan`, `/apply`, `/unlock`) and dispatched work |
| `caller-drift.yml` | the scheduled drift sweep |

The `uses:` ref and the `engine_ref` input carry the same exact version, and
both move together on every upgrade. Tags are immutable; there is no moving
major tag.

The callers need the variables and secrets the bootstrap sets on a generated
repository, including `ENGINE_APP_CLIENT_ID` and `ENGINE_APP_PRIVATE_KEY`
for the engine App. Setup, commands, gates, and operations are documented at
https://docs.nrit.cloud.

## About this repository

Nothing is authored here. The core's release job writes this tree, tags it
with the core's version, and records the core commit in `ENGINE_COMMIT`.
Branches under `preview/` are short-lived smoke builds. The files here are
licensed under Apache-2.0 (see LICENSE); the private core is not. Open issues on the
docs site's contact address, not here.
