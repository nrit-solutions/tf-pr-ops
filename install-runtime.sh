#!/usr/bin/env bash
# Install the engine runtime from the public entrypoint release that holds
# the calling workflow: tfpr, the bundled gate scripts and the setup-tools
# action. No private repository is involved. Every file is checked against
# the SHA256SUMS committed in the entrypoint tree at the calling workflow's
# commit, not against the release's copy, so a release asset that was swapped
# after the tag cannot pass. Any failure stops the job: there is no source to
# fall back to.
#
# Env in: TFPR_RUNTIME_REF (job.workflow_ref, or a bare release tag),
# TFPR_RUNTIME_SHA (job.workflow_sha, the entrypoint commit holding the
# workflow), optional GH_TOKEN (read the tree with it),
# TFPR_RUNTIME_REPO (default nrit-solutions/tf-pr-ops),
# TFPR_RUNTIME_BASE_URL (the release download base; tests point it at a
# local directory), TFPR_RUNTIME_SUMS_URL (the tree's SHA256SUMS; tests point
# it at a local file), TFPR_RUNTIME_DIR (default $RUNNER_TEMP/tfpr-engine,
# outside the checkout).
# Out: TFPR_BIN and TFPR_ENGINE_DIR to GITHUB_ENV, and a copy of the
# setup-tools action at $GITHUB_WORKSPACE/.tfpr-engine, because a local
# `uses:` path must be inside the workspace. Each job installs after its last
# checkout and before any PR code runs, so the copy is the release's.
set -euo pipefail

die() { echo "::error::$*" >&2; exit 1; }

repo="${TFPR_RUNTIME_REPO:-nrit-solutions/tf-pr-ops}"
ref="${TFPR_RUNTIME_REF:?TFPR_RUNTIME_REF is required}"
sha="${TFPR_RUNTIME_SHA:?TFPR_RUNTIME_SHA is required}"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "TFPR_RUNTIME_SHA must be a full commit SHA, got '$sha'"
ref="${ref#*@}"
case "$ref" in
  refs/tags/*) tag="${ref#refs/tags/}" ;;
  refs/heads/preview/*)
    branch="${ref#refs/heads/preview/}"
    tag="preview-${branch//\//-}-${sha:0:12}"
    ;;
  v[0-9]* | preview-*) tag="$ref" ;;
  *) die "no engine runtime for '$ref': pin the caller to a release tag, or to a preview branch for a smoke" ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) binary=tfpr_linux_amd64 ;;
  aarch64 | arm64) binary=tfpr_linux_arm64 ;;
  *) die "no tfpr build for $(uname -m)" ;;
esac

base="${TFPR_RUNTIME_BASE_URL:-https://github.com/$repo/releases/download}/$tag"
workspace="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
dest="${TFPR_RUNTIME_DIR:-${RUNNER_TEMP:?RUNNER_TEMP is required}/tfpr-engine}"
bin_dir="${RUNNER_TEMP:-$dest}"
action_stage="$workspace/.tfpr-engine"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch() {
  curl -sSfL --retry 3 -o "$tmp/$1" "$base/$1" || die "cannot download $1 from the $tag release of $repo"
}

sums_url="${TFPR_RUNTIME_SUMS_URL:-${GITHUB_API_URL:-https://api.github.com}/repos/$repo/contents/SHA256SUMS?ref=$sha}"
auth=()
[[ -n "${GH_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GH_TOKEN")
curl -sSfL --retry 3 ${auth[@]+"${auth[@]}"} -H "Accept: application/vnd.github.raw" -o "$tmp/SHA256SUMS" "$sums_url" \
  || die "cannot read SHA256SUMS from $repo at ${sha:0:12}, the commit of the $tag workflow"
# Every listed file except the other architecture's binary.
files=()
while read -r sum name; do
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "unexpected file name '$name' in the $tag checksums"
  [[ "$name" == tfpr_linux_* && "$name" != "$binary" ]] && continue
  [[ "$name" == ENGINE-LICENSE.txt ]] && continue
  files+=("$name")
  printf '%s  %s\n' "$sum" "$name" >>"$tmp/wanted.sums"
done <"$tmp/SHA256SUMS"
[[ " ${files[*]} " == *" $binary "* ]] || die "the $tag release has no $binary"

for f in "${files[@]}"; do
  fetch "$f"
done
(cd "$tmp" && sha256sum -c --quiet wanted.sums) || die "checksum mismatch in the $tag runtime: a release file differs from the SHA256SUMS in $repo at ${sha:0:12}"

# Replaced whole: in plan and apply the workspace is PR code, which must not
# leave its own files under the engine paths.
rm -rf "$dest" "$action_stage"
mkdir -p "$dest/scripts" "$dest/.github/actions/setup-tools" "$bin_dir" "$action_stage/.github/actions"
for f in "${files[@]}"; do
  case "$f" in
    "$binary") install -m 0755 "$tmp/$f" "$bin_dir/tfpr" ;;
    setup-tools.action.yml) install -m 0644 "$tmp/$f" "$dest/.github/actions/setup-tools/action.yml" ;;
    *.sh) install -m 0755 "$tmp/$f" "$dest/scripts/$f" ;;
  esac
done

cp -R "$dest/.github/actions/setup-tools" "$action_stage/.github/actions/setup-tools"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "TFPR_BIN=$bin_dir/tfpr"
    echo "TFPR_ENGINE_DIR=$dest"
  } >>"$GITHUB_ENV"
fi
echo "installed the $tag engine runtime: $("$bin_dir/tfpr" version)"
