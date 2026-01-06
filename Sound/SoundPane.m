/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Sound Preference Pane Implementation
 */

#import "SoundPane.h"
#import "SoundController.h"

@implementation SoundPane

- (id)initWithBundle:(NSBundle *)bundle
{
    self = [super initWithBundle:bundle];
    if (self) {
        controller = [[SoundController alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self stopRefreshTimer];
    [controller release];
    [super dealloc];
}

- (void)startRefreshTimer
{
    if (!refreshTimer) {
        NSLog(@"SoundPane: Starting device refresh timer (2 second interval)");
        refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                        target:controller
                                                      selector:@selector(refreshDevices:)
                                                      userInfo:nil
                                                       repeats:YES];
        [refreshTimer retain];
        NSLog(@"SoundPane: Device refresh timer started");
    } else {
        NSLog(@"SoundPane: Refresh timer already running");
    }
}

- (void)stopRefreshTimer
{
    if (refreshTimer) {
        NSLog(@"SoundPane: Stopping device refresh timer");
        [refreshTimer invalidate];
        [refreshTimer release];
        refreshTimer = nil;
        NSLog(@"SoundPane: Device refresh timer stopped");
    }
}

- (NSView *)loadMainView
{
    if (_mainView == nil) {
        _mainView = [[controller createMainView] retain];
    }
    return _mainView;
}

- (NSString *)mainNibName
{
    return nil; // We create the view programmatically
}

- (void)mainViewDidLoad
{
    // Initial data refresh
    [controller refreshDevices:nil];
    [self setInitialKeyView:nil];
}

- (void)didSelect
{
    [super didSelect];
    NSLog(@"SoundPane: didSelect called, starting device refresh timer");
    // Refresh data when the pane is selected
    [controller refreshDevices:nil];
    [controller startInputLevelMonitoring];
    // Start periodic device refresh (every 2 seconds)
    [self startRefreshTimer];
    [self setInitialKeyView:nil];
}

- (void)willUnselect
{
    NSLog(@"SoundPane: willUnselect called");
    [controller stopInputLevelMonitoring];
}

- (void)didUnselect
{
    [super didUnselect];
    [self stopRefreshTimer];
    NSLog(@"SoundPane: didUnselect called");
}

- (NSPreferencePaneUnselectReply)shouldUnselect
{
    NSLog(@"SoundPane: shouldUnselect called, allowing unselect");
    return NSUnselectNow;
}

@end
