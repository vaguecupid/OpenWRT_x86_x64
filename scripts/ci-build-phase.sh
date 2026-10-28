#!/usr/bin/env bash
set -euo pipefail
phase=${1:?Expected bootstrap, packages, or image}
case "$phase" in bootstrap|packages|image) ;; *) echo "Unknown phase: $phase" >&2; exit 2;; esac
cd "${GITHUB_WORKSPACE:?}/openwrt"
# Use at most the first five hours of this job for compilation.
# The remaining hour covers checkpoint compression, upload, and cleanup.
build_seconds=$(( ${JOB_START_EPOCH:?} + 300 * 60 - $(date +%s) ))
if [ "$build_seconds" -le 0 ]; then
  echo '::error::Preparation exhausted the build budget.'
  exit 1
fi
echo "Phase: $phase; CPUs: $(nproc); remaining build budget: $((build_seconds / 60)) minutes"
export OPENWRT_CI_PHASE="$phase"
timeout --signal=TERM --kill-after=60s "${build_seconds}s" bash -euo pipefail -c '
  case "$OPENWRT_CI_PHASE" in
    bootstrap)
      make -j"$(nproc)" tools/install
      make -j"$(nproc)" toolchain/install
      make -j"$(nproc)" target/compile
      ;;
    packages)
      make -j"$(nproc)" package/compile
      ;;
    image)
      # Run the normal world target to finish install, metadata, and images.
      # Previous stages and their stamps are restored, so they can be reused.
      make -j"$(nproc)"
      ;;
  esac
' 2>&1 | tee "ci-${phase}.log"
if [ "$phase" = image ]; then
  echo "date1=$(date +'%Y.%m.%d')" >> "$GITHUB_ENV"
  echo "date2=$(date +'%Y年%m月%d日')" >> "$GITHUB_ENV"
fi
echo 'status=success' >> "$GITHUB_OUTPUT"
