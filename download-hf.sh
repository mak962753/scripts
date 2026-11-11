#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") [--seq] [--tool curl|aria2c] <org/repo> [output-dir] [include-prefix]

  --seq            one file at a time, single connection (slow links)
  --tool TOOL      download tool: aria2c (default) or curl
  org/repo         Hugging Face repo, e.g. mlx-community/gemma-3-270m-it-4bit
  output-dir       default: /Volumes/External-001/models/<repo>
  include-prefix   optional subfolder filter, e.g. 4-bit  (downloads 4-bit/* only)

  HF_TOKEN         optional; required for gated repos (HF read token)
  SEQUENTIAL=1     same as --seq

examples:
  $(basename "$0") --seq chimingw/Qwen3.8-27B-Uncensored-OrcaRouter-MLX-4bit
  $(basename "$0") mlx-community/gemma-3-270m-it-4bit
  HF_TOKEN=hf_... $(basename "$0") orcarouter/Qwen3.8-27B-Uncensored-MLX "" 4-bit
EOF
  exit 1
}

SEQUENTIAL="${SEQUENTIAL:-0}"
TOOL="${TOOL:-aria2c}"
while [[ "${1-}" == "--seq" || "${1-}" == "--tool" ]]; do
  if [[ "$1" == "--seq" ]]; then
    SEQUENTIAL=1
  else
    TOOL="${2-}"
    [[ -n "$TOOL" && ("$TOOL" == curl || "$TOOL" == aria2c) ]] || usage
    shift
  fi
  shift
done

[[ "$TOOL" == curl || "$TOOL" == aria2c ]] || usage

REPO="${1-}"
[[ -n "$REPO" ]] || usage

DIR="${2:-/Volumes/External-001/models/$REPO}"
INCLUDE="${3-}"

mkdir -p "$DIR"

curl_args=(-fsSL "https://huggingface.co/api/models/$REPO/tree/main?recursive=1")
download_args=()
if [[ "$TOOL" == aria2c ]]; then
  if [[ "$SEQUENTIAL" == 1 ]]; then
    # -j 1: one file at a time; -x/-s 1: no per-file splitting
    download_args=(-j 1 -x 1 -s 1 -c -d "$DIR" -i -)
  else
    download_args=(-j 5 -x 8 -s 8 -c -d "$DIR" -i -)
  fi
else
  download_args=(-fSL)
fi

if [[ -n "${HF_TOKEN:-}" ]]; then
  curl_args=(-fsSL -H "Authorization: Bearer $HF_TOKEN"
    "https://huggingface.co/api/models/$REPO/tree/main?recursive=1")
  if [[ "$TOOL" == aria2c ]]; then
    download_args+=(--header="Authorization: Bearer $HF_TOKEN")
  else
    download_args=(-H "Authorization: Bearer $HF_TOKEN")
  fi
fi

echo "repo:    $REPO"
echo "dir:     $DIR"
[[ -n "$INCLUDE" ]] && echo "include: ${INCLUDE%/}/*"
echo "tool:    $TOOL"
if [[ "$SEQUENTIAL" == 1 ]]; then
  echo "mode:    sequential (1 file, 1 connection)"
else
  echo "mode:    parallel (5 files, 8 connections each)"
fi
[[ -n "${HF_TOKEN:-}" ]] && echo "auth:    HF_TOKEN set" || echo "auth:    none (gated repos need HF_TOKEN)"

curl "${curl_args[@]}" |
  python3 -c "
import json, sys

repo = sys.argv[1]
include = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else ''
prefix = f\"{include.rstrip('/')}/\" if include else ''

data = json.load(sys.stdin)
lines = []
total = 0
for entry in data:
    if entry.get('type') != 'file':
        continue
    path = entry['path']
    if prefix and not path.startswith(prefix):
        continue
    size = entry.get('size') or 0
    total += size
    lines.append(f'https://huggingface.co/{repo}/resolve/main/{path}\t{path}')

if not lines:
    where = f' under {prefix}' if prefix else ''
    print(f'no files found for {repo}{where}', file=sys.stderr)
    sys.exit(1)

n = len(lines)
print(f'downloading {n} files ({total / 1024**3:.2f} GiB)', file=sys.stderr)
print('\n'.join(lines))
" "$REPO" "$INCLUDE" |
  if [[ "$TOOL" == aria2c ]]; then
    # aria2c wants 'url\n  out=relative/path' per entry
    awk -F'\t' '{print $1; print "  out=" $2}' - | aria2c "${download_args[@]}"
  else
    while IFS=$'\t' read -r url path; do
      [[ -n "$url" ]] || continue
      mkdir -p "$DIR/$(dirname "$path")"
      curl "${download_args[@]}" -o "$DIR/$path" "$url"
    done
  fi
