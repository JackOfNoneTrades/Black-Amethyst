#!/bin/bash
#
# Repack the per-architecture Android JRE 8 tarballs from AngelAuraMC's
# `download_jre8` GitHub Release into the layout Amethyst bundles under
# app_pojavlauncher/src/main/assets/components/jre.
#
# This mirrors the official repackjre.sh from AngelAuraMC/angelauramc-openjdk-build
# (buildjre8), adapted for the *release-asset* filenames (jre8-android-<arch>.tar.xz)
# rather than the CI-artifact names. Output is universal.tar.xz + bin-<arch>.tar.xz
# + a version stamp, exactly what the launcher's runtime unpacker expects.
#
# Requires `pack200` on PATH -- it ships with a host JDK 8 (set up in CI).
#
# Usage: repack_jre.sh <dir_with_jre8-android-*.tar.xz> <output_components/jre_dir>
set -euo pipefail

in="$1"
out="$2"

if ! command -v pack200 >/dev/null 2>&1; then
  echo "FATAL: pack200 not found on PATH (need a host JDK 8 for jar compression)" >&2
  exit 1
fi

work="$in/work"
work1="$in/work1"
mkdir -p "$work" "$work1" "$out"

find_arch_tarball() {
  # $1 = arch token in the release asset name (arm / arm64 / x86 / x86_64)
  local f
  f="$(find "$in" -maxdepth 1 -name "jre8-android-$1.tar.xz" | head -n1)"
  if [ -z "$f" ]; then
    echo "FATAL: missing JRE tarball for arch '$1' (jre8-android-$1.tar.xz) in $in" >&2
    exit 1
  fi
  echo "$f"
}

compress_jars() {
  find ./ -name '*.jar' -execdir pack200 -S-1 -g -G -E9 {}.pack {} \;
  find ./ -name '*.jar' -execdir rm {} \;
}

# makearch <jre_libs_dir_name> <arch_token_in_tarball>
makearch() {
  echo "Making $2..."
  cd "$work"
  tar xf "$(find_arch_tarball "$2")"

  # Trim tools the launcher never invokes.
  for t in rmid keytool rmiregistry tnameserv policytool orbd servertool; do
    rm -f "bin/$t"
  done

  mv release "$work1"/
  mv bin "$work1"/
  mkdir -p "$work1"/lib
  mv "lib/$1" "$work1"/lib/
  mv lib/jexec "$work1"/lib/

  XZ_OPT="-6 --threads=0" tar cJf "bin-$2.tar.xz" -C "$work1" .
  mv "bin-$2.tar.xz" "$out"/
  rm -rf "${work:?}"/* "${work1:?}"/*
}

# The universal (arch-independent) part, taken once from arm64.
makeuni() {
  echo "Making universal..."
  cd "$work"
  tar xf "$(find_arch_tarball arm64)"
  rm -rf bin
  rm -rf lib/aarch64
  rm -f lib/jexec
  rm -f release
  rm -rf lib/jfr
  rm -rf man

  compress_jars
  XZ_OPT="-6 --threads=0" tar cJf universal.tar.xz ./*
  mv universal.tar.xz "$out"/
  rm -rf "${work:?}"/*
}

makeuni
makearch aarch32 arm
makearch aarch64 arm64
makearch i386 x86
makearch amd64 x86_64

# Version stamp (the launcher uses it to decide whether to re-extract).
if [ -n "${GITHUB_SHA:-}" ]; then
  echo "$GITHUB_SHA" > "$out"/version
else
  date +%Y%m%d > "$out"/version
fi

rm -rf "${work:?}" "${work1:?}"

echo "Repacked JRE into: $out"
ls -la "$out"
