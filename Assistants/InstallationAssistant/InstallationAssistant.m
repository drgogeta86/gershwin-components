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
                                            IAInstallProgressDelegate,
                                            IAInstallTypeDelegate>
{
    @public
    IADiskInfo *_selectedDisk;
    NSString *_imageSourcePath;
    IAInstallProgressStep *_progressStep;
    IACompletionStep *_completionStep;
    IAConfirmStep *_confirmStep;
    GSAssistantWindow *_assistantWindow;
}
@end

@implementation InstallationDelegate

- (void)dealloc
{
    [_selectedDisk release];
    [_imageSourcePath release];
    /* _progressStep, _completionStep, _confirmStep, _assistantWindow are not owned */
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

- (void)assistantWindow:(GSAssistantWindow *)window willShowStep:(id<GSAssistantStepProtocol>)step
{
    (void)window;
    /* Update the confirm step with the currently selected disk */
    if (_confirmStep && step == (id<GSAssistantStepProtocol>)_confirmStep) {
        NSLog(@"InstallationDelegate: updating confirm step with disk %@", _selectedDisk.devicePath);
        [_confirmStep updateWithDisk:_selectedDisk];
    }
}

- (void)assistantWindow:(GSAssistantWindow *)window didShowStep:(id<GSAssistantStepProtocol>)step
{
    (void)window;
    /* Auto-start installation when the progress step becomes visible */
    if (_progressStep && step == (id<GSAssistantStepProtocol>)_progressStep) {
        NSLog(@"InstallationDelegate: progress step appeared, starting installation to %@",
              _selectedDisk.devicePath);
        [_progressStep startInstallationToDisk:_selectedDisk source:_imageSourcePath];
    }
}

- (void)diskSelectionStep:(id)step didSelectDisk:(IADiskInfo *)disk {
    (void)step;
    [_selectedDisk release];
    _selectedDisk = [disk retain];
    NSLog(@"InstallationDelegate: disk selected: %@", _selectedDisk.devicePath);
}

- (void)installTypeStep:(id)step didSelectImageSource:(NSString *)imageSourcePath {
    (void)step;
    [_imageSourcePath release];
    _imageSourcePath = [imageSourcePath copy];
    NSLog(@"InstallationDelegate: image source path set to %@", _imageSourcePath ?: @"(none)");
}

- (void)installProgressDidFinish:(BOOL)success {
    NSLog(@"InstallationDelegate: installation finished, success=%d", success);
    if (success) {
        [_completionStep showSuccessWithDisk:_selectedDisk];
    } else {
        [_completionStep showFailureWithMessage:
            NSLocalizedString(@"The installation did not complete successfully. Check the log for details.", @"")];
    }
    /* Enable navigation to move to the completion step */
    if (_assistantWindow) {
        [_assistantWindow updateNavigationButtons];
    }
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
        
        /* Check for image-based installation source before building UI */
        NSString *imageSource = IACheckImageSourceAvailable();
        BOOL imageAvailable = (imageSource != nil && [imageSource length] > 0);
        NSLog(@"Image source available: %@ (%@)", imageAvailable ? @"YES" : @"NO",
              imageSource ?: @"none");
        
        IAWelcomeStep *welcomeStep = [[IAWelcomeStep alloc] init];
        IALicenseStep *licenseStep = [[IALicenseStep alloc] init];
        IAInstallTypeStep *installTypeStep = nil;
        if (imageAvailable) {
            installTypeStep = [[IAInstallTypeStep alloc] init];
            [installTypeStep setDelegate:delegate];
            [installTypeStep setImageSource:imageSource];
        }
        IADiskSelectionStep *diskStep = [[IADiskSelectionStep alloc] init];
        IAConfirmStep *confirmStep = [[IAConfirmStep alloc] init];
        IAInstallProgressStep *progressStep = [[IAInstallProgressStep alloc] init];
        IACompletionStep *completionStep = [[IACompletionStep alloc] init];
        
        [diskStep setDelegate:delegate];
        [progressStep setDelegate:delegate];
        delegate->_progressStep = progressStep;
        delegate->_completionStep = completionStep;
        delegate->_confirmStep = confirmStep;
        
        GSAssistantBuilder *builder = [GSAssistantBuilder builder];
        [builder withTitle:NSLocalizedString(@"Install Operating System", @"")];
        [builder withIcon:[NSImage imageNamed:@"NSComputer"]];
        [builder allowingCancel:YES];
        
        [builder addStep:welcomeStep];
        [builder addStep:licenseStep];
        if (installTypeStep) {
            [builder addStep:installTypeStep];
        }
        [builder addStep:diskStep];
        [builder addStep:confirmStep];
        [builder addStep:progressStep];
        [builder addStep:completionStep];
        
        GSAssistantWindow *assistant = [builder build];
        [assistant setDelegate:delegate];
        delegate->_assistantWindow = assistant;
        [[assistant window] makeKeyAndOrderFront:nil];
        
        [NSApp run];
        
        [appDelegate release];
    }
    return 0;
}
