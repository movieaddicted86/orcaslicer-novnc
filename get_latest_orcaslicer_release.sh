#!/bin/bash
# Get the latest release of OrcaSlicer for Linux (AppImage) using the GitHub API.
# Returns either the download URL or the filename of the x86_64 Ubuntu AppImage asset.
#
# usage: $0 [ url | name ] [VERSION]
#   url        Download URL of the latest x86_64 Linux AppImage
#   name       Filename of the latest x86_64 Linux AppImage
#   VERSION    Optional tag (e.g. v2.4.2) to pin instead of "latest"

set -eu

if [[ $# -lt 1 ]]; then
  echo "~~~ $0 ~~~"
  echo "	usage: $0 [ url | name ] [VERSION]"
  echo
  echo "	url:     Returns the download URL for the release (for cURL/wget)"
  echo "	name:    Returns the AppImage filename of the release"
  echo "	VERSION: Optional tag to pin (e.g. v2.4.2). Defaults to the latest release."
  echo
  exit 1
fi

baseDir="/orca"
mkdir -p "$baseDir"

repo="SoftFever/OrcaSlicer"
version="${2:-}"

if [[ -n "$version" ]]; then
  apiUrl="https://api.github.com/repos/${repo}/releases/tags/${version}"
  cacheFile="$baseDir/release_${version}.json"
else
  apiUrl="https://api.github.com/repos/${repo}/releases/latest"
  cacheFile="$baseDir/latestReleaseInfo.json"
fi

if [[ ! -e "$cacheFile" ]]; then
  curl -SsL "$apiUrl" > "$cacheFile"
fi

releaseInfo=$(cat "$cacheFile")

# Match the x86_64 Linux AppImage, excluding the aarch64 variant.
# e.g. OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.4.2.AppImage
selector='.assets[] | select((.name | test("Linux.*AppImage.*\\.AppImage$")) and (.name | test("aarch64") | not))'

case "$1" in
  url)
    echo "${releaseInfo}" | jq -r "${selector} | .browser_download_url" | head -n1
    ;;
  name)
    echo "${releaseInfo}" | jq -r "${selector} | .name" | head -n1
    ;;
  *)
    echo "Unknown mode: $1" >&2
    exit 1
    ;;
esac