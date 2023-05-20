#!/bin/bash

T=/cygdrive/d/Temp/lwapp.txt
date >> $T

# env >> /cygdrive/d/Temp/env.txt

OUT_DIR=/cygdrive/d/Temp/LW/  # ... not going to use it
LIST=$(cygpath "C:\\Users\\Public\\Documents\\Lightworks\\Projects\\sources-list.txt")
LINE=$(grep "^D:.*[MmAa][OoVv][VvIi] ( Frames " $LIST | head -n 1)
if [[ -z "$LINE" ]]; then
    LINE=$(grep "^D:.*m2ts ( Frames " $LIST | head -n 1)
    if [[ -n "$LINE" ]]; then
        echo "ERROR: FUSION 8 cannot handle M2TS files. Convert them to MOV first [ ffmpeg -i f.m2ts -c:v copy -c:a pcm_s16le f.mov ]"
        exit 1
    fi
fi
if [[ -z "$LINE" ]]; then
    echo "ERROR: can't find TRACK in $LIST. Is it in MOV format?"
    exit 1
fi
echo "$LINE" >> $T
SRC=$(cygpath "${LINE%% ( *}")
WIN_SRC=$(cygpath -w -s "$SRC")

JSON_COMMENTS=$(sed 's@\\@\\\\@g' $LIST | awk '{printf "%s\\n", $0}')

Frames="${LINE##* ( Frames }"
START="${Frames%% -> *}"
END="${Frames##* -> }" ; END="${END%% )*}"
PADDING=$(grep -i "PADDING=" $LIST | head -n 1)
if [[ -n "$PADDING" ]]; then PADDING="${PADDING##*[^0-9]}"; else PADDING=90; fi
# This is the frame rate of the LW project.
FPS=$(grep -i "FPS=" $LIST | head -n 1)
if [[ -n "$FPS" ]]; then FPS="${FPS##*[^0-9]}"; else FPS=60; fi

# Padding before/after for dissolve crossfade effects
START=$((START - $PADDING))
END=$((END + $PADDING))
if [[ $START -lt 0 ]]; then START=0; fi

START0=$(printf %05d $START)

# Paths
SRC_DIR=$(dirname "$SRC")
SRC_FN=$(basename "$SRC")
DST_DIR="$SRC_DIR/fusion"
EXT="${SRC_FN##*.}"
OUT_FN="${SRC_FN%.*}_$START0.$EXT"

echo "File   : $SRC_FN"
echo "LW FPS : $FPS"
echo "Padding: $PADDING"


if [[ ! -d "$DST_DIR" ]] ; then mkdir "$DST_DIR" ; fi
DST="$DST_DIR/$OUT_FN"
COMP="${DST%.*}.comp"
WAV="${DST%.*}.wav"
WIN_COMP=$(cygpath -w "$COMP")
WIN_WAV=$(cygpath  -w "$WAV")

JSON_WAV=$(cygpath -w "$WAV" | sed 's@\\@\\\\@g')
JSON_SRC=$(cygpath -w "$SRC" | sed 's@\\@\\\\@g')
JSON_DST=$(cygpath -w "$DST" | sed 's@\\@\\\\@g')

# Getting the frame count of the video.
# http://stackoverflow.com/questions/2017843/fetch-frame-count-with-ffmpeg
# This work but it needs to parse the whole file. It's precise but long:
# $ ffprobe.exe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 file
# The other "solution" is use ffmpeg -i file -f null /dev/null (so convert/copy to dev null). 
# Takes about the same time and involves an unreliable grep of the output.
#
# Since it's slow I'll cache the value.

CACHE="${DST_DIR}/${SRC_FN}.nbframes"
NB_FRAMES=""
if [[ -f "$CACHE" ]]; then
    NB_FRAMES=$(cat "$CACHE" | tr -d "\r\n" | cut -d " " -f 1 )
fi
if [[ -z "$NB_FRAMES" ]]; then
    echo "Computing number of frames for file... can take a while."
    NB_FRAMES=$(ffprobe.exe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "$WIN_SRC" )
    echo $NB_FRAMES > "$CACHE"
fi
echo "Frames found: $NB_FRAMES"

# Getting the frame rate of the video
VFPS=$(ffprobe.exe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nokey=1:noprint_wrappers=1 "$WIN_SRC" )
if [[ -n "$VFPS" ]]; then
    # ffprobe gives us something fractional, e.g. 30/1 or 60000/1001
    # meh, I only care for something simple like 30 or 60.
    VFPS="${VFPS:0:2}"
    if [[ "$FPS" != "$VFPS" ]]; then
        # START and END are in LW's project rate (e.g. 30) whereas Fusion needs the frames in
        # the video's frame rate. So convert them.
        START=$( python -c "print int($START * $VFPS / $FPS.)" )
        END=$(   python -c "print int($END   * $VFPS / $FPS.)" )
    fi
else
    VFPS="$FPS"
fi

# Getting the audio for the video
if [[ ! -f "$WAV" ]]; then
    ffmpeg.exe -i "$WIN_SRC" -vn "$WIN_WAV"
fi


echo "Video FPS: $VFPS"
echo "Frames : $NB_FRAMES frames"
echo "Render : $START to $END"


# Write template

if [[ -f "$COMP" ]]; then
    echo "File $COMP already exists."
    echo -n "Overwrite? [y/N]: "
    read YES
    YES=$(echo ${YES:0:1} | tr 'A-Z' "a-z")
    if [[ "${YES}" != "y" ]]; then
        echo "Not overriding file $COMP."
        echo "Press enter to close."
        read WHATEVER
        exit 0
    fi
fi

cat > "$COMP" << EOF
Composition {
	CurrentTime = $START,
	RenderRange = { $START, $END },
	GlobalRange = { 0, $NB_FRAMES },
	CurrentID = 3,
	PlaybackUpdateMode = 0,
	Version = "Fusion 8.1.1 build 3",
	SavedOutputs = 0,
	HeldTools = 0,
	DisabledTools = 0,
	LockedTools = 0,
	AudioFilename = "$JSON_WAV",
	AudioOffset = 0,
	Resumable = true,
	OutputClips = {
		"$WIN_DST"
	},
	Tools = {
		Loader1 = Loader {
			Clips = {
				Clip {
					ID = "Clip1",
					Filename = "$JSON_SRC",
					FormatID = "QuickTimeMovies",
					Length = $NB_FRAMES,
					Multiframe = true,
					TrimIn = 0,
					TrimOut = $NB_FRAMES,
					ExtendFirst = 0,
					ExtendLast = 0,
					Loop = 1,
					AspectMode = 0,
					Depth = 0,
					TimeCode = 0,
					GlobalStart = 0,
					GlobalEnd = $NB_FRAMES
				}
			},
			Inputs = {
				["Gamut.SLogVersion"] = Input { Value = FuID { "SLog2" }, },
				Comments = Input { Value = "$JSON_COMMENTS", },
			},
			ViewInfo = OperatorInfo { Pos = { 126, 110.5 } },
		},
		Saver1 = Saver {
			CtrlWZoom = false,
			Inputs = {
				ProcessWhenBlendIs00 = Input { Value = 0, },
				Clip = Input {
					Value = Clip {
						Filename = "$JSON_DST",
						FormatID = "QuickTimeMovies",
						Length = 0,
						Saving = true,
						TrimIn = 0,
						ExtendFirst = 0,
						ExtendLast = 0,
						Loop = 1,
						AspectMode = 0,
						Depth = 0,
						GlobalStart = -2000000000,
						GlobalEnd = 0
					},
				},
				["QuickTimeMovies.Compression"] = Input { Value = FuID { "H.264_avc1" }, },
				OutputFormat = Input { Value = FuID { "QuickTimeMovies" }, },
				["Gamut.SLogVersion"] = Input { Value = FuID { "SLog2" }, },
				AdjustBasedOn = Input { Value = FuID { "100Sat_100Amp" }, },
				Input = Input {
					SourceOp = "Loader1",
					Source = "Output",
				},
				["QuickTimeMovies.Compression"] = Input { Value = FuID { "H.264_avc1" }, },
			},
			ViewInfo = OperatorInfo { Pos = { 322, 109.5 } },
		}
	},
	Prefs = {
		Comp = {
			FrameFormat = {
				Rate = $VFPS,
				GuideRatio = 1.77777777777778,
			}
		}
	}
}

EOF

# Open the folder and select the COMP in it
echo "Generated $COMP"
cmd /c "explorer /select,$WIN_COMP"
