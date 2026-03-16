#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <syslog.h>
#include <string.h>
#include <errno.h>

/**
 * writer.c - Una alternativa en C al script writer.sh
 * * Requisitos:
 * 1. Usa File IO (open, write, close).
 * 2. No crea directorios (asume que existen).
 * 3. Usa syslog con LOG_USER.
 * 4. Loggea el éxito con LOG_DEBUG y errores con LOG_ERR.
 */

int main(int argc, char *argv[]) {
    // 1. Configurar el registro syslog con LOG_USER
    openlog("writer-app", LOG_PID, LOG_USER);

    // 2. Validar argumentos (necesitamos exactamente 2: archivo y cadena)
    if (argc != 3) {
        syslog(LOG_ERR, "Error: Número de argumentos inválido. Se esperaban 2, se recibieron %d", argc - 1);
        fprintf(stderr, "Uso: %s <fichero> <cadena>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    // 3. Abrir el archivo usando la llamada al sistema open()
    // O_WRONLY: Solo escritura
    // O_CREAT: Crear el archivo si no existe
    // O_TRUNC: Truncar (vaciar) el archivo si ya existe
    // Permisos 0644: rw-r--r--
    int fd = open(writefile, O_WRONLY | O_CREAT | O_TRUNC, 0644);

    if (fd == -1) {
        syslog(LOG_ERR, "Error al abrir/crear el archivo %s: %s", writefile, strerror(errno));
        perror("Error en open");
        closelog();
        return 1;
    }

    // 4. Escribir la cadena en el archivo usando write()
    size_t len = strlen(writestr);
    ssize_t bytes_written = write(fd, writestr, len);

    if (bytes_written == -1) {
        syslog(LOG_ERR, "Error al escribir en el archivo %s: %s", writefile, strerror(errno));
        perror("Error en write");
        close(fd);
        closelog();
        return 1;
    } 
    
    // Verificación adicional: ¿se escribió todo el buffer?
    if (bytes_written != (ssize_t)len) {
        syslog(LOG_ERR, "Error: No se pudieron escribir todos los bytes en %s", writefile);
    } else {
        // 5. Registrar éxito en syslog con nivel LOG_DEBUG
        syslog(LOG_DEBUG, "Escribiendo %s en %s", writestr, writefile);
    }

    // 6. Limpiar y cerrar
    if (close(fd) == -1) {
        syslog(LOG_ERR, "Error al cerrar el descriptor de archivo: %s", strerror(errno));
    }

    closelog();
    return 0;
}
