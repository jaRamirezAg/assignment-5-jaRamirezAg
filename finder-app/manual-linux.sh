#!/bin/bash
# Script outline to install and build kernel.
# Author: JA.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

OUTDIR=$(realpath "${OUTDIR}")
mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    # Limpiar el árbol de construcción para evitar basura de otras arquitecturas
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    # Configurar el Kernel para la arquitectura ARM64 'virt' (QEMU)
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    # Compilar la imagen del Kernel (Image). -j$(nproc) usa todos tus núcleos
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    # Compilar los Device Tree (árbol de hardware)
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Adding the Image in outdir"
cp "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" "${OUTDIR}/Image"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
# Creamos la estructura estándar de Linux (FHS)
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone https://github.com/mirror/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    # Esto genera el archivo .config inicial basado en valores por defecto
else
    cd busybox
fi

# TODO: Make and install busybox
echo "Configuring busybox..."
make distclean
make defconfig

# ... después de make defconfig ...
echo "Desactivando TC para evitar errores de compilación..."
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config

# Instalamos busybox en nuestro directorio rootfs
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX="${OUTDIR}/rootfs" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

cd "${OUTDIR}/rootfs"


echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
# Buscamos dónde está el compilador para copiar sus librerías dinámicas
echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# 1. Obtenemos el SYSROOT correctamente
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
if [ -z "$SYSROOT" ] || [ "$SYSROOT" = "/" ]; then
    SYSROOT="/usr/aarch64-linux-gnu"
fi
echo "Buscando librerías en SYSROOT: $SYSROOT"

# 2. Copiamos el cargador dinámico (Interpreter)
INTERPRETER=$(find $SYSROOT -name "ld-linux-aarch64.so.1" | head -n 1)
if [ -n "$INTERPRETER" ]; then
    sudo cp -L "$INTERPRETER" "${OUTDIR}/rootfs/lib/"
    # TRUCO CLAVE: También ponlo en lib64 o crea un enlace simbólico
    sudo cp -L "$INTERPRETER" "${OUTDIR}/rootfs/lib64/"
else
    echo "ERROR: No se encontró ld-linux-aarch64.so.1"
    exit 1
fi

# 3. Copiamos las librerías compartidas
# En arquitecturas de 64 bits, suelen estar en /lib64
#sudo cp -L ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/
#sudo cp -L ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/
#sudo cp -L ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/

for LIB in libm.so.6 libresolv.so.2 libc.so.6; do
    FOUND_LIB=$(find $SYSROOT -name "$LIB" | head -n 1)
    if [ -n "$FOUND_LIB" ]; then
        sudo cp -L "$FOUND_LIB" "${OUTDIR}/rootfs/lib64/"
        # Opcional: también a /lib para máxima compatibilidad
        sudo cp -L "$FOUND_LIB" "${OUTDIR}/rootfs/lib/"
    else
        echo "ERROR: No se encontró $LIB"
        exit 1
    fi
done

# TODO: Make device nodes
# Creamos nodos esenciales para que el Kernel pueda hablar con el hardware
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# TODO: Clean and build the writer utility
# --- TODO: Clean and build the writer utility ---
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp writer ${OUTDIR}/rootfs/home/
cp finder.sh ${OUTDIR}/rootfs/home/
cp finder-test.sh ${OUTDIR}/rootfs/home/
cp autorun-qemu.sh ${OUTDIR}/rootfs/home/
mkdir -p ${OUTDIR}/rootfs/home/conf
cp conf/assignment.txt ${OUTDIR}/rootfs/home/conf/
cp conf/username.txt ${OUTDIR}/rootfs/home/conf/

# Modificamos el script de prueba para la nueva ruta (Requisito f.i)
sed -i 's|\.\./conf/assignment.txt|conf/assignment.txt|g' ${OUTDIR}/rootfs/home/finder-test.sh

# TODO: Chown the root directory
# El dueño de todo en el sistema final debe ser el usuario root
cd "${OUTDIR}/rootfs"
sudo chown -R root:root *

# TODO: Create initramfs.cpio.gz
# Empaquetamos todo en un archivo comprimido que el Kernel cargará en RAM
find . | cpio -H newc -ov --owner root:root > "${OUTDIR}/initramfs.cpio"

# Ahora nos movemos a OUTDIR para comprimir y verificar
cd "${OUTDIR}"
gzip -f "${OUTDIR}/initramfs.cpio"

ls -l "${OUTDIR}/Image"
ls -l "${OUTDIR}/initramfs.cpio.gz"