#!/bin/bash
#
# Script to run the stabilizer on a segment that is ALREADY in LightWorks.
#
# Usage:
# - In LightWorks, right-click clip / Add > Effect > Plugins > "LW App Test"
# - In the effect panel, click "List Sources" -- do NOT run "Launch" EVER
# - This opens the sources-list.txt in Notepad++
# - Verify the video track is the first one (if there are more than one, reorder as needed).
#
# If there's only one clip to process:
# - Run this script now. It picks up the info from the single sources-list.txt and prints info.
# - If statisfactory, run it with -f.
# - After the stabilizer has finished, import the stabilized video in LW as usual.
# - This does NOT automatically replace the rendered media in LW. I like to do it manually.
#
# If there are multiple clips to process:
# - Generate the sources-list.txt and call the script with -prepare for each one:
#   ~/bin/lw_stabilize.sh -prepare list1.txt ; ~/bin/lw_stabilize.sh -prepare list2.txt ; etc.
# - This simply makes a convenient copy of the unique sources-list.txt into separate files.
# - Once all the list files have been prepared (aka copied), simply run the script with the list files:
#   ~/bin/lw_stabilize.sh list1.txt list2.txt etc.
# - After the stabilizer has finished, import the stabilized videos in LW as usual.
# - This does NOT automatically replace the rendered media in LW. I like to do it manually.
#
# IMPORTANT:
# - The stabilizer script keeps tmp videos around. When processing multiple clips out of the same
#   original video, the tmp extraded video would be reused incorrectly. The avoid that, either
#   a/ process them all at the same time, this script detects it and generate different tmp movs, or
#   b/ manually trash the e:\\temp\\tmp_* matching the video that has several clips, or
#   c/ all of the above.
#
# IMPORTANT:
# - LightWorks exports the clip using frame numbers as start/end.
# - FFMPEG takes decimal seconds for the start and length. There might be a slight discrepency.


LIST=$(cygpath "C:\\Users\\Public\\Documents\\Lightworks\\Projects\\sources-list.txt")
LISTS=""
STABI_CMD=~/bin/stabilize_mobius.sh
STABI_ARGS=""
LAST_DST=""

declare -A STARTS  # Bash's own sick version of hashmaps. See https://stackoverflow.com/questions/1494178

T=/cygdrive/d/Temp/lwapp.txt
date >> $T

function parse_args() {
    while [ -n "$1" ]; do
		case "$1" in
			-f | -na | -nice )
                STABI_ARGS="$STABI_ARGS $1"
				;;
            -p | -prepare )
                prepare "$2"
                exit 0
                ;;
			-*)
				echo "Unknown parameter: $1"
                echo "Parameters: [-f -na -nice] [-prepare LIST_DST] LISTS*"
                echo "Default is to read source from $LIST."
                echo "Args -f -na -nice are passed to "$(basename $STABI_CMD)" as-is"
                echo "Use -prepare to copy the list file to LIST_DST then process it later in batch."
                exit 2
				;;
            *)
                if [[ -f "$1" ]]; then
                    LISTS="$LISTS $1"
                else
                    echo "Unknown input file: $1"
                    exit 1
                fi
                ;;
		esac
        shift
    done
}

function prepare() {
    DST="$1"
    if [[ -z "$DST" ]]; then
        echo "Error: missing dest arg for -prepare"
        exit 1
    fi
    if [[ -f "$DST" ]]; then
        echo "Error: $DST already exists. Will not overwrite."
        exit 1
    fi
    cp -v "$LIST" "$DST"

    parse_list "$DST"
}

function parse_list() {
    LIST="$1"
    
    LINE=$(grep "^.* ( Frames " $LIST | head -n 1)
    echo "$LINE" >> $T
    SRC=$(cygpath "${LINE%% ( *}")
    WIN_SRC=$(cygpath -w -s "$SRC")

    Frames="${LINE##* ( Frames }"
    F_START="${Frames%% -> *}"
    F_END="${Frames##* -> }" ; F_END="${F_END%% )*}"

    F_PADDING=$(grep -i "PADDING=" $LIST | head -n 1)
    if [[ -n "$F_PADDING" ]]; then 
        F_PADDING="${F_PADDING##*[^0-9]}"
        F_START=$((F_START - $F_PADDING))
        if [[ $F_START -lt 0 ]]; then F_START=0; fi
        F_END=$((F_END + $F_PADDING))
    fi

    # This is the frame rate of the file
    FPS=$(ffprobe.exe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nokey=1:noprint_wrappers=1 "$WIN_SRC" | head -n 1 | tr -d "\r\n" )
    FPS=$(python -c "print $FPS.")
    
    START=$(python -c "print '%f' % (float($F_START) / $FPS)")
    END=$(  python -c "print '%f' % (float($F_END) / $FPS)")
    LEN=$(  python -c "print '%f' % ($END - $START)")

    # Try to detect dups in source files ==> changed to always use a tmp seed.
    # The stabi script creates tmp files and reuses them based on the source input.
    # If we stabi the same file twice at different offset, it would keep using the old tmp files
    # unless we change the tmp seed.
    TMP_SEED=""
    # if [[ -n "${STARTS[$SRC]}" ]]; then
    #    # We have seen this file before. Use a tmp seed.
        TMP_SEED="-tmp-seed=$F_START"
    # fi
    STARTS=( ["$SRC"]="$F_START" )
    
    # Paths
    V_DST_EXT="mov"
    NUM_LIST=$(echo "$LIST" | tr -c -d "0-9")  # extract numbers for LIST filename, if any
    DST_AVI=$(basename "${SRC}")
    DST_AVI="${DST_AVI%.*}"
    if [[ "$DST_AVI" =~ .*stabi.* ]] ; then
        DST_AVI="${DST_AVI}/stabi/LW-${F_START}-STABI${NUM_LIST}_"
    else
        DST_AVI="${DST_AVI}_LW-${F_START}-STABI${NUM_LIST}_"
    fi
    DST_AVI="${DST_AVI}.${V_DST_EXT}"

    echo "File : $SRC"
    echo "Dest : $DST_AVI"
    echo "FPS  : $FPS"
    echo "Start: $START seconds"
    echo "Len  : $LEN seconds"
}

function process() {
    LIST="$1"
    echo
    echo "**** Process $LIST"
    echo

    parse_list "$1"
    
    $STABI_CMD -s=$START -t=$LEN $TMP_SEED "-single-dest=$DST_AVI" $STABI_ARGS "$SRC"
    LAST_DST="$DST_AVI"
}

parse_args "$@"

if [[ -z "$LISTS" ]]; then LISTS="$LIST"; fi

for i in $LISTS; do
    process "$i"
done

if [[ -f "$LAST_DST" ]]; then
    # Open the folder and select the last generated file in it
    echo "Opening $LAST_DST"
    cmd /c "explorer /select,"$(cygpath -ws "$LAST_DST")
fi
