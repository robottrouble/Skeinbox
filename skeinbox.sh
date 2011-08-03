#!/bin/bash

WAIT_TIME=30
SCRIPT_NAME=`basename $0`
MAX_PROCS=2

get_skeinforge() {
	SKEINFORGE_VERSION=$1

	case "$SKEINFORGE_VERSION" in
		"0006")
			echo "./skeinforge/skeinforge-0006/skeinforge.py"
			;;
		"35")
			echo "./skeinforge/skeinforge-35/skeinforge_application/skeinforge.py"
			;;
	esac
				

}

skein_file() {
	FILE="$1"
	if [ -z "$FILE" ]; then
		echo "No input file found. exiting..."
		exit 1
	fi
	RUN_DIR=`dirname "$FILE"`
	PREFS_DIR="${RUN_DIR}/prefs/"
    OUT_DIR=`echo "$FILE" | sed -e 's/\.stl//g'`
	RUN_FILE="${OUT_DIR}/"`basename "${FILE}"`
	GCODE_FILE=`echo "$RUN_FILE" | sed -e 's/\.stl/.gcode/g'`
	LOG_DIR="${OUT_DIR}/logs/"
	TMP_DIR="${OUT_DIR}/tmp/"
	SKEIN_LOG_FILE="/dev/null"
	RENDER_LOG_FILE="/dev/null"

	ERR_FILE="${ERR_DIR}"`basename "${FILE}".err`

	SKEINFORGE_VERSION="0006"
	DEBUG_LOG="true"
	RENDER_STL="true"
	RENDER_GCODE="true"


    for DIR in "${OUT_DIR}" "${LOG_DIR}" "${TMP_DIR}"; do
		if [ ! -d "${DIR}" ]; then
			mkdir -p "${DIR}"
		fi
	done

	if [ ! -d "${LOG_DIR}" ]; then
		mkdir -p "${LOG_DIR}"
	fi

	if [ ! -d "${PREFS_DIR}" ]; then
		echo "ERROR: no prefs directory" >> "${ERR_FILE}"
	fi

	if [ ! -f "${RUN_DIR}/skeinbox.conf" ]; then
		echo "ERROR: no prefs directory" >> "${ERR_FILE}"
	else
		. "${RUN_DIR}/skeinbox.conf"
	fi

    mv "${FILE}" "${RUN_FILE}"

	if [ "${DEBUG_LOG}" == "true" ]; then
		SKEIN_LOG_FILE="${LOG_DIR}/skeinforge.log"
		RENDER_LOG_FILE="${LOG_DIR}/render_stl.log"
	fi


	SKEINFORGE=`get_skeinforge "$SKEINFORGE_VERSION"`

	if [ -z "$SKEINFORGE" ]; then
		echo "ERROR: invalid skeinforge version" >> "${ERR_FILE}"
		exit 1;
	fi
	echo "Starting skeinforge: $SKEINFORGE"
	python "$SKEINFORGE" -p "${PREFS_DIR}" "${RUN_FILE}" 2>&1 | tee "$SKEIN_LOG_FILE"
  
  
  	if [ "$RENDER_STL" == "true" ]; then
		../STLRender/render_stl.sh "${RUN_FILE}" "${TMP_DIR}" 2>&1 | tee "$RENDER_LOG_FILE"
	fi

	if [ "$RENDER_GCODE" == "true" ]; then
		../GView/gview_svg.php "${GCODE_FILE}"
	fi
     
	if [ $? -ne 0 ]; then
		mv "${RUN_FILE}" "${ERR_DIR}"
		echo "ERROR: skeinforge failed" > "${ERR_FILE}"
	fi

	rm -rf "${TMP_DIR}"
}

while true; do
	find ../*_sb -maxdepth 1 -name \*.stl | while read FILE; do
		while [ `ps -ef | grep "/bin/bash" | grep -c "$SCRIPT_NAME"` -gt $[ $MAX_PROCS + 2 ] ]; do
			echo "Already running max procs of ${MAX_PROCS}..."
			sleep 10
	    done

		echo "Starting skeinbox job for file ${FILE}..."
		SAFE_FILENAME=`echo $FILE | sed -e 's/(//g' -e 's/)//g'`
		mv "$FILE" "$SAFE_FILENAME"
		skein_file "$SAFE_FILENAME" & > /dev/null
    done

	echo Sleeping...
	sleep $WAIT_TIME
done
