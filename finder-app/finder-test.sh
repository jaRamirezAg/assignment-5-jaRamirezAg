#!/bin/sh
set -e
set -u

NUMFILES=10
WRITESTR=AESD_IS_AWESOME
WRITEDIR=/tmp/aeld-data

if [ -d /etc/finder-app/conf ]; then
    username=$(cat /etc/finder-app/conf/username.txt)
else
    username=$(cat conf/username.txt)
fi

if [ $# -lt 3 ]; then
    echo "Usando valores por defecto"
else
    NUMFILES=$1
    WRITESTR=$2
    WRITEDIR=/tmp/aeld-data/$3
fi

# El string exacto que esperamos
MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Creando archivos usando el binario writer desde el PATH..."
rm -rf "${WRITEDIR}"
mkdir -p "$WRITEDIR"

for i in $(seq 1 $NUMFILES)
do
    writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

# Ejecutamos finder y capturamos salida
OUTPUTSTRING=$(finder.sh "$WRITEDIR" "$WRITESTR")
echo "${OUTPUTSTRING}" > /tmp/assignment4-result.txt

# Comparación directa
if [ "$OUTPUTSTRING" = "$MATCHSTR" ]; then
    echo "success"
    exit 0
else
    echo "failed: expected ${NUMFILES} files but got ${OUTPUTSTRING}"
    exit 1
fi