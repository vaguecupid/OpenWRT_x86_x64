#!/usr/bin/env bash
set -euo pipefail
mode=${1:?Expected pack or unpack}
cd "${GITHUB_WORKSPACE:?}"
case "$mode" in
  pack)
    test -d openwrt/staging_dir
    test -d openwrt/build_dir
    # Prevent mixing a new state with chunks from a previous checkpoint.
    if [ -e checkpoint ]; then
      mv checkpoint "checkpoint-input-${GITHUB_JOB:?}-${GITHUB_RUN_ATTEMPT:?}"
    fi
    mkdir checkpoint
    realpath openwrt > openwrt/.ci-build-root
    git -C openwrt rev-parse HEAD > openwrt/.ci-source-revision
    # PAX tar retains symlinks, executability, and sub-second mtimes.
    # Preserve the whole source, feeds, downloads, staging, build dirs and stamps.
    # The disposable ccache is omitted; compiled object files are retained.
    tar --format=posix --exclude='openwrt/.ccache' -cf - openwrt \
      | zstd -T0 -3 -c \
      | split -b 1900M - checkpoint/state.tar.zst.part-
    (cd checkpoint && sha256sum state.tar.zst.part-* > SHA256SUMS)
    du -sh checkpoint
    ;;
  unpack)
    test ! -e openwrt
    (cd checkpoint && sha256sum -c SHA256SUMS)
    cat checkpoint/state.tar.zst.part-* | zstd -d -c | tar -xpf -
    # Build files contain absolute paths; do not silently relocate them.
    test "$(cat openwrt/.ci-build-root)" = "$(realpath openwrt)" || {
      echo '::error::Runner workspace path differs from the original build path.'
      exit 1
    }
    test "$(git -C openwrt rev-parse HEAD)" = "$(cat openwrt/.ci-source-revision)"
    echo "Restored source revision: $(cat openwrt/.ci-source-revision)"
    ;;
  *) echo "Unknown mode: $mode" >&2; exit 2;;
esac
