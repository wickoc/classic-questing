#!/usr/bin/env bash
#
# Fetches Blizzard's own UI source for a client flavour, and rebuilds the API
# index from it.
#
# Gethe/wow-ui-source is a git mirror of the interface code Blizzard ships with
# the game. Its branches track live clients, and `version.txt` at the root says
# exactly which build the branch is at. On 2026-09-12 the `classic` branch read
# 5.5.4.69585 -- the build this AddOn is developed against, to the revision.
#
# Read this before assuming anything about the client. It is not a wiki write-up
# of what the API used to do; it is the Lua the client runs.
#
# Usage:
#   dev/knowledge/fetch_client_source.sh [branch] [destination]
#
# Branch defaults to `classic`, which is the current Classic progression client
# (MoP as of this writing). Other branches worth knowing:
#
#   classic          Classic progression  -- MoP 5.5.x today, Cata before it
#   classic_era      Classic Era (1.15.x)
#   classic_ptr      the PTR for the progression client
#   live             retail
#   ptr, beta        retail PTR and beta
#
# The clone is blobless and shallow: about 35 MB checked out, seconds to fetch.
# Nothing here is committed to this repository except the generated index --
# re-run the script when the client is patched.

set -euo pipefail

branch="${1:-classic}"
dest="${2:-${TMPDIR:-/tmp}/wow-ui-source-$branch}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$dest/.git" ]; then
	echo "== updating $dest ($branch)"
	git -C "$dest" fetch --depth 1 origin "$branch"
	git -C "$dest" checkout -q FETCH_HEAD
else
	echo "== cloning $branch into $dest"
	git clone --depth 1 --branch "$branch" --filter=blob:none \
		https://github.com/Gethe/wow-ui-source.git "$dest"
fi

echo "== build: $(cat "$dest/version.txt" 2>/dev/null || echo unknown)"

docs="$dest/Interface/AddOns/Blizzard_APIDocumentationGenerated"
if [ ! -d "$docs" ]; then
	echo "!! no Blizzard_APIDocumentationGenerated in this drop; index not rebuilt" >&2
	exit 0
fi

echo "== rebuilding the API index"
lua5.1 "$here/build_api_index.lua" "$docs" "$here"

cat <<EOF

Source is at $dest

  Which file does this flavour load?  The .toc marks it:
    grep -rn 'AllowLoadGameType' "\$dest"/Interface/AddOns/<addon>/*.toc
  On 5.5.x, [AllowLoadGameType wrath, cata, mists] means the Wrath/ copy is
  the live one and the Mists/ copy may not be.
EOF
