/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "BuildApplication.h"
#import "BuildController.h"

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        // Process command line arguments
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        NSString *makefilePath = nil;
        NSMutableArray *extraArgs = [NSMutableArray array];
        if ([args count] > 1) {
            makefilePath = [args objectAtIndex: 1];
            for (NSUInteger i = 2; i < [args count]; i++) {
                [extraArgs addObject: [args objectAtIndex: i]];
            }
        }

        BOOL hasDisplay = (getenv("DISPLAY") != NULL);

        if (!hasDisplay) {
            // Console mode, run build directly without GUI
            if (makefilePath) {
                NSTask *task = [[NSTask alloc] init];
                NSString *dir = [makefilePath stringByDeletingLastPathComponent];
                if ([dir length] == 0) dir = @".";
                [task setCurrentDirectoryPath: dir];
                NSString *gmakePath = @"/usr/bin/gmake";
                [task setLaunchPath: gmakePath];
                NSMutableArray *taskArgs = [NSMutableArray arrayWithObjects: @"-f", makefilePath, nil];
                [taskArgs addObjectsFromArray: extraArgs];
                [task setArguments: taskArgs];
                [task setEnvironment: [[NSProcessInfo processInfo] environment]];
                NSPipe *pipe = [[NSPipe alloc] init];
                [task setStandardOutput: pipe];
                [task setStandardError: pipe];
                NSFileHandle *handle = [pipe fileHandleForReading];
                [task launch];
                // Read and output
                while (1) {
                    NSData *data = [handle availableData];
                    if (data.length == 0) {
                        if ([task isRunning]) {
                            [NSThread sleepForTimeInterval: 0.1];
                        } else {
                            break;
                        }
                    } else {
                        NSString *str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
                        write(STDERR_FILENO, [str UTF8String], [str length]);
                    }
                }
                exit([task terminationStatus]);
            }
        } else {
            // GUI mode
            BuildApplication *app = (BuildApplication *)[BuildApplication sharedApplication];
            [app setDelegate: app];
            [(BuildApplication *)app setMakefilePath: makefilePath];
            [(BuildApplication *)app setExtraArgs: extraArgs];
            [app run];
        }
        return 0;
    }
}