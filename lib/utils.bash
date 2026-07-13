#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/nubjs/nub"
TOOL_NAME="nub"

fail() {
  echo -e "asdf-$TOOL_NAME: $*" >&2
  exit 1
}

curl_opts=(-fsSL)
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

# Release asset target for the current platform: darwin/linux x arm64/x64,
# with -musl on non-glibc Linux (same probe as nub's own install.sh).
release_target() {
  local os arch target
  os=$(uname -s)
  arch=$(uname -m)
  case "$os $arch" in
    'Darwin arm64') target=darwin-arm64 ;;
    'Darwin x86_64') target=darwin-x64 ;;
    'Linux aarch64' | 'Linux arm64') target=linux-arm64 ;;
    'Linux x86_64') target=linux-x64 ;;
    *) fail "unsupported platform: $os $arch" ;;
  esac
  if [[ "$target" == linux-* ]] && ! ldd --version 2>&1 | grep -qiE 'glibc|gnu'; then
    target="${target}-musl"
  fi
  echo "$target"
}

download_release() {
  local version filename target url
  version="$1"
  filename="$2"
  target=$(release_target)
  url="$GH_REPO/releases/download/v${version}/nub-${target}.tar.gz"

  echo "* Downloading $TOOL_NAME release $version ($target)..."
  curl "${curl_opts[@]}" -o "$filename" "$url" || fail "Could not download $url"

  # Verify the published SHA-256 when a checksum tool is available.
  local sha_url sha_expected sha_actual
  sha_url="${url}.sha256"
  if command -v sha256sum >/dev/null 2>&1; then
    sha_actual=$(sha256sum "$filename" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    sha_actual=$(shasum -a 256 "$filename" | awk '{print $1}')
  else
    return 0
  fi
  sha_expected=$(curl "${curl_opts[@]}" "$sha_url" | awk '{print $1}') || return 0
  [ -n "$sha_expected" ] || return 0
  [ "$sha_actual" = "$sha_expected" ] ||
    fail "checksum mismatch for $url (expected $sha_expected, got $sha_actual)"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    # The archive ships bin/nub (plus a vestigial runtime/); extract as-is.
    tar -xzf "$ASDF_DOWNLOAD_PATH/nub.tar.gz" -C "$install_path" ||
      fail "Could not extract archive"
    [ -x "$install_path/bin/nub" ] || chmod +x "$install_path/bin/nub"
    # nubx is the same binary dispatched on argv[0]; ship it as a relative symlink.
    ln -sf nub "$install_path/bin/nubx"

    local tool_cmd
    tool_cmd="$install_path/bin/nub"
    "$tool_cmd" --version >/dev/null || fail "'nub --version' failed after install"

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
