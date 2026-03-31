#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>

#define PORT "9000"
#define DATA_FILE "/var/tmp/aesdsocketdata"
#define BUFFER_SIZE 1024

int server_fd = -1;

void handle_signal(int sig) {
    syslog(LOG_INFO, "Caught signal, exiting");
    if (server_fd != -1) close(server_fd);
    remove(DATA_FILE);
    closelog();
    exit(0);
}

void daemonize() {
    pid_t pid = fork();
    if (pid < 0) exit(-1);
    if (pid > 0) exit(0);
    setsid();
    chdir("/");
    int fd = open("/dev/null", O_RDWR);
    if (fd >= 0) {
        dup2(fd, STDIN_FILENO);
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        close(fd);
    }
}

int main(int argc, char *argv[]) {
    openlog("aesdsocket", LOG_PID, LOG_USER);

    struct sigaction sa;
    sa.sa_handler = handle_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    struct addrinfo hints, *res;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;

    if (getaddrinfo(NULL, PORT, &hints, &res) != 0) return -1;

    server_fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (server_fd == -1) { freeaddrinfo(res); return -1; }

    int opt = 1;
    // SO_REUSEADDR es vital para que Valgrind no falle si el puerto quedó "limbo"
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    if (bind(server_fd, res->ai_addr, res->ai_addrlen) != 0) {
        syslog(LOG_ERR, "Bind failed: %m");
        freeaddrinfo(res);
        close(server_fd);
        return -1;
    }
    freeaddrinfo(res);

    if (argc > 1 && strcmp(argv[1], "-d") == 0) {
        daemonize();
    }

    if (listen(server_fd, 10) != 0) { close(server_fd); return -1; }

    while (1) {
        struct sockaddr_in client_addr;
        socklen_t addr_size = sizeof(client_addr);
        int client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &addr_size);
        if (client_fd == -1) continue;

        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
        syslog(LOG_INFO, "Accepted connection from %s", client_ip);

        // ABRIR PARA ESCRIBIR
        FILE *fp = fopen(DATA_FILE, "a");
        if (fp) {
            char buffer[BUFFER_SIZE];
            ssize_t bytes_recv;
            while ((bytes_recv = recv(client_fd, buffer, BUFFER_SIZE, 0)) > 0) {
                fwrite(buffer, 1, bytes_recv, fp);
                if (memchr(buffer, '\n', bytes_recv)) break;
            }
            fclose(fp);
        }

        // ABRIR PARA LEER Y ENVIAR
        fp = fopen(DATA_FILE, "r");
        if (fp) {
            char buffer[BUFFER_SIZE];
            size_t bytes_read;
            while ((bytes_read = fread(buffer, 1, BUFFER_SIZE, fp)) > 0) {
                send(client_fd, buffer, bytes_read, 0);
            }
            fclose(fp);
        }

        close(client_fd);
        syslog(LOG_INFO, "Closed connection from %s", client_ip);
    }
    return 0;
}