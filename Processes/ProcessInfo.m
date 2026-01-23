/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "ProcessInfo.h"
#ifndef __linux__
#include <sys/sysctl.h>
#endif
#include <unistd.h>

@implementation ProcessInfo

@synthesize pid = _pid;
@synthesize ppid = _ppid;
@synthesize user = _user;
@synthesize cpu = _cpu;
@synthesize memory = _memory;
@synthesize command = _command;
@synthesize state = _state;
@synthesize virtualMemory = _virtualMemory;
@synthesize residentMemory = _residentMemory;
@synthesize tty = _tty;
@synthesize startTime = _startTime;
@synthesize cpuTime = _cpuTime;

- (id)initWithPsLine:(NSString *)line
{
    self = [super init];
    if (self) {
        // Parse ps aux output: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
        NSArray *components = [line componentsSeparatedByString:@" "];
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *comp in components) {
            if ([comp length] > 0) {
                [filtered addObject:comp];
            }
        }
        if ([filtered count] >= 11) {
            _user = [filtered objectAtIndex:0];
            _pid = [[filtered objectAtIndex:1] intValue];
            _cpu = [[filtered objectAtIndex:2] floatValue];
            _memory = [[filtered objectAtIndex:3] floatValue];
            _virtualMemory = [[filtered objectAtIndex:4] longLongValue];
            _residentMemory = [[filtered objectAtIndex:5] longLongValue];
            _tty = [filtered objectAtIndex:6];
            _state = [filtered objectAtIndex:7];
            _startTime = [filtered objectAtIndex:8];
            _cpuTime = [filtered objectAtIndex:9];
            // Command starts from index 10
            NSRange range = NSMakeRange(10, [filtered count] - 10);
            _command = [[filtered subarrayWithRange:range] componentsJoinedByString:@" "];
        }
        _lastUpdateTime = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (void)updateCPUAndMemoryWithTotalMemory:(long)totalMemory numCPUs:(int)numCPUs
{
    // Update CPU percentage from /proc/[pid]/stat on Linux or via sysctl on BSD
#ifdef __linux__
    unsigned long utime = 0, stime = 0;
#else
    (void)0;
#endif
    
#ifdef __linux__
    // Linux: Read from /proc/[pid]/stat
    char statPath[256];
    snprintf(statPath, sizeof(statPath), "/proc/%d/stat", _pid);
    FILE *statFile = fopen(statPath, "r");
    if (statFile) {
        char comm[256];
        char state;
        int ppid, pgrp, session, tty_nr, tpgid;
        unsigned int flags;
        unsigned long minflt, cminflt, majflt, cmajflt;
        
        // Parse: pid (comm) state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime ...
        int fields = fscanf(statFile, "%*d (%[^)]) %c %d %d %d %d %d %u %lu %lu %lu %lu %lu %lu",
                           comm, &state, &ppid, &pgrp, &session, &tty_nr, &tpgid,
                           &flags, &minflt, &cminflt, &majflt, &cmajflt, &utime, &stime);
        
        if (fields >= 14) {
            NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval deltaTime = currentTime - _lastUpdateTime;
            
            if (deltaTime > 0 && _lastUpdateTime > 0) {
                // Calculate CPU percentage
                // utime and stime are in clock ticks, need to convert to seconds
                long ticksPerSecond = sysconf(_SC_CLK_TCK);
                double deltaUtime = (double)(utime - _lastUtime) / ticksPerSecond;
                double deltaStime = (double)(stime - _lastStime) / ticksPerSecond;
                double deltaCPU = deltaUtime + deltaStime;
                
                // CPU percentage = (CPU time / elapsed time) * 100 * num_CPUs
                // We use num_CPUs to account for multi-core systems
                _cpu = (float)((deltaCPU / deltaTime) * 100.0);
                
                // Cap at reasonable maximum (numCPUs * 100)
                if (_cpu > (100.0 * numCPUs)) {
                    _cpu = 100.0 * numCPUs;
                }
            } else if (_lastUpdateTime == 0) {
                // First update - just initialize
                _cpu = 0.0;
            }
            
            _lastUtime = utime;
            _lastStime = stime;
            _lastUpdateTime = currentTime;
        }
        fclose(statFile);
    }
    
    // Read memory info from /proc/[pid]/status for more accurate RSS
    char statusPath[256];
    snprintf(statusPath, sizeof(statusPath), "/proc/%d/status", _pid);
    FILE *statusFile = fopen(statusPath, "r");
    if (statusFile) {
        char line[256];
        while (fgets(line, sizeof(line), statusFile)) {
            if (strncmp(line, "VmRSS:", 6) == 0) {
                long rss_kb = 0;
                sscanf(line, "VmRSS: %ld", &rss_kb);
                _residentMemory = rss_kb; // Already in KB
                
                // Calculate memory percentage
                if (totalMemory > 0) {
                    _memory = (float)(rss_kb * 100.0 / totalMemory);
                }
                break;
            }
        }
        fclose(statusFile);
    }
    
#else
    // BSD: Use sysctl and libutil (or kqueue)
    // For simplicity, we'll read from /proc if available (some BSD systems have /proc)
    // Otherwise we'd need to use more complex BSD APIs
    
    // Try to read CPU time from /proc if available
    char statPath[256];
    snprintf(statPath, sizeof(statPath), "/proc/%d/stat", _pid);
    FILE *statFile = fopen(statPath, "r");
    if (statFile) {
        // BSD /proc format is different but we can try
        char line[1024];
        while (fgets(line, sizeof(line), statFile)) {
            if (strncmp(line, "  Runtime", 9) == 0) {
                // Runtime in microseconds
                unsigned long runtime_us;
                sscanf(line, "  Runtime %lu us", &runtime_us);
                
                NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
                NSTimeInterval deltaTime = currentTime - _lastUpdateTime;
                
                if (deltaTime > 0 && _lastUpdateTime > 0) {
                    double deltaCPU = (double)runtime_us / 1000000.0; // Convert to seconds
                    _cpu = (float)((deltaCPU / deltaTime) * 100.0 * numCPUs);
                    
                    if (_cpu > (100.0 * numCPUs)) {
                        _cpu = 100.0 * numCPUs;
                    }
                }
                _lastUpdateTime = currentTime;
                break;
            }
        }
        fclose(statFile);
    }
    
    // For BSD memory: try sysctl or /proc/[pid]/status
    char statusPath[256];
    snprintf(statusPath, sizeof(statusPath), "/proc/%d/status", _pid);
    FILE *statusFile = fopen(statusPath, "r");
    if (statusFile) {
        char line[256];
        while (fgets(line, sizeof(line), statusFile)) {
            if (strncmp(line, "VmRSS:", 6) == 0) {
                long rss_kb = 0;
                sscanf(line, "VmRSS: %ld", &rss_kb);
                _residentMemory = rss_kb;
                
                if (totalMemory > 0) {
                    _memory = (float)(rss_kb * 100.0 / totalMemory);
                }
                break;
            }
        }
        fclose(statusFile);
    }
#endif
    
    // Ensure reasonable values
    if (_cpu < 0) _cpu = 0;
    if (_memory < 0) _memory = 0;
}



@end