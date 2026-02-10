/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GSAssistantFramework.h>
#import "InstallationSteps.h"

@interface InstallationAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation InstallationAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}
@end

@interface InstallationDelegate : NSObject <GSAssistantWindowDelegate,
                                            IADiskSelectionDelegate,
                                            IAInstallProgressDelegate>
{
    @public
    IADiskInfo *_selectedDisk;
}
@end

@implementation InstallationDelegate

- (void)dealloc
{
    [_selectedDisk release];
    [super dealloc];
}

- (void)assistantWindowDidFinish:(GSAssistantWindow *)window {
    (void)window;
    [NSApp terminate:nil];
}

- (BOOL)assistantWindow:(GSAssistantWindow *)window shouldCancelWithConfirmation:(BOOL)showConfirmation {
    (void)window;
    if (showConfirmation) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:NSLocalizedString(@"Cancel Installation?", @"")];
        [alert setInformativeText:NSLocalizedString(@"Are you sure you want to cancel?", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Continue", @"")];
        [alert setAlertStyle:NSWarningAlertStyle];
        NSModalResponse response = [alert runModal];
        [alert release];
        return response == NSAlertFirstButtonReturn;
    }
    return YES;
}

- (void)diskSelectionStep:(id)step didSelectDisk:(IADiskInfo *)disk {
    (void)step;
    [_selectedDisk release];
    _selectedDisk = [disk retain];
}

- (void)installProgressDidFinish:(BOOL)success {
    (void)success;
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        [NSApplication sharedApplication];
        
        InstallationAppDelegate *appDelegate = [[InstallationAppDelegate alloc] init];
        [NSApp setDelegate:appDelegate];
        
        NSMenu *mainMenu = [[NSMenu alloc] init];
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
        [mainMenu addItem:appMenuItem];
        [NSApp setMainMenu:mainMenu];
        
        NSMenu *appMenu = [[NSMenu alloc] init];
        NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
        [appMenu addItem:quitMenuItem];
        [appMenuItem setSubmenu:appMenu];
        
        InstallationDelegate *delegate = [[InstallationDelegate alloc] init];
        
        IAWelcomeStep *welcomeStep = [[IAWelcomeStep alloc] init];
        IALicenseStep *licenseStep = [[IALicenseStep alloc] init];
        IADiskSelectionStep *diskStep = [[IADiskSelectionStep alloc] init];
        IAConfirmStep *confirmStep = [[IAConfirmStep alloc] init];
        IAInstallProgressStep *progressStep = [[IAInstallProgressStep alloc] init];
        IACompletionStep *completionStep = [[IACompletionStep alloc] init];
        
        [diskStep setDelegate:delegate];
        [progressStep setDelegate:delegate];
        
        GSAssistantBuilder *builder = [GSAssistantBuilder builder];
        [builder withTitle:NSLocalizedString(@"Install Operating System", @"")];
        [builder withIcon:[NSImage imageNamed:@"NSComputer"]];
        [builder allowingCancel:YES];
        
        [builder addStep:welcomeStep];
        [builder addStep:licenseStep];
        [builder addStep:diskStep];
        [builder addStep:confirmStep];
        [builder addStep:progressStep];
        [builder addStep:completionStep];
        
        GSAssistantWindow *assistant = [builder build];
        [assistant setDelegate:delegate];
        [[assistant window] makeKeyAndOrderFront:nil];
        
        [NSApp run];
        
        [appDelegate release];
    }
    return 0;
}
