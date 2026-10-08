#!/usr/bin/env bash
# Install the engine runtime from the public entrypoint release that holds
# the calling workflow: tfpr, the bundled gate scripts and the setup-tools
# action. No token and no private repository are involved. Every file is
# checked against the release's SHA256SUMS, and any failure stops the job:
# there is no source to fall back to.
#
# Env in: TFPR_RUNTIME_REF (job.workflow_ref, or a bare release tag),
# optional TFPR_RUNTIME_REPO (default nrit-solutions/tf-pr-ops),
# TFPR_RUNTIME_BASE_URL (the release download base; tests point it at a
# local directory), TFPR_RUNTIME_DIR (default $GITHUB_WORKSPACE/.tfpr-engine).
# Out: TFPR_BIN and TFPR_ENGINE_DIR to GITHUB_ENV.
set -euo pipefail

die() { echo "::error::$*" >&2; exit 1; }

repo="${TFPR_RUNTIME_REPO:-nrit-solutions/tf-pr-ops}"
ref="${TFPR_RUNTIME_REF:?TFPR_RUNTIME_REF is required}"
ref="${ref#*@}"
case "$ref" in
  refs/tags/*) tag="${ref#refs/tags/}" ;;
  refs/heads/preview/*)
    branch="${ref#refs/heads/preview/}"
    tag="preview-${branch//\//-}"
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
dest="${TFPR_RUNTIME_DIR:-${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/.tfpr-engine}"
bin_dir="${RUNNER_TEMP:-$dest}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch() {
  curl -sSfL --retry 3 -o "$tmp/$1" "$base/$1" || die "cannot download $1 from the $tag release of $repo"
}

fetch SHA256SUMS
# Every listed file except the other architecture's binary.
files=()
while read -r sum name; do
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "unexpected file name '$name' in the $tag checksums"
  [[ "$name" == tfpr_linux_* && "$name" != "$binary" ]] && continue
  files+=("$name")
  printf '%s  %s\n' "$sum" "$name" >>"$tmp/wanted.sums"
done <"$tmp/SHA256SUMS"
[[ " ${files[*]} " == *" $binary "* ]] || die "the $tag release has no $binary"

for f in "${files[@]}"; do
  fetch "$f"
done
(cd "$tmp" && sha256sum -c --quiet wanted.sums) || die "checksum mismatch in the $tag runtime"

# Replaced whole: in plan and apply the workspace is PR code, which must not
# leave its own files under the engine path.
rm -rf "$dest"
mkdir -p "$dest/scripts" "$dest/.github/actions/setup-tools" "$bin_dir"
for f in "${files[@]}"; do
  case "$f" in
    "$binary") install -m 0755 "$tmp/$f" "$bin_dir/tfpr" ;;
    setup-tools.action.yml) install -m 0644 "$tmp/$f" "$dest/.github/actions/setup-tools/action.yml" ;;
    *.sh) install -m 0755 "$tmp/$f" "$dest/scripts/$f" ;;
  esac
done

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "TFPR_BIN=$bin_dir/tfpr"
    echo "TFPR_ENGINE_DIR=$dest"
  } >>"$GITHUB_ENV"
fi
echo "installed the $tag engine runtime: $("$bin_dir/tfpr" version)"
