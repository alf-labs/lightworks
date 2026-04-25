#!/bin/sh
set -e

TMP_DIR=/cygdrive/e/Temp
LOCK_FILE=$TMP_DIR/lock_$(basename "$0").txt
HAS_LOCK=""
FFMPEG=ffmpeg.exe
FFPROBE=ffprobe.exe
VDUB=/cygdrive/d/$USER/T/video/VirtualDub-1.10.4-AMD64/vdub64.exe
#DESHAKE1=~/bin/deshaker1.vdscript
#DESHAKE2=~/bin/deshaker2.vdscript
DESHAKE1=~/bin/deshaker1_nz.vdscript
DESHAKE2=~/bin/deshaker2_nz.vdscript
NICE=""   # use -nice
DRYRUN="echo"
RM="echo rm"

PREPARE_TEMP_ONLY=""

V_SRC_EXTRA= # "-ss 0:4:50 -t 0:0:45"

V_ROT=3
V_FILTER=""
V_FILTER_ROT=""
V_FILTER_CROP=""

V_TMP_BITRATE="-b:v 17000k"
V_TMP_OPTS="-vcodec libx264 -profile:v baseline -level 3.0 -preset fast"

V_DST_BITRATE="-b:v 17000k"
V_DST_OPTS="-vcodec libx264 -profile:v baseline -level 3.0 -preset fast"
V_DST_EXT="mov"

# A_BITRATE="-b:a 128k"
# A_OPTS="-acodec libmp3lame -ac 1 -ar 44100" 
#A_DST_EXT="mp3"
##  -async 1 -- is this what makes the sound weird?
#A_BITRATE="-b:a 1536k"
#A_OPTS="-acodec pcm_s16le -ac 1 -ar 48000" 
A_BITRATE=""
# A_OPTS="-acodec copy"
A_OPTS="-acodec pcm_s16le -ac 2 -ar 48000" 
A_MOBIUS_OPTS="-acodec pcm_s16le -ac 1 -ar 44100"
A_DST_EXT="wav"

T_OPTS=""   # duration time in sec
S_OPTS=""   # start time in sec

TMP_SEED=""
SINGLE_DST=""

THREADS="-threads 4"

function parse_args() {
    for i in "$@"; do
        case "$i" in
			-f )
				DRYRUN=""
				;;
            -rot=[0-9]* )
                i="${i:5}"
                V_ROT="$i"
                V_FILTER_ROT="rotate=${V_ROT}*PI/180"
                ;;
            -crop )
                V_FILTER_CROP="crop=1280:720:320:327"
                ;;
            -rm )
                RM="rm"
                ;;
            -fps=[0-9]* )
                # Override frame rate of the output, e.g. -r 30 or -r 23.98 to match other camera
                # in which case it also drops the sync between video and audio.
                i="${i:5}"
                V_DST_OPTS="$V_DST_OPTS -r $i -vsync drop"
                ;;
            -na )
                # na = no audio. Just drop it, it's cleaner.
                A_OPTS="-acodec none"
                A_DST_EXT=""
                ;;
            -di | -deinterlace )
                V_TMP_OPTS="$V_TMP_OPTS -vf yadif"
                ;;
            -s=[0-9]* )
                # start time in seconds
                i="${i:3}"
                S_OPTS="-ss $i"
                ;;
            -t=[0-9]* )
                # duration in seconds
                i="${i:3}"
                T_OPTS="-t $i"
                ;;
            -prepare-temp-only )
                PREPARE_TEMP_ONLY="1"
                ;;
            -single-dest=* )
                SINGLE_DST="${i:13}"
                ;;
            -nice )
                NICE="nice -n 5"
                ;;
            -tmp-seed=[0-9]* )
                TMP_SEED="${i:10}"
                ;;
			-*)
				echo "Unknown parameter: $i"
                echo "Parameters: -f -nice -crop -rot=00 -rm -di -deinterlace -fps=23.98 -na -s=12 -t=34... + *.MOV|mp4|VOB"
                echo "Esoteric: -prepare-temp-only -single-dest=NAME"
                echo "Default is no-crop no-rot no-rm no-deinterlace, same fps."
				# usage
				;;
		esac
    done
    
    if [[ -n "$V_FILTER_ROT$V_FILTER_CROP" ]]; then
        V_FILTER="$V_FILTER_ROT"
        if [[ -n "$V_FILTER" && -n "$V_FILTER_CROP" ]]; then
            V_FILTER="$V_FILTER,"
        fi
        if [[ -n "$V_FILTER_CROP" ]]; then
            V_FILTER="$V_FILTER$V_FILTER_CROP"
        fi
        if [[ -n "$V_FILTER" ]]; then
            V_FILTER="-vf $V_FILTER"
        fi
    fi
}

function get_lock() {
    if [[ -z "$DRYRUN" ]]; then
        while [[ -f "$LOCK_FILE" ]]; do
            echo "Lock file present, wait 5s: $LOCK_FILE"
            sleep 5s
        done

        echo "Acquire lock file: $LOCK_FILE"

        trap release_lock EXIT

        date > "$LOCK_FILE"
        HAS_LOCK="1"
    fi
}

function release_lock() {
    trap - EXIT
    if [[ -n "$HAS_LOCK" ]]; then
        echo "Release lock file: $LOCK_FILE"
        rm -fv "$LOCK_FILE"
        HAS_LOCK=""
    fi
}

function process() {
    SRC="$1"
    TMP_SRC=tmp_${TMP_SEED}_$(basename "${SRC// /_}")
    TMP_SRC="${TMP_SRC%.*}.avi"
    TMP_AUD="${TMP_SRC%.*}.${A_DST_EXT}"
    TMP_META="${TMP_SRC%.*}.meta"

    TMP_DST="${TMP_SRC/tmp_/stabi_}"

    DST_AVI="$SINGLE_DST"
    if [[ -z "$DST_AVI" ]]; then
        DST_AVI="${SRC/stabi/STABI_}"
        if [[ "$DST_AVI" == "$SRC" ]]; then DST_AVI="${SRC/VID/STABI}"; fi
        if [[ "$DST_AVI" == "$SRC" ]]; then DST_AVI="${SRC/MVI/STABI}"; fi
        if [[ "$DST_AVI" == "$SRC" ]]; then DST_AVI="${SRC/REC/STABI}"; fi
        if [[ "$DST_AVI" == "$SRC" ]]; then DST_AVI="STABI_${SRC}"; fi
        DST_AVI="${DST_AVI%.*}.${V_DST_EXT}"
    fi
    
    if [[ -f "$DST_AVI" ]]; then
        echo "**** KEEPING EXISTING DST: $DST_AVI"
    else
        # Extract source metadata
        if [[ ! -f "$TMP_DIR/$TMP_META" ]]; then
            $NICE "$FFMPEG"  -hide_banner -loglevel panic  -i "$SRC" -f ffmetadata \
                $(cygpath -w "$TMP_DIR/$TMP_META")
        fi
    
        # Transcode input in something usable by VirtualDub
        if [[ -f "$TMP_DIR/$TMP_SRC" ]]; then
            echo "**** Keeping existing temp: $TMP_DIR/$TMP_SRC"
        else
            # Grab the codec from the source stream, in case we don't need to transcode it
            CODEC=$("$FFPROBE"  -v error -select_streams v:0 -show_entries "stream=codec_name" -print_format csv "$SRC" | tr -d "\r\n")
            echo "Source codec: '$CODEC'"
            #if [[ "$CODEC" == "stream,mjpeg" ]]; then
            # ==> well that didn't work... black picture.
            #    $DRYRUN $NICE "$FFMPEG" $V_SRC_EXTRA -i "$SRC" \
            #        $S_OPTS $T_OPTS -vcodec copy -an \
            #        $(cygpath -w "$TMP_DIR/$TMP_SRC")
            #else
                $DRYRUN $NICE "$FFMPEG" $V_SRC_EXTRA -i "$SRC" \
                    $S_OPTS $T_OPTS $V_TMP_OPTS $V_TMP_BITRATE -an \
                    $(cygpath -w "$TMP_DIR/$TMP_SRC")
            #fi
        fi
        # Extract the sound to merge it back later
        if [[ -n "$A_DST_EXT" ]]; then
            if [[ -f "$TMP_DIR/$TMP_AUD" ]]; then
                echo "**** Keeping existing temp: $TMP_DIR/$TMP_AUD"
            else
                TMP_A_OPTS="$A_OPTS"
                if [[ $(grep "^comment=" "$TMP_DIR/$TMP_META") =~ Mobius ]]; then
                    TMP_A_OPTS="$A_MOBIUS_OPTS"
                fi
            
                $DRYRUN $NICE "$FFMPEG" $V_SRC_EXTRA -i "$SRC" \
                    $S_OPTS $T_OPTS $TMP_A_OPTS $A_BITRATE -vn \
                    $(cygpath -w "$TMP_DIR/$TMP_AUD")
            fi
        fi
        
        # Only prepare temp files, don't run deshaker
        if [[ -n "$PREPARE_TEMP_ONLY" ]]; then
            return
        fi

        # Use VirtualDub with Deshaker plugin
        if [[ -f "$TMP_DIR/$TMP_DST" ]]; then
            echo "**** Keeping existing deshaked: $TMP_DIR/$TMP_DST"
        else
            $DRYRUN get_lock
        
            $DRYRUN $NICE "$VDUB" \
                /s $(cygpath -w "$DESHAKE1") \
                /p $(cygpath -w "$TMP_DIR/$TMP_SRC") $(cygpath -w "$TMP_DIR/$TMP_DST") /r /c /x \
            && \
            $DRYRUN $NICE "$VDUB" \
                /s $(cygpath -w "$DESHAKE2") \
                /p $(cygpath -w "$TMP_DIR/$TMP_SRC") $(cygpath -w "$TMP_DIR/$TMP_DST") /r /c /x
        
            $DRYRUN release_lock
        fi
        
        # Remix deshaker output with the original sound, rotate and crop from 1080 to 720 on bottom center
        if [[ -f "$TMP_DIR/$TMP_DST" || -n $DRYRUN ]]; then
            if [[ -n "$A_DST_EXT" ]]; then
                $DRYRUN $NICE "$FFMPEG" $T_OPTS \
                    -i $(cygpath -w "$TMP_DIR/$TMP_DST") -i $(cygpath -w "$TMP_DIR/$TMP_AUD") \
                    -map 0:0 -map 1:0 $V_DST_OPTS $V_DST_BITRATE -c:a copy $V_FILTER \
                    -y "$DST_AVI" \
                && \
                $DRYRUN $RM -v "$TMP_DIR/$TMP_SRC" \
                && \
                $DRYRUN $RM -v "$TMP_DIR/$TMP_DST"
            else
                $DRYRUN $NICE "$FFMPEG" $T_OPTS \
                    -i $(cygpath -w "$TMP_DIR/$TMP_DST") $V_DST_OPTS $V_DST_BITRATE -c:a copy $V_FILTER -y "$DST_AVI"
            fi
        fi

    fi
    
    if [[ -n "$SINGLE_DST" ]]; then
        echo
        echo "**** PROCESSED SINGLE DEST DONE: $SINGLE_DST"
        exit 0
    fi
}

parse_args "$@"

for i in "$@"; do
    D=""
    N="$i"
    if [[ -f "$i" ]]; then
        D=$(dirname "$i")
        N=$(basename "$i")
    fi
    case "$N" in
        -* )
            # skip
            ;;
        *.mov | *.mp4 | *.avi | *.MP4 | *.MOV | *.VOB | *.m2ts | *.webm )
            (   cd "$D"
                echo
                echo "-------"
                echo "Process $D/$N"
                echo "-------"
                echo
                process "$N"
            )
            ;;
        * )
            echo
            echo "-------"
            echo "ERROR: unknown file $i. Use only with *REC*.mp4 ones"
            echo "-------"
            echo
            ;;
    esac
done
    
[ -n "$DRYRUN" ] && echo && echo "#### DRY-RUN #### ==> Append -f to really convert." && echo
