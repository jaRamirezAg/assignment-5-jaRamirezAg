#!/bin/sh
# Script de prueba para la asignación 4 - Adaptado para Buildroot
set -e 
set -u 

CONF_DIR=/etc/finder-app/conf
if [ -d "$CONF_DIR" ]; then
    username=$(cat "$CONF_DIR/username.txt")
else
    username=$(cat conf/username.txt)
fi

# 1. Definimos la base
NUMFILES=10
WRITESTR=AESD_IS_AWESOME
WRITEDIR_BASE=/tmp/aeld-data

# 2. Ajustamos según argumentos
if [ $# -ge 3 ]; then
    NUMFILES=$1
    WRITESTR=$2
    WRITEDIR=$WRITEDIR_BASE/$3
else
    echo "Usando valores por defecto"
    WRITEDIR=$WRITEDIR_BASE
fi

# 3. CREAR EL DIRECTORIO (Punto crítico)
rm -rf "$WRITEDIR"
mkdir -p "$WRITEDIR"

echo "Creando archivos usando el binario writer desde el PATH..."

for i in $(seq 1 $NUMFILES)
do
    writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

# 4. Ejecutar finder.sh y limpiar salida
OUTPUTSTRING=$(finder.sh "$WRITEDIR" "$WRITESTR" | tr -d '\r' | xargs)

# Escribir resultado
echo "${OUTPUTSTRING}" > /tmp/assignment4-result.txt

# 5. EXTRAER NÚMEROS (Basado en tu salida: "The number of files are 10...")
# En esa frase, el número 10 es la palabra 5 y la palabra 11
FOUND_FILES=$(echo "$OUTPUTSTRING" | awk '{print $5}')
FOUND_LINES=$(echo "$OUTPUTSTRING" | awk '{print $11}')

# 6. VERIFICACIÓN
if [ "$FOUND_FILES" = "$NUMFILES" ] && [ "$FOUND_LINES" = "$NUMFILES" ]; then
    echo "success"
    # Solo borramos si tuvimos éxito
    rm -rf "$WRITEDIR_BASE"
    exit 0
else
    echo "failed: expected ${NUMFILES} files but got ${OUTPUTSTRING}"
    exit 1
fi