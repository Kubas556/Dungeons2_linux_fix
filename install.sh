#!/bin/sh
# Copy xgameruntime.dll next to both game executables and into the Proton prefix.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DLL="$ROOT/src/xgameruntime.dll"
APPID=1912410
if [ ! -f "$DLL" ]; then
    echo "Missing $DLL. Build it first; see README.md." >&2
    exit 1
fi

# The DLL looks for xauth.py in ~/.local/share/dungeons2-compat.
# If the repository was cloned elsewhere, link it there.
COMPAT="$HOME/.local/share/dungeons2-compat"
if [ "$(CDPATH= cd -- "$COMPAT" 2>/dev/null && pwd -P)" != "$(cd -- "$ROOT" && pwd -P)" ]; then
    if [ -e "$COMPAT" ] || [ -L "$COMPAT" ]; then
        echo "$COMPAT exists but is not this repository." >&2
        echo "Clone the repo there, or remove that directory and run again." >&2
        exit 1
    fi
    mkdir -p "$(dirname "$COMPAT")"
    ln -s "$ROOT" "$COMPAT"
    echo "Linked $COMPAT -> $ROOT"
fi

STEAM_ROOT=${STEAM_ROOT:-$HOME/.local/share/Steam}
if [ ! -f "$STEAM_ROOT/steamapps/libraryfolders.vdf" ] && [ -f "$HOME/.steam/steam/steamapps/libraryfolders.vdf" ]; then
    STEAM_ROOT=$HOME/.steam/steam
fi
VDF="$STEAM_ROOT/steamapps/libraryfolders.vdf"
if [ ! -f "$VDF" ]; then
    echo "Could not find libraryfolders.vdf. Set STEAM_ROOT." >&2
    exit 1
fi

LIB=$(awk '
    /"path"/ {
        gsub(/"/, "", $2)
        path = $2
        manifest = path "/steamapps/appmanifest_'"$APPID"'.acf"
        if (system("test -f \"" manifest "\"") == 0) { print path; exit }
    }
' "$VDF")
if [ -z "$LIB" ]; then
    echo "Steam app $APPID is not in any library folder." >&2
    exit 1
fi

GAME="$LIB/steamapps/common/Minecraft Dungeons II"
PFX="$LIB/steamapps/compatdata/$APPID/pfx/drive_c/windows/system32"
SHIP="$GAME/Dungeons/Binaries/Win64"
for dir in "$GAME" "$SHIP" "$PFX"; do
    if [ ! -d "$dir" ]; then
        echo "Missing $dir" >&2
        exit 1
    fi
    cp -f "$DLL" "$dir/xgameruntime.dll"
    echo "Installed $dir/xgameruntime.dll"
done
echo
echo "In Steam, set this launch option for Minecraft Dungeons II:"
echo '  WINEDLLOVERRIDES="xgameruntime=n" %command%'
