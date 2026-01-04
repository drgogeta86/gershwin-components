/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "MenuApplication.h"
#import "MenuController.h"
#import <signal.h>
#import <sys/types.h>
#import <unistd.h>
#import <dirent.h>

// Function to resolve a symlink to its actual path
static NSString *resolveSymlink(NSString *linkPath) {
    char buffer[PATH_MAX];
    ssize_t len = readlink([linkPath fileSystemRepresentation], buffer, sizeof(buffer) - 1);
    if (len != -1) {
        buffer[len] = '\0';
        return [NSString stringWithUTF8String:buffer];
    }
    return nil;
}

// Function to kill any other instances of this application
static void killOtherInstances(void) {
    // Get the path to the current executable
    NSString *currentPath = [[NSBundle mainBundle] executablePath];
    if (!currentPath) {
        NSLog(@"Menu.app: Warning - could not determine executable path");
        return;
    }
    
    pid_t currentPID = getpid();
    
    // Resolve the current executable path to its real path
    NSString *currentRealPath = realpath([currentPath fileSystemRepresentation], NULL) ?
        [NSString stringWithUTF8String:realpath([currentPath fileSystemRepresentation], NULL)] :
        currentPath;
    
    NSLog(@"Menu.app: Current executable: %@ (real: %@)", currentPath, currentRealPath);
    
    // Scan /proc filesystem for other instances (works on Linux and BSD with /proc)
    DIR *procDir = opendir("/proc");
    if (!procDir) {
        NSLog(@"Menu.app: Warning - could not open /proc directory");
        return;
    }
    
    struct dirent *entry;
    while ((entry = readdir(procDir)) != NULL) {
        // Skip non-numeric entries and . and ..
        if (entry->d_name[0] < '0' || entry->d_name[0] > '9') {
            continue;
        }
        
        pid_t otherPID = (pid_t)strtol(entry->d_name, NULL, 10);
        if (otherPID <= 0 || otherPID == currentPID) {
            continue;
        }
        
        // Try to read the exe link (works on Linux and some BSDs)
        NSString *exePath = [NSString stringWithFormat:@"/proc/%d/exe", otherPID];
        NSString *linkedPath = resolveSymlink(exePath);
        
        // If exe link doesn't work, try file link (some BSDs)
        if (!linkedPath) {
            exePath = [NSString stringWithFormat:@"/proc/%d/file", otherPID];
            linkedPath = resolveSymlink(exePath);
        }
        
        if (!linkedPath) {
            continue;
        }
        
        // Resolve the found process's executable to real path for comparison
        NSString *otherRealPath = realpath([linkedPath fileSystemRepresentation], NULL) ?
            [NSString stringWithUTF8String:realpath([linkedPath fileSystemRepresentation], NULL)] :
            linkedPath;
        
        // Compare the executable paths
        if ([otherRealPath isEqualToString:currentRealPath]) {
            NSLog(@"Menu.app: Killing other instance with PID %d", otherPID);
            kill(otherPID, SIGTERM);
            // Give it a moment to terminate gracefully
            usleep(100000); // 100ms
            // Force kill if still running
            kill(otherPID, SIGKILL);
        }
    }
    
    closedir(procDir);
}

int main(int __attribute__((unused)) argc, const char * __attribute__((unused)) argv[])
{
    NSLog(@"Menu.app: Starting application initialization...");
    
    // Kill any other instances of Menu.app before proceeding
    killOtherInstances();
    
    @autoreleasepool {
        @try {
            // Create MenuApplication directly as the main application instance
            MenuApplication *app = [[MenuApplication alloc] init];
            
            // Set it as the shared application instance manually
            NSApp = app;
            
            NSLog(@"Menu.app: About to start main run loop...");
            
            // Run the application with better exception handling
            @try {
                [app run];
            } @catch (NSException *runException) {
                NSLog(@"Menu.app: Exception in run loop: %@", runException);
                NSLog(@"Menu.app: Run loop exception reason: %@", [runException reason]);
            }
            
            NSLog(@"Menu.app: Main run loop exited normally");
        } @catch (NSException *exception) {
            NSLog(@"Menu.app: Caught exception in main: %@", exception);
            NSLog(@"Menu.app: Exception reason: %@", [exception reason]);
            NSLog(@"Menu.app: Exception stack: %@", [exception callStackSymbols]);
            return 1;
        }
    }
    
    NSLog(@"Menu.app: Application exiting normally");
    return 0;
}
