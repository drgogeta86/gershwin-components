/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#include <sys/types.h>

@interface ProcessInfo : NSObject
{
    int _pid;
    int _ppid;
    NSString *_user;
    float _cpu;
    float _memory;
    NSString *_command;
    NSString *_state;
    long _virtualMemory;
    long _residentMemory;
    NSString *_tty;
    NSString *_startTime;
    NSString *_cpuTime;
    
    // For CPU calculation
    unsigned long _lastUtime;
    unsigned long _lastStime;
    NSTimeInterval _lastUpdateTime;
}

@property (nonatomic, assign) int pid;
@property (nonatomic, assign) int ppid;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, assign) float cpu;
@property (nonatomic, assign) float memory;
@property (nonatomic, strong) NSString *command;
@property (nonatomic, strong) NSString *state;
@property (nonatomic, assign) long virtualMemory;
@property (nonatomic, assign) long residentMemory;
@property (nonatomic, strong) NSString *tty;
@property (nonatomic, strong) NSString *startTime;
@property (nonatomic, strong) NSString *cpuTime;

- (id)initWithPsLine:(NSString *)line;
- (void)updateCPUAndMemoryWithTotalMemory:(long)totalMemory numCPUs:(int)numCPUs;

@end