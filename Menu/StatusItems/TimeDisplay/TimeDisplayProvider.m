/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "TimeDisplayProvider.h"

@implementation TimeDisplayProvider

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.currentTitle = @"--:--";
    }
    return self;
}

- (NSString *)identifier
{
    return @"org.gershwin.menu.statusitem.time";
}

- (NSString *)title
{
    return self.currentTitle;
}

- (CGFloat)width
{
    // Fixed width for time display
    return 60.0;
}

- (NSInteger)displayPriority
{
    // Highest priority - appears at far right
    return 1000;
}

- (NSTimeInterval)updateInterval
{
    return 1.0; // Update every second
}

- (void)loadWithManager:(id)manager
{
    NSLog(@"TimeDisplayProvider: Loading time display");
    self.manager = manager;
    
    // Create time formatter
    self.timeFormatter = [[NSDateFormatter alloc] init];
    [self.timeFormatter setDateFormat:@"HH:mm"];
    
    // Initial update
    [self update];
}

- (void)update
{
    // Always show time (no date toggle)
    [self updateTime];
}

- (void)handleClick
{
    // Click handler not needed - menu will be shown automatically
}

- (NSMenu *)menu
{
    // No menu - just show the time
    return nil;
}

- (void)unload
{
    NSLog(@"TimeDisplayProvider: Unloading");
    
    self.timeFormatter = nil;
}

#pragma mark - Time/Date Display

- (void)updateTime
{
    NSDate *now = [NSDate date];
    NSString *timeString = [self.timeFormatter stringFromDate:now];
    self.currentTitle = timeString;
}

@end
