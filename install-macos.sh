#!/bin/sh
# Copy xgameruntime.dll into a CrossOver Steam bottle on macOS.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DLL="$ROOT/src/xgameruntime.dll"
APPID=1912410
if [ ! -f "$DLL" ]; then
    echo "Missing $DLL. Build it first; see README.md." >&2
    exit 1
fi
if [ "$(uname -s)" != "Darwin" ]; then
    echo "install-macos.sh is for macOS. On Linux, run ./install.sh." >&2
    exit 1
fi
if [ ! -x /usr/bin/python3 ]; then
    echo "Need /usr/bin/python3. The DLL starts that program, not a Homebrew Python." >&2
    exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl is not on PATH. Sign-in uses it for the PlayFab token." >&2
    exit 1
fi

# The DLL looks for xauth.py in ~/.local/share/dungeons2-compat.
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

BOTTLES=${CX_BOTTLES:-"$HOME/Library/Application Support/CrossOver/Bottles"}
LIST=$(mktemp)
BOTTLE_LIST=$(mktemp)
trap 'rm -f "$LIST" "$BOTTLE_LIST"' EXIT

bottle_list() {
    if [ -n "${CX_BOTTLE:-}" ]; then
        case $CX_BOTTLE in
            /*) printf '%s\n' "$CX_BOTTLE" ;;
            *) printf '%s\n' "$BOTTLES/$CX_BOTTLE" ;;
        esac
        return
    fi
    if [ ! -d "$BOTTLES" ]; then
        echo "Could not find CrossOver bottles in $BOTTLES. Set CX_BOTTLES." >&2
        exit 1
    fi
    find "$BOTTLES" -mindepth 1 -maxdepth 1 -type d -name '*' 
}

# C:\Program Files (x86)\Steam -> <bottle>/dosdevices/c:/Program Files (x86)/Steam
win_to_host() {
    bottle=$1
    win=$2
    win=$(printf '%s' "$win" | sed 's/\\\\/\//g; s/\\/\//g')
    letter=$(printf '%s' "$win" | cut -c1 | tr 'A-Z' 'a-z')
    rest=$(printf '%s' "$win" | sed 's/^.:\/*//')
    link="$bottle/dosdevices/${letter}:"
    if [ -e "$link" ]; then
        printf '%s/%s\n' "$link" "$rest"
        return
    fi
    if [ "$letter" = c ]; then
        printf '%s/%s\n' "$bottle/drive_c" "$rest"
    fi
}

note_game() {
    bottle=$1
    game=$2
    if [ -d "$game/Dungeons/Binaries/Win64" ]; then
        printf '%s\t%s\n' "$bottle" "$game" >> "$LIST"
    fi
}

scan_bottle() {
    bottle=$1
    if [ ! -d "$bottle/drive_c" ]; then
        echo "Not a CrossOver bottle: $bottle" >&2
        exit 1
    fi
    vdfs=$(mktemp)
    find "$bottle/drive_c" -path '*/steamapps/libraryfolders.vdf' > "$vdfs" 2>/dev/null || true
    while IFS= read -r vdf; do
        [ -n "$vdf" ] || continue
        sed -n 's/.*"path"[[:space:]]*"\(.*\)".*/\1/p' "$vdf" | while IFS= read -r winpath; do
            host=$(win_to_host "$bottle" "$winpath" || true)
            [ -n "$host" ] || continue
            if [ -f "$host/steamapps/appmanifest_$APPID.acf" ]; then
                note_game "$bottle" "$host/steamapps/common/Minecraft Dungeons II"
            fi
        done
    done < "$vdfs"
    rm -f "$vdfs"
    manifests=$(mktemp)
    find "$bottle/drive_c" -name "appmanifest_$APPID.acf" > "$manifests" 2>/dev/null || true
    while IFS= read -r manifest; do
        [ -n "$manifest" ] || continue
        note_game "$bottle" "$(dirname "$manifest")/common/Minecraft Dungeons II"
    done < "$manifests"
    rm -f "$manifests"
}

bottle_list > "$BOTTLE_LIST"
while IFS= read -r bottle; do
    [ -n "$bottle" ] || continue
    scan_bottle "$bottle"
done < "$BOTTLE_LIST"

sort -u -o "$LIST" "$LIST"
count=$(grep -c . "$LIST" || true)
if [ "$count" -eq 0 ]; then
    echo "Steam app $APPID is not in any CrossOver bottle." >&2
    echo "Set CX_BOTTLE to the bottle name or path if it lives outside the default folder." >&2
    exit 1
fi
if [ "$count" -gt 1 ]; then
    echo "More than one bottle has Minecraft Dungeons II. Set CX_BOTTLE to one of:" >&2
    awk -F '\t' '{ print "  " $1 }' "$LIST" >&2
    exit 1
fi

IFS=$(printf '\t')
read -r BOTTLE GAME < "$LIST"
IFS=$(printf ' \t\n')
SHIP="$GAME/Dungeons/Binaries/Win64"
PFX="$BOTTLE/drive_c/windows/system32"
if [ ! -d "$PFX" ]; then
    PFX="$BOTTLE/drive_c/Windows/System32"
fi
for dir in "$GAME" "$SHIP" "$PFX"; do
    if [ ! -d "$dir" ]; then
        echo "Missing $dir" >&2
        exit 1
    fi
    cp -f "$DLL" "$dir/xgameruntime.dll"
    echo "Installed $dir/xgameruntime.dll"
done

REG="$BOTTLE/user.reg"
if [ -f "$REG" ] && grep -q 'WINE REGISTRY' "$REG"; then
    updated=$(mktemp)
    awk '
        BEGIN { insec = 0; done = 0 }
        /^\[Software\\\\Wine\\\\DllOverrides\]/ { insec = 1; print; next }
        insec && /^\[/ {
            if (!done) { print "\"xgameruntime\"=\"native\""; done = 1 }
            insec = 0
            print
            next
        }
        insec && /"\*?xgameruntime"=/ {
            if (!done) { print "\"xgameruntime\"=\"native\""; done = 1 }
            next
        }
        { print }
        END {
            if (insec && !done) print "\"xgameruntime\"=\"native\""
            else if (!done) {
                print ""
                print "[Software\\\\Wine\\\\DllOverrides]"
                print "\"xgameruntime\"=\"native\""
            }
        }
    ' "$REG" > "$updated"
    mv "$updated" "$REG"
    echo "Set xgameruntime=native in $REG"
else
    echo "Could not edit $REG." >&2
    echo "In CrossOver, open Wine Configuration, Libraries, and add xgameruntime as native." >&2
fi
echo
echo "Quit CrossOver completely if it was open, then start the game from Steam."
