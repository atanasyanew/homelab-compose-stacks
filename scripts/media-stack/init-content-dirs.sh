#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -z "${CONTENT_ROOT:-}" && -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

if [[ -z "${CONTENT_ROOT:-}" ]]; then
  printf "ERROR: CONTENT_ROOT is not set. Configure it in %s or export it in your shell.\n" "${ENV_FILE}" >&2
  exit 1
fi

if [[ "${CONTENT_ROOT}" = /* ]]; then
  CONTENT_ROOT_ABS="${CONTENT_ROOT}"
else
  CONTENT_ROOT_ABS="${ROOT_DIR}/${CONTENT_ROOT#./}"
fi

dirs=(
  "media/movies favorite"
  "media/movies"
  "media/kids"
  "media/music"
  "media/tv"
  "torrents/movies"
  "torrents/music"
  "torrents/tv"
  "usenet/movies"
  "usenet/music"
  "usenet/tv"
)

mkdir -p "${CONTENT_ROOT_ABS}" "${ROOT_DIR}/provision"

for dir in "${dirs[@]}"; do
  mkdir -p "${CONTENT_ROOT_ABS}/${dir}"
done

printf "Initialized media stack directories under: %s\n" "${CONTENT_ROOT_ABS}"
printf "Ensured provision directory exists: %s/provision\n" "${ROOT_DIR}"
