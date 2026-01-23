#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/types.h>

volatile int done = 0;
volatile int processed = 0;

void *scan_proc(void *arg)
{
    DIR *procDir = opendir("/proc");
    if (!procDir) {
        perror("opendir /proc");
        done = 1;
        return NULL;
    }
    struct dirent *entry;
    while ((entry = readdir(procDir)) != NULL) {
        char *endptr;
        int pid = (int)strtol(entry->d_name, &endptr, 10);
        if (*endptr == '\0' && pid > 0) {
            char statPath[256];
            snprintf(statPath, sizeof(statPath), "/proc/%d/stat", pid);
            FILE *statFile = fopen(statPath, "r");
            if (!statFile) continue;
            char statLine[2048];
            if (!fgets(statLine, sizeof(statLine), statFile)) { fclose(statFile); continue; }
            // quick sanity checks
            if (strlen(statLine) < 10) { fclose(statFile); continue; }
            char cmdPath[256];
            snprintf(cmdPath, sizeof(cmdPath), "/proc/%d/cmdline", pid);
            FILE *cmdFile = fopen(cmdPath, "r");
            if (cmdFile) {
                char cmdLine[1024];
                size_t len = fread(cmdLine, 1, sizeof(cmdLine)-1, cmdFile);
                if (len > 0) cmdLine[len] = '\0'; else cmdLine[0] = '\0';
                fclose(cmdFile);
            }
            processed++;
        }
    }
    closedir(procDir);
    done = 1;
    return NULL;
}

int main(void)
{
    pthread_t t;
    if (pthread_create(&t, NULL, scan_proc, NULL) != 0) {
        perror("pthread_create");
        return 1;
    }

    int waited = 0;
    while (!done && waited < 10) {
        sleep(1);
        waited++;
    }

    if (!done) {
        fprintf(stderr, "Timed out waiting for scan (processed=%d)\n", processed);
        return 2;
    }

    printf("Scan finished safely. processed=%d\n", processed);
    return 0;
}
