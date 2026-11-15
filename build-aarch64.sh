#!/bin/sh
# Builds this fork on a 64-bit ARM host (tested on a Raspberry Pi 5, aarch64).
#
# Everything the build needs is bootstrapped into $TOOLCHAIN if missing:
#
#   $TOOLCHAIN/jdk-17*/         full JDK (Temurin); AGP needs bin/jlink
#   $TOOLCHAIN/aapt2dir/aapt2   x86_64 aapt2 from the AGP artifact (Google ships
#                               no aarch64 build)
#   $TOOLCHAIN/x86root/         minimal x86_64 glibc (libc6 + libgcc-s1), because
#                               the Pi has no x86_64 libs of its own
#   $TOOLCHAIN/aapt2wrap/aapt2  shim that runs the above under qemu-user
#   $ANDROID_HOME/              Android SDK platform 35 + build-tools, via
#                               cmdline-tools sdkmanager, if android-35 is absent
#
# Override with TOOLCHAIN=, JAVA_HOME=, ANDROID_HOME=, DEBIAN_MIRROR= as needed.
# The release keystore is optional: without keystore.properties the APK is built
# unsigned (see README).
set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOOLCHAIN=${TOOLCHAIN:-$HOME/android-toolchain}
ANDROID_HOME=${ANDROID_HOME:-$HOME/android-sdk}
DEBIAN_MIRROR=${DEBIAN_MIRROR:-https://deb.debian.org/debian}

AAPT2_VERSION=8.7.3-12006047
JDK_URL=https://api.adoptium.net/v3/binary/latest/17/ga/linux/aarch64/jdk/hotspot/normal/eclipse
CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -m)" = aarch64 ] ||
  log "warning: this script is written for aarch64; continuing anyway"
for t in curl unzip tar ar xz; do
  command -v "$t" >/dev/null 2>&1 || die "required tool missing: $t"
done

mkdir -p "$TOOLCHAIN"

# ---------------------------------------------------------------- JDK --------
ensure_jdk() {
  if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/jlink" ]; then
    for d in "$TOOLCHAIN"/jdk-*; do
      [ -x "$d/bin/jlink" ] && JAVA_HOME=$d
    done
  fi
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/jlink" ]; then
    log "JDK: $JAVA_HOME"
    return
  fi
  log "downloading JDK 17 (Temurin, aarch64)"
  mkdir -p "$TOOLCHAIN/jdkdl"
  tarball=$TOOLCHAIN/jdkdl/jdk17.tar.gz
  [ -s "$tarball" ] || curl -fL --retry 3 -o "$tarball" "$JDK_URL" ||
    die "JDK download failed"
  tar xzf "$tarball" -C "$TOOLCHAIN" || die "JDK extraction failed"
  for d in "$TOOLCHAIN"/jdk-*; do
    [ -x "$d/bin/jlink" ] && JAVA_HOME=$d
  done
  [ -n "${JAVA_HOME:-}" ] || die "no JDK with bin/jlink under $TOOLCHAIN"
  log "JDK: $JAVA_HOME"
}

# --------------------------------------------------- aapt2 + x86_64 root -----
# Resolve "<package>_<ver>_amd64.deb" from a Debian pool directory listing, so
# security updates changing the point release do not break the bootstrap.
deb_filename() { # $1 = pool path below pool/main/, $2 = filename regex
  listing=$DEBIAN_MIRROR/pool/main/$1/
  curl -fsSL --max-time 90 "$listing" | grep -o "$2" | sort -uV | tail -1
}

extract_deb() { # $1 = deb file, $2 = destination root
  tmp=$(mktemp -d)
  ( cd "$tmp" && ar x "$1" ) || die "cannot unpack $1"
  for m in data.tar.xz data.tar.gz data.tar.zst; do
    [ -f "$tmp/$m" ] || continue
    case $m in
      *.xz)  tar xJf "$tmp/$m" -C "$2" ;;
      *.gz)  tar xzf "$tmp/$m" -C "$2" ;;
      *.zst) tar --zstd -xf "$tmp/$m" -C "$2" ;;
    esac
    rm -rf "$tmp"
    return 0
  done
  rm -rf "$tmp"
  die "no known data.tar.* in $1"
}

ensure_aapt2() {
  if [ ! -x "$TOOLCHAIN/aapt2dir/aapt2" ]; then
    log "fetching x86_64 aapt2 $AAPT2_VERSION from the Android maven repo"
    jar=$TOOLCHAIN/aapt2-$AAPT2_VERSION-linux.jar
    [ -s "$jar" ] || curl -fL --retry 3 -o "$jar" \
      "https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/$AAPT2_VERSION/aapt2-$AAPT2_VERSION-linux.jar" ||
      die "aapt2 download failed"
    mkdir -p "$TOOLCHAIN/aapt2dir"
    unzip -o -q "$jar" aapt2 -d "$TOOLCHAIN/aapt2dir" ||
      die "aapt2 not found in $jar"
    chmod 755 "$TOOLCHAIN/aapt2dir/aapt2"
  fi
}

ensure_x86root() {
  [ -f "$TOOLCHAIN/x86root/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2" ] && return
  log "extracting a minimal x86_64 glibc root (libc6 + libgcc-s1)"
  mkdir -p "$TOOLCHAIN/x86root" "$TOOLCHAIN/debs"
  for spec in \
    "g/glibc|libc6_2\.36-[^\"]*_amd64\.deb" \
    "g/gcc-12|libgcc-s1_[0-9][^\"]*_amd64\.deb"; do
    pool=${spec%%|*}
    re=${spec#*|}
    name=$(deb_filename "$pool" "$re")
    [ -n "$name" ] || die "cannot resolve a package in pool/main/$pool"
    log "  $name"
    [ -s "$TOOLCHAIN/debs/$name" ] ||
      curl -fL --retry 3 -o "$TOOLCHAIN/debs/$name" \
        "$DEBIAN_MIRROR/pool/main/$pool/$name" || die "download of $name failed"
    extract_deb "$TOOLCHAIN/debs/$name" "$TOOLCHAIN/x86root"
  done
  [ -f "$TOOLCHAIN/x86root/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2" ] ||
    die "x86_64 loader still missing after extraction"
}

ensure_aapt2_shim() {
  # Rewritten on every run: the toolchain may have moved since the last build.
  qemu=/usr/bin/qemu-x86_64-static
  [ -x "$qemu" ] || die "qemu-user missing: apt-get install qemu-user-static"
  mkdir -p "$TOOLCHAIN/aapt2wrap"
  cat > "$TOOLCHAIN/aapt2wrap/aapt2" <<'SHIM'
#!/bin/sh
# Runs the x86_64 aapt2 from AGP under qemu-user on aarch64.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec /usr/bin/qemu-x86_64-static \
  "$ROOT/x86root/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2" \
  --library-path "$ROOT/x86root/lib/x86_64-linux-gnu:$ROOT/x86root/usr/lib/x86_64-linux-gnu" \
  "$ROOT/aapt2dir/aapt2" "$@"
SHIM
  chmod 755 "$TOOLCHAIN/aapt2wrap/aapt2"
}

# ---------------------------------------------------------------- SDK --------
ensure_sdk() {
  [ -d "$ANDROID_HOME/platforms/android-35" ] && return
  log "Android SDK platform 35 missing in $ANDROID_HOME, installing via sdkmanager"
  sdk=$TOOLCHAIN/cmdline-tools
  if [ ! -x "$sdk/latest/bin/sdkmanager" ]; then
    zip=$TOOLCHAIN/jdkdl/commandlinetools.zip
    mkdir -p "$TOOLCHAIN/jdkdl"
    [ -s "$zip" ] || curl -fL --retry 3 -o "$zip" "$CMDLINE_TOOLS_URL" ||
      die "cmdline-tools download failed"
    rm -rf "$TOOLCHAIN/cmdline-tools-unpack" "$sdk"
    mkdir -p "$TOOLCHAIN/cmdline-tools-unpack"
    unzip -q -o "$zip" -d "$TOOLCHAIN/cmdline-tools-unpack" ||
      die "cmdline-tools unzip failed"
    mkdir -p "$sdk"
    mv "$TOOLCHAIN/cmdline-tools-unpack/cmdline-tools" "$sdk/latest"
    rm -rf "$TOOLCHAIN/cmdline-tools-unpack"
  fi
  yes | "$sdk/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses \
    >/dev/null 2>&1 || true
  "$sdk/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
    "platforms;android-35" "build-tools;35.0.1" ||
    die "sdkmanager could not install platform 35"
}

# ---------------------------------------------------------------- build ------
ensure_jdk
ensure_aapt2
ensure_x86root
ensure_aapt2_shim
ensure_sdk
export JAVA_HOME ANDROID_HOME

if [ ! -f "$REPO/local.properties" ]; then
  printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$REPO/local.properties"
fi

if [ ! -f "$REPO/keystore.properties" ]; then
  log "no keystore.properties: building an unsigned release APK"
fi

cd "$REPO"
log "building"
exec ./gradlew --no-daemon assembleRelease \
  -Pandroid.aapt2FromMavenOverride="$TOOLCHAIN/aapt2wrap/aapt2" \
  "$@"
