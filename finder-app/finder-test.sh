#!/bin/sh
# Script de prueba para la asignación 2
# Autor: juanA

set -e # Detener el script si algún comando falla
set -u # Tratar variables no definidas como error

NUMFILES=10
WRITESTR=AESD_IS_AWESOME
WRITEDIR=/tmp/aeld-data
username=$(cat conf/username.txt)

if [ $# -lt 3 ]
then
	echo "Usando valores por defecto: $NUMFILES archivos con la cadena $WRITESTR en $WRITEDIR"
else
	NUMFILES=$1
	WRITESTR=$2
	WRITEDIR=/tmp/aeld-data/$3
fi

# ---------------------------------------------------------
# REQUISITO: Limpiar cualquier artefacto de compilación anterior
# ---------------------------------------------------------
echo "Limpiando artefactos previos..."
make clean

# ---------------------------------------------------------
# REQUISITO: Compilar la aplicación writer de forma nativa
# ---------------------------------------------------------
echo "Compilando aplicación writer..."
make

# Configuración de directorios
rm -rf "$WRITEDIR"
mkdir -p "$WRITEDIR"

if [ -d "$WRITEDIR" ]
then
	echo "Directorio creado exitosamente"
else
	echo "Error: No se pudo crear el directorio $WRITEDIR"
	exit 1
fi

# ---------------------------------------------------------
# REQUISITO: Utilizar la utilidad "writer" (binario) en lugar de "writer.sh"
# ---------------------------------------------------------
echo "Creando archivos usando el binario writer..."

for i in $(seq 1 $NUMFILES)
do
	# Notar que ahora llamamos a ./writer (el ejecutable compilado)
	./writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

# Ejecutar finder.sh para verificar resultados
OUTPUTSTRING=$(./finder.sh "$WRITEDIR" "$WRITESTR")

# Eliminar archivos temporales creados
rm -rf /tmp/aeld-data

# Verificar si el resultado coincide con lo esperado
echo ${OUTPUTSTRING} | grep "${NUMFILES}" > /dev/null
if [ $? -eq 0 ]; then
	echo "success"
	exit 0
else
	echo "failed: expected ${NUMFILES} files and matches but got ${OUTPUTSTRING}"
	exit 1
fi