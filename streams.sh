#!/usr/bin/env bash
################################################################################
# streams.sh - v1
#  - Justin Lambe, May 2016
#
# Takes single argument (file or directory), recursively finds all video files
# within and provides summary of video and audio streams contained within each
# file.
#
# Currently uses ffprobe (ffmpeg), should probably rewrite for libav.
#
################################################################################


################################################################################
# System variables

FFPROBE=$( /usr/bin/env which ffprobe )
READLINK=$( /usr/bin/env which readlink )
PERL=$( /usr/bin/env which perl )
SEARCH="$1"

IFS='
'


################################################################################
# Ensure search path exists

if [ ! -e ${SEARCH} ]; then
    echo -e "Error: could not find search path ${SEARCH}"
    exit 1
fi


################################################################################
# Ensure ffprobe is installed

if [ "${FFPROBE}" == "" ] || [ ! -e "${FFPROBE}" ]; then
    echo -e "Error: could not locate ffprobe"
    exit 1
fi

################################################################################
# Method for determining absolute path of files & directories
# (OSX doesn't have GNU readlink installed)

# First try readlink
${READLINK} -f ${0} &>/dev/null

# Check output of previous command
if [ $? -ne 0 ]; then

    # Define our own internal readlink function using perl instead
    readlinkf() {
        ${PERL} -MCwd -e 'print Cwd::abs_path shift' "$2";
    }
    READLINK=readlinkf

fi


################################################################################
# Compile list of files and loop through list

FILE_LIST=$( find ${SEARCH} -type f \( -iname '*.avi' -o -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.m4v' \) | sort )

LASTDIR=null
for FILE in ${FILE_LIST}; do

    # Determine directory name of current file
    CURDIR=$( dirname "${FILE}" )

    # Print current directory name as heading if this is the first time we've seen this directory
    if [ "${CURDIR}" != "${LASTDIR}" ]; then
        echo
        echo -e $( ${READLINK} -f "${CURDIR}" )/:
        LASTDIR="${CURDIR}"
    fi


    # Run ffprobe and extract stream information from ffprobe output
    OUTPUT=$( ${FFPROBE} "${FILE}" 2>&1 )
    DURATION=$( echo -e "${OUTPUT}" | grep -e 'Duration: ' )
    VIDEO=$( echo -e "${OUTPUT}" | grep -e 'Stream #0.*Video' | head -n1 )
    AUDIO_1=$( echo -e "${OUTPUT}" | grep -e 'Stream #0.*Audio' | head -n1 )
    #AUDIO_2=$( echo -e "${OUTPUT}" | grep -e 'Stream #0.*Audio' | head -n2 | tail -n1 )


    # Print video stream information
    if [ "${VIDEO}" != "" ]; then
        CODEC=$( echo -e $VIDEO | awk '{print $4}' )
        RESOLUTION=$( echo -e $VIDEO | ${PERL} -nle 'print $1 if / (\d\d+x\d\d+)/' )
        BITRATE=$( echo -e "$VIDEO\n$DURATION" | ${PERL} -nle 'print $1 if / (\d+ kb\/s)/' | head -n1 )
        FRAMERATE=$( echo -e $VIDEO | ${PERL} -nle 'print $1 if / (\d+ fps)/; print $1 if / (\d+\.\d+ fps)/' )
        printf "| %-5s %9s %10s %10s " \
            "${CODEC}" "${RESOLUTION}" "${BITRATE}" "${FRAMERATE}"
    fi


    # Print audio stream 1 information
    if [ "${AUDIO_1}" != "" ]; then
        CODEC=$( echo -e $AUDIO_1 | awk '{print $4}' )
        CHANNELS=$( echo -e $AUDIO_1 | ${PERL} -nle 'print $1 if / (stereo),/; print $1 . " ch" if / (\d\.\d)/' )
        BITRATE=$( echo -e $AUDIO_1 | ${PERL} -nle 'print $1 if / (\d+ kb\/s)/' )
        FREQ=$( echo -e $AUDIO_1 | ${PERL} -nle 'print int( $1/1000 ) . " kHz" if / (\d+) Hz/' )
        printf "| %-4s %7s %10s %7s " \
            "${CODEC}" "${CHANNELS}" "${BITRATE}" "${FREQ}"
    fi


    # Print audio stream 2 information
    if [ "${AUDIO_2}" != "" ]; then
        CODEC=$( echo -e $AUDIO_2 | awk '{print $4}' )
        CHANNELS=$( echo -e $AUDIO_1 | ${PERL} -nle 'print $1 if / (stereo),/; print $1 . " ch" if / (\d\.\d),/' )
        BITRATE=$( echo -e $AUDIO_2 | ${PERL} -nle 'print $1 if / (\d+ kb\/s)/' )
        FREQ=$( echo -e $AUDIO_2 | ${PERL} -nle 'print $1 if / (\d+ Hz)/' )
        printf "| %-4s %7s %9s %9s " \
            "${CODEC}" "${CHANNELS}" "${BITRATE}" "${FREQ}"
    fi


    # Finally print the filename
    echo -e "| $( basename ${FILE} )"
    

done
echo


################################################################################
################################################################################

