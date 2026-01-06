/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Network Helper Tool
 *
 * A helper CLI tool for privileged network operations.
 * This tool is meant to be called via sudo -A -E from the Network preference pane.
 * The SUDO_ASKPASS environment variable should point to a graphical password dialog.
 *
 * This is a pure C program without GNUstep dependencies so it works reliably
 * when invoked via sudo without requiring LD_LIBRARY_PATH setup.
 *
 * Usage:
 *   network-helper <command> [arguments...]
 *
 * Commands:
 *   wlan-enable           Enable WLAN radio
 *   wlan-disable          Disable WLAN radio
 *   wlan-connect <ssid> [password]   Connect to WLAN network
 *   wlan-disconnect       Disconnect from current WLAN network
 *   wlan-direct-connect <interface> <ssid> [password]  Direct wpa_supplicant connect
 *   dhcp-renew <interface>  Renew DHCP lease on interface
 *   dhcp-release <interface>  Release DHCP lease on interface
 *   connection-add <type> <name> [device]   Add a new connection
 *   connection-delete <name>   Delete a connection
 *   connection-up <name>       Activate a connection
 *   connection-down <name>     Deactivate a connection
 *   interface-enable <device>  Enable a network interface
 *   interface-disable <device> Disable a network interface
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>

#define MAX_ARGS 32
#define MAX_OUTPUT 4096

static char nmcli_path[256] = {0};
static char wpa_cli_path[256] = {0};
static char dhcpcd_path[256] = {0};

/* Forward declarations */
static int run_command(char *const args[], char *error_buf, size_t error_buf_size);
static int dhcp_renew(const char *interface);

/* Find executable in common paths */
static int find_executable(const char *name, char *buffer, size_t buffer_size) {
    char test_path[512];
    const char *paths[] = {
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        NULL
    };
    
    for (int i = 0; paths[i] != NULL; i++) {
        snprintf(test_path, sizeof(test_path), "%s/%s", paths[i], name);
        if (access(test_path, X_OK) == 0) {
            strncpy(buffer, test_path, buffer_size - 1);
            buffer[buffer_size - 1] = '\0';
            return 1;
        }
    }
    
    return 0;
}

/* Find nmcli executable */
static int find_nmcli(void) {
    return find_executable("nmcli", nmcli_path, sizeof(nmcli_path));
}

/* Find wpa_cli executable */
static int find_wpa_cli(void) {
    return find_executable("wpa_cli", wpa_cli_path, sizeof(wpa_cli_path));
}

/* Find dhcpcd executable */
static int find_dhcpcd(void) {
    return find_executable("dhcpcd", dhcpcd_path, sizeof(dhcpcd_path));
}

/* Run nmcli command with given arguments
 * Returns exit code, captures stderr for error reporting */
static int run_nmcli(char *const args[], char *error_buf, size_t error_buf_size) {
    if (nmcli_path[0] == '\0') {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "nmcli not found");
        }
        return 1;
    }
    
    int pipefd[2];  /* For capturing stderr */
    if (pipe(pipefd) < 0) {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "Failed to create pipe: %s", strerror(errno));
        }
        return 1;
    }
    
    pid_t pid = fork();
    
    if (pid < 0) {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "Failed to fork: %s", strerror(errno));
        }
        close(pipefd[0]);
        close(pipefd[1]);
        return 1;
    }
    
    if (pid == 0) {
        /* Child process */
        close(pipefd[0]);  /* Close read end */
        
        /* Redirect stderr to pipe */
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);
        
        /* Execute nmcli */
        execv(nmcli_path, args);
        
        /* If exec fails */
        fprintf(stderr, "Failed to execute nmcli: %s", strerror(errno));
        _exit(127);
    }
    
    /* Parent process */
    close(pipefd[1]);  /* Close write end */
    
    /* Read stderr output */
    if (error_buf && error_buf_size > 0) {
        ssize_t n = read(pipefd[0], error_buf, error_buf_size - 1);
        if (n > 0) {
            error_buf[n] = '\0';
            /* Remove trailing newline */
            while (n > 0 && (error_buf[n-1] == '\n' || error_buf[n-1] == '\r')) {
                error_buf[--n] = '\0';
            }
        } else {
            error_buf[0] = '\0';
        }
    }
    close(pipefd[0]);
    
    /* Wait for child */
    int status;
    waitpid(pid, &status, 0);
    
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    
    return 1;
}

/* Run nmcli with output capture (for commands that need to parse output) */
static int run_nmcli_with_output(char *const args[], char *output_buf, size_t output_buf_size,
                                  char *error_buf, size_t error_buf_size) {
    if (nmcli_path[0] == '\0') {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "nmcli not found");
        }
        return 1;
    }
    
    int stdout_pipe[2];
    int stderr_pipe[2];
    
    if (pipe(stdout_pipe) < 0 || pipe(stderr_pipe) < 0) {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "Failed to create pipes: %s", strerror(errno));
        }
        return 1;
    }
    
    pid_t pid = fork();
    
    if (pid < 0) {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "Failed to fork: %s", strerror(errno));
        }
        close(stdout_pipe[0]); close(stdout_pipe[1]);
        close(stderr_pipe[0]); close(stderr_pipe[1]);
        return 1;
    }
    
    if (pid == 0) {
        /* Child process */
        close(stdout_pipe[0]);
        close(stderr_pipe[0]);
        
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);
        
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);
        
        execv(nmcli_path, args);
        _exit(127);
    }
    
    /* Parent process */
    close(stdout_pipe[1]);
    close(stderr_pipe[1]);
    
    if (output_buf && output_buf_size > 0) {
        ssize_t n = read(stdout_pipe[0], output_buf, output_buf_size - 1);
        output_buf[n > 0 ? n : 0] = '\0';
    }
    close(stdout_pipe[0]);
    
    if (error_buf && error_buf_size > 0) {
        ssize_t n = read(stderr_pipe[0], error_buf, error_buf_size - 1);
        if (n > 0) {
            error_buf[n] = '\0';
            while (n > 0 && (error_buf[n-1] == '\n' || error_buf[n-1] == '\r')) {
                error_buf[--n] = '\0';
            }
        } else {
            error_buf[0] = '\0';
        }
    }
    close(stderr_pipe[0]);
    
    int status;
    waitpid(pid, &status, 0);
    
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    
    return 1;
}

/* Enable WLAN radio */
static int wlan_enable(void) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[] = {nmcli_path, "radio", "wifi", "on", NULL};
    int result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error enabling WLAN: %s\n", error_buf);
    }
    return result;
}

/* Disable WLAN radio */
static int wlan_disable(void) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[] = {nmcli_path, "radio", "wifi", "off", NULL};
    int result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error disabling WLAN: %s\n", error_buf);
    }
    return result;
}

/* Delete a connection by name (helper for wlan_connect) */
static void delete_connection(const char *name) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[] = {nmcli_path, "connection", "delete", (char *)name, NULL};
    run_nmcli(args, error_buf, sizeof(error_buf));
    /* Ignore errors - connection might not exist */
}

/* Connect to WLAN network using connection add method */
static int wlan_connect(const char *ssid, const char *password) {
    char error_buf[MAX_OUTPUT] = {0};
    int result;
    
    if (!ssid || ssid[0] == '\0') {
        fprintf(stderr, "Error: SSID is required\n");
        return 1;
    }
    
    /* If no password, use simple device wifi connect */
    if (!password || password[0] == '\0') {
        char *args[] = {nmcli_path, "device", "wifi", "connect", (char *)ssid, NULL};
        result = run_nmcli(args, error_buf, sizeof(error_buf));
        if (result != 0 && error_buf[0] != '\0') {
            fprintf(stderr, "Error connecting to WLAN '%s': %s\n", ssid, error_buf);
        }
        return result;
    }
    
    /* For secured networks, use connection add with explicit security settings */
    /* This is more reliable than device wifi connect */
    
    /* First delete any existing connection with this SSID */
    delete_connection(ssid);
    
    /* Create connection: nmcli connection add type wifi con-name SSID ssid SSID wifi-sec.key-mgmt wpa-psk wifi-sec.psk PASSWORD */
    char *add_args[] = {
        nmcli_path, "connection", "add",
        "type", "wifi",
        "con-name", (char *)ssid,
        "ssid", (char *)ssid,
        "wifi-sec.key-mgmt", "wpa-psk",
        "wifi-sec.psk", (char *)password,
        NULL
    };
    
    result = run_nmcli(add_args, error_buf, sizeof(error_buf));
    
    if (result != 0) {
        fprintf(stderr, "Error creating connection profile for '%s': %s\n", ssid, error_buf);
        return result;
    }
    
    /* Now activate the connection */
    char *up_args[] = {nmcli_path, "connection", "up", (char *)ssid, NULL};
    result = run_nmcli(up_args, error_buf, sizeof(error_buf));
    
    if (result != 0) {
        fprintf(stderr, "Error activating connection '%s': %s\n", ssid, error_buf);
        /* Clean up the failed connection profile */
        delete_connection(ssid);
        return result;
    }
    
    return 0;
}

/* Disconnect from current WLAN */
static int wlan_disconnect(void) {
    char output_buf[MAX_OUTPUT] = {0};
    char error_buf[MAX_OUTPUT] = {0};
    
    /* First find the wifi device */
    char *args[] = {nmcli_path, "-t", "-f", "DEVICE,TYPE", "device", NULL};
    int result = run_nmcli_with_output(args, output_buf, sizeof(output_buf),
                                        error_buf, sizeof(error_buf));
    
    if (result != 0) {
        fprintf(stderr, "Error listing devices: %s\n", error_buf);
        return result;
    }
    
    /* Parse output to find WLAN device */
    char *line = strtok(output_buf, "\n");
    while (line != NULL) {
        char *colon = strchr(line, ':');
        if (colon != NULL) {
            *colon = '\0';
            char *device = line;
            char *type = colon + 1;
            
            if (strcmp(type, "wifi") == 0) {
                /* Found WLAN device, disconnect it */
                char *disconnect_args[] = {nmcli_path, "device", "disconnect", device, NULL};
                result = run_nmcli(disconnect_args, error_buf, sizeof(error_buf));
                
                if (result != 0 && error_buf[0] != '\0') {
                    fprintf(stderr, "Error disconnecting WLAN device %s: %s\n", device, error_buf);
                }
                return result;
            }
        }
        line = strtok(NULL, "\n");
    }
    
    fprintf(stderr, "Error: No WLAN device found\n");
    return 1;
}

/* Add a new connection */
static int connection_add(const char *type, const char *name, const char *device) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[10];
    int i = 0;
    
    args[i++] = nmcli_path;
    args[i++] = "connection";
    args[i++] = "add";
    args[i++] = "type";
    args[i++] = (char *)type;
    args[i++] = "con-name";
    args[i++] = (char *)name;
    
    if (device && device[0] != '\0') {
        args[i++] = "ifname";
        args[i++] = (char *)device;
    }
    args[i] = NULL;
    
    int result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error adding connection '%s': %s\n", name, error_buf);
    }
    return result;
}

/* Delete a connection */
static int connection_delete(const char *name) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[] = {nmcli_path, "connection", "delete", (char *)name, NULL};
    int result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error deleting connection '%s': %s\n", name, error_buf);
    }
    return result;
}

/* Activate a connection */
static int connection_up(const char *name) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[] = {nmcli_path, "connection", "up", (char *)name, NULL};
    int result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error activating connection '%s': %s\n", name, error_buf);
    }
    return result;
}

/* Deactivate a connection */
static int connection_down(const char *name) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[] = {nmcli_path, "connection", "down", (char *)name, NULL};
    int result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error deactivating connection '%s': %s\n", name, error_buf);
    }
    return result;
}

/* Enable interface */
static int interface_enable(const char *device) {
    char error_buf[MAX_OUTPUT] = {0};
    char output_buf[MAX_OUTPUT] = {0};
    int result;
    
    /* First try nmcli device connect */
    char *args[] = {nmcli_path, "device", "connect", (char *)device, NULL};
    result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result == 0) {
        return 0;
    }
    
    fprintf(stderr, "nmcli device connect failed: %s\n", error_buf);
    
    /* If that failed, try to find and activate an existing connection for this device */
    /* Get list of connections for this device */
    char *list_args[] = {nmcli_path, "-t", "-f", "NAME,DEVICE,TYPE", "connection", "show", NULL};
    result = run_nmcli_with_output(list_args, output_buf, sizeof(output_buf), error_buf, sizeof(error_buf));
    
    if (result == 0 && output_buf[0] != '\0') {
        /* Parse output to find a connection for our device */
        char *saveptr;
        char *line = strtok_r(output_buf, "\n", &saveptr);
        while (line != NULL) {
            /* Format is: connection_name:device:type */
            char conn_name[256] = {0};
            char conn_dev[64] = {0};
            
            char *colon1 = strchr(line, ':');
            if (colon1) {
                strncpy(conn_name, line, colon1 - line);
                conn_name[colon1 - line] = '\0';
                
                char *colon2 = strchr(colon1 + 1, ':');
                if (colon2) {
                    strncpy(conn_dev, colon1 + 1, colon2 - colon1 - 1);
                    conn_dev[colon2 - colon1 - 1] = '\0';
                }
            }
            
            /* Check if this connection is for our device or has no device assigned */
            if (conn_name[0] != '\0' && 
                (strcmp(conn_dev, device) == 0 || conn_dev[0] == '\0' || strcmp(conn_dev, "--") == 0)) {
                /* Found a potential connection, try to activate it */
                fprintf(stdout, "Trying to activate connection '%s' for device %s\n", conn_name, device);
                
                char *up_args[] = {nmcli_path, "connection", "up", conn_name, "ifname", (char *)device, NULL};
                result = run_nmcli(up_args, error_buf, sizeof(error_buf));
                
                if (result == 0) {
                    fprintf(stdout, "Successfully activated connection '%s'\n", conn_name);
                    return 0;
                }
            }
            
            line = strtok_r(NULL, "\n", &saveptr);
        }
    }
    
    /* If still failed, try to bring up the interface with ip link */
    fprintf(stdout, "Trying ip link set %s up...\n", device);
    char ip_path[256] = {0};
    if (find_executable("ip", ip_path, sizeof(ip_path))) {
        char *ip_args[] = {ip_path, "link", "set", (char *)device, "up", NULL};
        result = run_command(ip_args, error_buf, sizeof(error_buf));
        if (result == 0) {
            fprintf(stdout, "Interface %s is up, requesting DHCP...\n", device);
            /* Also try to get DHCP */
            result = dhcp_renew(device);
            return result;
        }
    }
    
    fprintf(stderr, "Error enabling interface '%s': all methods failed\n", device);
    return 1;
}

/* Disable interface */
static int interface_disable(const char *device) {
    char error_buf[MAX_OUTPUT] = {0};
    char *args[] = {nmcli_path, "device", "disconnect", (char *)device, NULL};
    int result = run_nmcli(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error disabling interface '%s': %s\n", device, error_buf);
    }
    return result;
}

/* Run a system command and return exit code */
static int run_command(char *const args[], char *error_buf, size_t error_buf_size) {
    if (!args || !args[0]) {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "No command specified");
        }
        return 1;
    }
    
    int pipefd[2];  /* For capturing stderr */
    if (pipe(pipefd) < 0) {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "Failed to create pipe: %s", strerror(errno));
        }
        return 1;
    }
    
    pid_t pid = fork();
    
    if (pid < 0) {
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size, "Failed to fork: %s", strerror(errno));
        }
        close(pipefd[0]);
        close(pipefd[1]);
        return 1;
    }
    
    if (pid == 0) {
        /* Child process */
        close(pipefd[0]);  /* Close read end */
        
        /* Redirect stderr to pipe */
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);
        
        /* Execute command */
        execv(args[0], args);
        
        /* If execv returns, an error occurred */
        fprintf(stderr, "Failed to execute %s: %s\n", args[0], strerror(errno));
        exit(1);
    }
    
    /* Parent process */
    close(pipefd[1]);  /* Close write end */
    
    /* Read stderr */
    if (error_buf && error_buf_size > 0) {
        ssize_t bytes_read = read(pipefd[0], error_buf, error_buf_size - 1);
        if (bytes_read > 0) {
            error_buf[bytes_read] = '\0';
            /* Remove trailing newline */
            if (error_buf[bytes_read - 1] == '\n') {
                error_buf[bytes_read - 1] = '\0';
            }
        } else {
            error_buf[0] = '\0';
        }
    }
    close(pipefd[0]);
    
    int status;
    waitpid(pid, &status, 0);
    
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    
    return 1;
}

/* Renew DHCP lease on interface using dhcpcd */
static int dhcp_renew(const char *interface) {
    char error_buf[MAX_OUTPUT] = {0};
    int result;
    
    if (!interface || interface[0] == '\0') {
        fprintf(stderr, "Error: Interface name is required\n");
        return 1;
    }
    
    if (!find_dhcpcd()) {
        fprintf(stderr, "Error: dhcpcd not found. Is dhcpcd installed?\n");
        return 1;
    }
    
    /* Kill any existing dhcpcd for this interface first */
    char *kill_args[] = {dhcpcd_path, "-x", (char *)interface, NULL};
    run_command(kill_args, error_buf, sizeof(error_buf));
    /* Ignore errors - dhcpcd might not be running */
    
    /* Wait a moment for cleanup */
    usleep(500000);  /* 500ms */
    
    /* Start dhcpcd with options to try harder for IPv4:
     * -4: IPv4 only (focus on getting IPv4)
     * -t 30: 30 second timeout (instead of default ~10s)
     * --noipv4ll: Don't fall back to link-local immediately
     */
    fprintf(stdout, "Requesting IPv4 address via DHCP (30s timeout)...\n");
    char *renew_args[] = {dhcpcd_path, "-4", "-t", "30", "--noipv4ll", (char *)interface, NULL};
    result = run_command(renew_args, error_buf, sizeof(error_buf));
    
    if (result != 0) {
        /* If --noipv4ll failed, try without it */
        fprintf(stdout, "Retrying with fallback options...\n");
        char *retry_args[] = {dhcpcd_path, "-4", "-t", "20", (char *)interface, NULL};
        result = run_command(retry_args, error_buf, sizeof(error_buf));
    }
    
    /* If still failed, try dual-stack */
    if (result != 0) {
        fprintf(stdout, "Trying dual-stack DHCP...\n");
        char *dual_args[] = {dhcpcd_path, "-t", "15", (char *)interface, NULL};
        result = run_command(dual_args, error_buf, sizeof(error_buf));
    }
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "DHCP request failed on '%s': %s\n", interface, error_buf);
    }
    
    return result;
}

/* Release DHCP lease on interface */
static int dhcp_release(const char *interface) {
    char error_buf[MAX_OUTPUT] = {0};
    
    if (!interface || interface[0] == '\0') {
        fprintf(stderr, "Error: Interface name is required\n");
        return 1;
    }
    
    if (!find_dhcpcd()) {
        fprintf(stderr, "Error: dhcpcd not found. Is dhcpcd installed?\n");
        return 1;
    }
    
    /* Kill dhcpcd for this interface */
    char *args[] = {dhcpcd_path, "-k", (char *)interface, NULL};
    int result = run_command(args, error_buf, sizeof(error_buf));
    
    if (result != 0 && error_buf[0] != '\0') {
        fprintf(stderr, "Error releasing DHCP lease on '%s': %s\n", interface, error_buf);
    }
    
    return result;
}

/* Direct WiFi connection using wpa_cli and dhcpcd */
static int wlan_direct_connect(const char *interface, const char *ssid, const char *password) {
    int result;
    
    if (!interface || interface[0] == '\0') {
        fprintf(stderr, "Error: Interface name is required\n");
        return 1;
    }
    
    if (!ssid || ssid[0] == '\0') {
        fprintf(stderr, "Error: SSID is required\n");
        return 1;
    }
    
    if (!find_wpa_cli()) {
        fprintf(stderr, "Error: wpa_cli not found. Is wpa_supplicant installed?\n");
        return 1;
    }
    
    /* Add network in wpa_supplicant */
    char cmd_buf[512];
    FILE *fp;
    int network_id = -1;
    
    /* Add network and get network ID */
    snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s add_network", wpa_cli_path, interface);
    fp = popen(cmd_buf, "r");
    if (fp) {
        if (fscanf(fp, "%d", &network_id) != 1) {
            fprintf(stderr, "Error: Failed to add network\n");
            pclose(fp);
            return 1;
        }
        pclose(fp);
    } else {
        fprintf(stderr, "Error: Failed to run wpa_cli add_network\n");
        return 1;
    }
    
    /* Set SSID */
    snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s set_network %d ssid '\"%s\"'",
             wpa_cli_path, interface, network_id, ssid);
    result = system(cmd_buf);
    if (result != 0) {
        fprintf(stderr, "Error: Failed to set SSID\n");
        return 1;
    }
    
    /* Set password if provided */
    if (password && password[0] != '\0') {
        snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s set_network %d psk '\"%s\"'",
                 wpa_cli_path, interface, network_id, password);
        result = system(cmd_buf);
        if (result != 0) {
            fprintf(stderr, "Error: Failed to set password\n");
            return 1;
        }
    } else {
        /* Open network - no encryption */
        snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s set_network %d key_mgmt NONE",
                 wpa_cli_path, interface, network_id);
        result = system(cmd_buf);
        if (result != 0) {
            fprintf(stderr, "Error: Failed to configure open network\n");
            return 1;
        }
    }
    
    /* Enable the network */
    snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s enable_network %d",
             wpa_cli_path, interface, network_id);
    result = system(cmd_buf);
    if (result != 0) {
        fprintf(stderr, "Error: Failed to enable network\n");
        return 1;
    }
    
    /* Select this network */
    snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s select_network %d",
             wpa_cli_path, interface, network_id);
    result = system(cmd_buf);
    if (result != 0) {
        fprintf(stderr, "Error: Failed to select network\n");
        return 1;
    }
    
    /* Save configuration */
    snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s save_config", wpa_cli_path, interface);
    system(cmd_buf);  /* Ignore errors for save_config */
    
    /* Wait for connection and check status */
    fprintf(stdout, "Connecting to WLAN '%s'...\n", ssid);
    int max_wait = 15;  /* Wait up to 15 seconds */
    int connected = 0;
    
    for (int i = 0; i < max_wait; i++) {
        sleep(1);
        
        /* Check wpa_supplicant state */
        snprintf(cmd_buf, sizeof(cmd_buf), "%s -i %s status | grep wpa_state", wpa_cli_path, interface);
        fp = popen(cmd_buf, "r");
        if (fp) {
            char status_line[256];
            if (fgets(status_line, sizeof(status_line), fp)) {
                if (strstr(status_line, "COMPLETED")) {
                    connected = 1;
                    pclose(fp);
                    break;
                }
            }
            pclose(fp);
        }
        
        if (i % 3 == 0) {
            fprintf(stdout, "  Waiting for authentication...\n");
        }
    }
    
    if (!connected) {
        fprintf(stderr, "Error: Failed to authenticate with network '%s'\n", ssid);
        fprintf(stderr, "Please check your password and try again.\n");
        return 1;
    }
    
    fprintf(stdout, "WiFi authentication successful!\n");
    
    /* Wait a bit more for link to be fully up */
    sleep(2);
    
    /* Start DHCP */
    fprintf(stdout, "Requesting IP address via DHCP...\n");
    result = dhcp_renew(interface);
    
    if (result == 0) {
        /* Wait for DHCP to complete */
        sleep(3);
        fprintf(stdout, "Successfully connected to '%s'\n", ssid);
        fprintf(stdout, "Please check your IP address with: ip addr show %s\n", interface);
    } else {
        fprintf(stderr, "Warning: WiFi connected but DHCP may have failed\n");
        fprintf(stderr, "Check with: ip addr show %s\n", interface);
    }
    
    return result;
}

/* Print usage */
static void usage(const char *prog) {
    fprintf(stderr, "Network Helper - Privileged network operations\n\n");
    fprintf(stderr, "Usage: %s <command> [arguments...]\n\n", prog);
    fprintf(stderr, "Commands:\n");
    fprintf(stderr, "  wlan-enable                              Enable WLAN radio\n");
    fprintf(stderr, "  wlan-disable                             Disable WLAN radio\n");
    fprintf(stderr, "  wlan-connect <ssid> [password]           Connect to WLAN network (via NetworkManager)\n");
    fprintf(stderr, "  wlan-disconnect                          Disconnect from WLAN\n");
    fprintf(stderr, "  wlan-direct-connect <iface> <ssid> [pw]  Direct wpa_supplicant + DHCP connection\n");
    fprintf(stderr, "  dhcp-renew <interface>                   Renew DHCP lease on interface\n");
    fprintf(stderr, "  dhcp-release <interface>                 Release DHCP lease on interface\n");
    fprintf(stderr, "  connection-add <type> <name> [device]    Add connection\n");
    fprintf(stderr, "  connection-delete <name>                 Delete connection\n");
    fprintf(stderr, "  connection-up <name>                     Activate connection\n");
    fprintf(stderr, "  connection-down <name>                   Deactivate connection\n");
    fprintf(stderr, "  interface-enable <device>                Enable interface\n");
    fprintf(stderr, "  interface-disable <device>               Disable interface\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        usage(argv[0]);
        return 1;
    }
    
    if (!find_nmcli()) {
        fprintf(stderr, "Error: nmcli not found. Is NetworkManager installed?\n");
        return 1;
    }
    
    const char *command = argv[1];
    int result = 0;
    
    if (strcmp(command, "wlan-enable") == 0) {
        result = wlan_enable();
    } else if (strcmp(command, "wlan-disable") == 0) {
        result = wlan_disable();
    } else if (strcmp(command, "wlan-connect") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: wlan-connect requires SSID argument\n");
            result = 1;
        } else {
            const char *ssid = argv[2];
            const char *password = (argc >= 4) ? argv[3] : NULL;
            result = wlan_connect(ssid, password);
        }
    } else if (strcmp(command, "wlan-disconnect") == 0) {
        result = wlan_disconnect();
    } else if (strcmp(command, "wlan-direct-connect") == 0) {
        if (argc < 4) {
            fprintf(stderr, "Error: wlan-direct-connect requires interface and SSID arguments\n");
            result = 1;
        } else {
            const char *interface = argv[2];
            const char *ssid = argv[3];
            const char *password = (argc >= 5) ? argv[4] : NULL;
            result = wlan_direct_connect(interface, ssid, password);
        }
    } else if (strcmp(command, "dhcp-renew") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: dhcp-renew requires interface argument\n");
            result = 1;
        } else {
            const char *interface = argv[2];
            result = dhcp_renew(interface);
        }
    } else if (strcmp(command, "dhcp-release") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: dhcp-release requires interface argument\n");
            result = 1;
        } else {
            const char *interface = argv[2];
            result = dhcp_release(interface);
        }
    } else if (strcmp(command, "connection-add") == 0) {
        if (argc < 4) {
            fprintf(stderr, "Error: connection-add requires type and name arguments\n");
            result = 1;
        } else {
            const char *type = argv[2];
            const char *name = argv[3];
            const char *device = (argc >= 5) ? argv[4] : NULL;
            result = connection_add(type, name, device);
        }
    } else if (strcmp(command, "connection-delete") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: connection-delete requires name argument\n");
            result = 1;
        } else {
            const char *name = argv[2];
            result = connection_delete(name);
        }
    } else if (strcmp(command, "connection-up") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: connection-up requires name argument\n");
            result = 1;
        } else {
            const char *name = argv[2];
            result = connection_up(name);
        }
    } else if (strcmp(command, "connection-down") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: connection-down requires name argument\n");
            result = 1;
        } else {
            const char *name = argv[2];
            result = connection_down(name);
        }
    } else if (strcmp(command, "interface-enable") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: interface-enable requires device argument\n");
            result = 1;
        } else {
            const char *device = argv[2];
            result = interface_enable(device);
        }
    } else if (strcmp(command, "interface-disable") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Error: interface-disable requires device argument\n");
            result = 1;
        } else {
            const char *device = argv[2];
            result = interface_disable(device);
        }
    } else {
        fprintf(stderr, "Error: Unknown command '%s'\n\n", command);
        usage(argv[0]);
        result = 1;
    }
    
    return result;
}
