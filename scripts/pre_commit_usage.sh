#!/usr/bin/env bash

set -x
set -euo pipefail
PRE_COMMIT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAIN_SOURCES=$(cd "${PRE_COMMIT_DIR}/../" && pwd);
cd "${MAIN_SOURCES}" || exit 1

TMP_FILE=$(mktemp)
TMP_OUTPUT=$(mktemp)

trap 'rm "${TMP_FILE}"; ' EXIT
export MAX_SCREEN_WIDTH=100

echo '````' >"${TMP_FILE}"
./pianka.sh --help | sed 's/ *$//' >> "${TMP_FILE}"
echo '````' >> "${TMP_FILE}"

MAX_LEN=$(awk '{ print length($0); }' "${TMP_FILE}" | sort -n | tail -1 )

# 2 spaces added in front of the width for .rst formatting
if (( MAX_LEN > MAX_SCREEN_WIDTH )); then
    cat "${TMP_FILE}"
    echo
    echo "ERROR! Some lines in generate breeze help-all command are too long. See above ^^"
    echo
    echo
    exit 1
fi

TRACKED_FILE="${MAIN_SOURCES}/README.md"

LEAD='^<!\-\-\- START\ USAGE\ MARKER \-\->$'
TAIL='^<!\-\-\- END\ USAGE\ MARKER \-\->$'

BEGIN_GEN=$(grep -n "${LEAD}" <"${TRACKED_FILE}" | cut -d ":" -f 1)
END_GEN=$(grep -n "${TAIL}" <"${TRACKED_FILE}" | cut -d ":" -f 1)

cat <(head -n "${BEGIN_GEN}" "${TRACKED_FILE}") \
    "${TMP_FILE}" \
    <(tail -n +"${END_GEN}" "${TRACKED_FILE}") \
    >"${TMP_OUTPUT}"

mv "${TMP_OUTPUT}" "${TRACKED_FILE}"
