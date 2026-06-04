#!/usr/bin/bash

DRY="echo"
OP="install"
FN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: $0 filename.fuse [-f] [--grab] [--vimdiff]"
            exit 0
            ;;
        -f|--force)
            DRY=""
            shift
            ;;
        --grab)
            OP="grab"
            shift
            ;;
        --vimdiff)
            OP="vimdiff"
            shift
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            exit 1
            ;;
        *)
            if [[ -n "$FN" ]]; then
                echo "Error: $0 only handles one filename."
                exit 1
            fi
            FN="$1"
            shift
            ;;
    esac
done

if [[ ! -f "$FN" ]]; then
    echo "Error: Invalid file '$FN'"
    echo "Usage: $0 filename.fuse [-f]"
    exit 1
fi

BN=$(basename "$FN")
SRC="$FN"
DST=$(cygpath "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\\$BN")

echo "Local : $FN"
echo "Fusion: $DST"
echo

if [[ "$FN" == "$DST" ]]; then
    echo "Error: Local '$FN' is the same as Fusion path."
    echo "Usage: $0 local/filename.fuse [-f]"
    exit 1
fi

if [[ "$OP" == "vimdiff" ]]; then
    vimdiff "$SRC" "$DST"
    exit 0
elif [[ -n "$DRY" ]]; then
    # Default is to diff if not --force
    diff "$SRC" "$DST" | less
fi
echo
echo "Perform $OP..."
if [[ "$OP" == "install" ]]; then
    $DRY cp -v "$FN" "$DST"
elif [[ "$OP" == "grab" ]]; then
    $DRY cp -v "$DST" "$FN"
fi

if [[ -n "$DRY" ]]; then
    echo
    echo "DRY MODE. Use '$0 $FN -f' to actually run."
fi
echo
# ~~

