/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */


//
// InstallationSteps.m
// Installation Assistant - Custom Step Classes
//

#import "InstallationSteps.h"

#import <sys/utsname.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

// ============================================================================
// Helper: Detect whether the real kernel is FreeBSD (even under Linux compat)
// ============================================================================
static BOOL IAIsFreeBSD(void)
{
    struct utsname u;
    if (uname(&u) == 0 && strcmp(u.sysname, "FreeBSD") == 0) {
        return YES;
    }
    /* uname may report "Linux" under FreeBSD Linux compatibility layer.
     * Detect real FreeBSD by checking for freebsd-version or /etc/rc.conf
     * combined with sysctl kern.ostype. */
    if (access("/bin/freebsd-version", X_OK) == 0) {
        NSLog(@"IAIsFreeBSD: detected FreeBSD via /bin/freebsd-version");
        return YES;
    }
    if (access("/etc/rc.conf", R_OK) == 0 && access("/sbin/sysctl", X_OK) == 0) {
        /* Double check with sysctl kern.ostype */
        FILE *fp = popen("sysctl -n kern.ostype 2>/dev/null", "r");
        if (fp) {
            char buf[64] = {0};
            if (fgets(buf, sizeof(buf), fp) != NULL) {
                /* Strip trailing newline */
                char *nl = strchr(buf, '\n');
                if (nl) *nl = '\0';
                if (strcmp(buf, "FreeBSD") == 0) {
                    pclose(fp);
                    NSLog(@"IAIsFreeBSD: detected FreeBSD via sysctl kern.ostype");
                    return YES;
                }
            }
            pclose(fp);
        }
    }
    return NO;
}

// ============================================================================
// Helper: Determine installer script path from app bundle
// ============================================================================
NSString *IAInstallerScriptPath(void)
{
    NSString *scriptName = IAIsFreeBSD() ? @"installer-FreeBSD" : @"installer-Linux";
    NSLog(@"IAInstallerScriptPath: selected script %@", scriptName);

    NSString *path = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"sh"];
    if (!path) {
        NSLog(@"IAInstallerScriptPath: script %@.sh not found in bundle, searching in Resources/", scriptName);
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        path = [bundlePath stringByAppendingPathComponent:
                [NSString stringWithFormat:@"Resources/%@.sh", scriptName]];
    }
    NSLog(@"IAInstallerScriptPath: using script at %@", path);
    return path;
}

// ============================================================================
// Helper: Synchronously check for image source availability
// Returns the mount path of the image source, or nil if none found.
// ============================================================================
NSString *IACheckImageSourceAvailable(void)
{
    NSString *scriptPath = IAInstallerScriptPath();
    NSLog(@"IACheckImageSourceAvailable: running %@ --check-image-source", scriptPath);

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:scriptPath];
    [task setArguments:@[@"--check-image-source"]];

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];

    NSString *result = nil;
    @try {
        [task launch];
        NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];

        NSString *outStr = outData ? [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] autorelease] : @"";
        NSLog(@"IACheckImageSourceAvailable: script output: %@", outStr);

        NSArray *lines = [outStr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in lines) {
            if ([line hasPrefix:@"IMAGE_SOURCE:"]) {
                NSString *src = [line substringFromIndex:[@"IMAGE_SOURCE:" length]];
                src = [src stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([src length] > 0) {
                    result = src;
                }
                break;
            }
        }
    } @catch (NSException *ex) {
        NSLog(@"IACheckImageSourceAvailable: exception: %@", ex);
    }
    [task release];

    NSLog(@"IACheckImageSourceAvailable: result = %@", result ?: @"(none)");
    return result;
}

@implementation IADiskInfo
@synthesize devicePath, name, diskDescription, sizeBytes, formattedSize;
@end

@implementation IALicenseStep

@synthesize stepTitle, stepDescription;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = @"License Agreement";
        self.stepDescription = @"Please read and accept the software license";
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [stepTitle release];
    [stepDescription release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 250)];
    
    // License text view with scroll
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 50, 360, 180)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setBorderType:NSBezelBorder];
    
    _licenseTextView = [[NSTextView alloc] init];
    [_licenseTextView setEditable:NO];
    [_licenseTextView setString:@"BSD 2-Clause License\n\nCopyright (c) 2023, Gershwin Project\nAll rights reserved.\n\nRedistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:\n\n1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.\n\n2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.\n\nTHIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."];
    
    [scrollView setDocumentView:_licenseTextView];
    [_stepView addSubview:scrollView];
    [scrollView release];
    
    // Agreement checkbox
    _agreeCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(24, 20, 350, 20)];
    [_agreeCheckbox setButtonType:NSSwitchButton];
    [_agreeCheckbox setTitle:@"I agree to the terms and conditions of this license"];
    [_agreeCheckbox setState:NSOffState];
    [_agreeCheckbox setTarget:self];
    [_agreeCheckbox setAction:@selector(checkboxChanged:)];
    [_stepView addSubview:_agreeCheckbox];
}

- (void)checkboxChanged:(id)sender
{
    [self requestNavigationUpdate];
}

- (void)requestNavigationUpdate
{
    NSWindow *window = [[self stepView] window];
    if (!window) {
        window = [NSApp keyWindow];
    }
    NSWindowController *wc = [window windowController];
    if ([wc isKindOfClass:[GSAssistantWindow class]]) {
        GSAssistantWindow *assistantWindow = (GSAssistantWindow *)wc;
        [assistantWindow updateNavigationButtons];
    }
}

- (NSView *)stepView
{
    return _stepView;
}

- (BOOL)canContinue
{
    return ([_agreeCheckbox state] == NSOnState);
}

- (BOOL)userAgreedToLicense
{
    return ([_agreeCheckbox state] == NSOnState);
}

@end

@implementation IADestinationStep

@synthesize stepTitle, stepDescription;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = @"Installation Location";
        self.stepDescription = @"Choose where to install the software";
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [stepTitle release];
    [stepDescription release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];
    
    // Destination selection
    NSTextField *destinationLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 160, 150, 20)];
    [destinationLabel setStringValue:NSLocalizedString(@"Install to:", @"")];
    [destinationLabel setBezeled:NO];
    [destinationLabel setDrawsBackground:NO];
    [destinationLabel setEditable:NO];
    [destinationLabel setSelectable:NO];
    [_stepView addSubview:destinationLabel];
    [destinationLabel release];
    
    _destinationPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, 130, 300, 24)];
    [_destinationPopup addItemWithTitle:@"/usr/local"];
    [_destinationPopup addItemWithTitle:@"/opt/gershwin"];
    [_destinationPopup addItemWithTitle:NSLocalizedString(@"Choose...", @"")];
    [_stepView addSubview:_destinationPopup];
    
    // Space requirements
    _spaceRequiredLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 90, 350, 20)];
    [_spaceRequiredLabel setStringValue:NSLocalizedString(@"Space required: 2.5 GB", @"")];
    [_spaceRequiredLabel setBezeled:NO];
    [_spaceRequiredLabel setDrawsBackground:NO];
    [_spaceRequiredLabel setEditable:NO];
    [_spaceRequiredLabel setSelectable:NO];
    [_stepView addSubview:_spaceRequiredLabel];
    
    _spaceAvailableLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 70, 350, 20)];
    [_spaceAvailableLabel setStringValue:NSLocalizedString(@"Space available: 15.2 GB", @"")];
    [_spaceAvailableLabel setBezeled:NO];
    [_spaceAvailableLabel setDrawsBackground:NO];
    [_spaceAvailableLabel setEditable:NO];
    [_spaceAvailableLabel setSelectable:NO];
    [_stepView addSubview:_spaceAvailableLabel];
}

- (NSView *)stepView
{
    return _stepView;
}

- (BOOL)canContinue
{
    // Always can continue - a destination is pre-selected
    return YES;
}

- (NSString *)selectedDestination
{
    return [_destinationPopup titleOfSelectedItem];
}

@end

@implementation IAOptionsStep

@synthesize stepTitle, stepDescription;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = @"Installation Options";
        self.stepDescription = @"Select components to install";
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [stepTitle release];
    [stepDescription release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];
    
    NSTextField *optionsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 170, 350, 20)];
    [optionsLabel setStringValue:NSLocalizedString(@"Choose optional components to install:", @"")];
    [optionsLabel setBezeled:NO];
    [optionsLabel setDrawsBackground:NO];
    [optionsLabel setEditable:NO];
    [optionsLabel setSelectable:NO];
    [_stepView addSubview:optionsLabel];
    [optionsLabel release];
    
    // Development Tools checkbox
    _installDevelopmentToolsCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 140, 350, 20)];
    [_installDevelopmentToolsCheckbox setButtonType:NSSwitchButton];
    [_installDevelopmentToolsCheckbox setTitle:@"Development Tools (GCC, Make, etc.)"];
    [_installDevelopmentToolsCheckbox setState:NSOnState]; // Default to checked
    [_stepView addSubview:_installDevelopmentToolsCheckbox];
    
    // Linux Compatibility checkbox
    _installLinuxCompatibilityCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 110, 350, 20)];
    [_installLinuxCompatibilityCheckbox setButtonType:NSSwitchButton];
    [_installLinuxCompatibilityCheckbox setTitle:@"Linux Compatibility Layer"];
    [_installLinuxCompatibilityCheckbox setState:NSOnState]; // Default to checked
    [_stepView addSubview:_installLinuxCompatibilityCheckbox];
    
    // Documentation checkbox
    _installDocumentationCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 80, 350, 20)];
    [_installDocumentationCheckbox setButtonType:NSSwitchButton];
    [_installDocumentationCheckbox setTitle:@"Documentation and Examples"];
    [_installDocumentationCheckbox setState:NSOnState]; // Default to checked
    [_stepView addSubview:_installDocumentationCheckbox];
}

- (NSView *)stepView
{
    return _stepView;
}

- (BOOL)canContinue
{
    // Always can continue - at least core components will be installed
    return YES;
}

- (BOOL)installDevelopmentTools
{
    return ([_installDevelopmentToolsCheckbox state] == NSOnState);
}

- (BOOL)installLinuxCompatibility
{
    return ([_installLinuxCompatibilityCheckbox state] == NSOnState);
}

- (BOOL)installDocumentation
{
    return ([_installDocumentationCheckbox state] == NSOnState);
}

@end

// ============================================================================
// IAWelcomeStep - simple welcome screen
// ============================================================================

@implementation IAWelcomeStep

@synthesize stepTitle, stepDescription;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = NSLocalizedString(@"Welcome", @"");
        self.stepDescription = NSLocalizedString(@"Welcome to the installer", @"");
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [stepTitle release];
    [stepDescription release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];

    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 140, 360, 40)];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setStringValue:NSLocalizedString(@"This assistant will guide you through installing the operating system.", @"")];
    [[label cell] setWraps:YES];
    [label setFont:[NSFont systemFontOfSize:12]];
    [_stepView addSubview:label];
    [label release];
}

- (NSView *)stepView
{
    return _stepView;
}

- (NSString *)stepTitle { return stepTitle; }
- (NSString *)stepDescription { return stepDescription; }
- (BOOL)canContinue { return YES; }

@end

// ============================================================================
// IAInstallTypeStep - Choose clone vs image-based installation
// ============================================================================

@implementation IAInstallTypeStep

@synthesize stepTitle, stepDescription, delegate;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = NSLocalizedString(@"Installation Type", @"");
        self.stepDescription = NSLocalizedString(@"Choose how to install the system", @"");
        _detectedImageSource = nil;
        _imageSourceAvailable = NO;
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [stepTitle release];
    [stepDescription release];
    [_detectedImageSource release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];

    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 160, 360, 20)];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setStringValue:NSLocalizedString(@"Choose the installation method:", @"")];
    [_stepView addSubview:label];
    [label release];

    _cloneRadio = [[NSButton alloc] initWithFrame:NSMakeRect(20, 126, 360, 24)];
    [_cloneRadio setButtonType:NSRadioButton];
    [_cloneRadio setTitle:NSLocalizedString(@"Clone running system to disk", @"")];
    [_cloneRadio setState:NSOnState];
    [_cloneRadio setTarget:self];
    [_cloneRadio setAction:@selector(radioChanged:)];
    [_stepView addSubview:_cloneRadio];

    _imageRadio = [[NSButton alloc] initWithFrame:NSMakeRect(20, 90, 360, 24)];
    [_imageRadio setButtonType:NSRadioButton];
    [_imageRadio setTitle:NSLocalizedString(@"Image based installation (from external media)", @"")];
    [_imageRadio setState:NSOffState];
    [_imageRadio setEnabled:NO];
    [_imageRadio setTarget:self];
    [_imageRadio setAction:@selector(radioChanged:)];
    [_stepView addSubview:_imageRadio];

    _imageSourceLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(40, 62, 340, 20)];
    [_imageSourceLabel setBezeled:NO];
    [_imageSourceLabel setDrawsBackground:NO];
    [_imageSourceLabel setEditable:NO];
    [_imageSourceLabel setSelectable:NO];
    [_imageSourceLabel setTextColor:[NSColor grayColor]];
    [_imageSourceLabel setStringValue:NSLocalizedString(@"No installation media detected", @"")];
    [_stepView addSubview:_imageSourceLabel];
}

- (void)radioChanged:(id)sender
{
    if (sender == _cloneRadio) {
        [_cloneRadio setState:NSOnState];
        [_imageRadio setState:NSOffState];
    } else if (sender == _imageRadio) {
        [_imageRadio setState:NSOnState];
        [_cloneRadio setState:NSOffState];
    }
    if (delegate && [delegate respondsToSelector:@selector(installTypeStep:didSelectImageSource:)]) {
        [delegate installTypeStep:self didSelectImageSource:[self useImageInstall] ? _detectedImageSource : nil];
    }
}

- (void)detectImageSource
{
    /* Called externally if the caller already knows the image source path.
     * Alternatively runs the check script to detect it. */
    NSString *source = IACheckImageSourceAvailable();
    if (source && [source length] > 0) {
        [_detectedImageSource release];
        _detectedImageSource = [source copy];
        _imageSourceAvailable = YES;
        [_imageRadio setEnabled:YES];
        [_imageSourceLabel setStringValue:[NSString stringWithFormat:
            NSLocalizedString(@"Image source detected: %@", @""), _detectedImageSource]];
        [_imageSourceLabel setTextColor:[NSColor controlTextColor]];
        NSLog(@"IAInstallTypeStep: image source available at %@", _detectedImageSource);
    } else {
        _imageSourceAvailable = NO;
        [_imageRadio setEnabled:NO];
        [_imageSourceLabel setStringValue:NSLocalizedString(@"No installation media detected", @"")];
        [_imageSourceLabel setTextColor:[NSColor grayColor]];
        NSLog(@"IAInstallTypeStep: no image source available");
    }
}

- (void)setImageSource:(NSString *)sourcePath
{
    [_detectedImageSource release];
    _detectedImageSource = [sourcePath copy];
    if (_detectedImageSource && [_detectedImageSource length] > 0) {
        _imageSourceAvailable = YES;
        [_imageRadio setEnabled:YES];
        [_imageSourceLabel setStringValue:[NSString stringWithFormat:
            NSLocalizedString(@"Image source detected: %@", @""), _detectedImageSource]];
        [_imageSourceLabel setTextColor:[NSColor controlTextColor]];
    }
}

- (BOOL)useImageInstall
{
    return (_imageSourceAvailable && [_imageRadio state] == NSOnState);
}

- (NSString *)imageSourcePath
{
    if ([self useImageInstall]) {
        return _detectedImageSource;
    }
    return nil;
}

- (NSView *)stepView { return _stepView; }
- (NSString *)stepTitle { return stepTitle; }
- (NSString *)stepDescription { return stepDescription; }
- (BOOL)canContinue { return YES; }

@end

// ============================================================================
// IADiskSelectionStep - enumerates disks using external installer scripts
// ============================================================================

@implementation IADiskSelectionStep

@synthesize stepTitle, stepDescription, delegate;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = NSLocalizedString(@"Select Destination Disk", @"");
        self.stepDescription = NSLocalizedString(@"Choose a physical disk to install to", @"");
        _disks = [[NSMutableArray alloc] init];
        _diagnostics = [[NSMutableString alloc] init];
        [self setupView];
        /* Use performSelector:afterDelay: instead of dispatch_after on main queue
         * because GCD main queue is not integrated with the GNUstep NSRunLoop. */
        [self performSelector:@selector(refreshDiskList) withObject:nil afterDelay:0.5];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_stepView release];
    [_tableView release];
    [_disks release];
    [_statusLabel release];
    [_spinner release];
    [_detailsButton release];
    [_diagnostics release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 240)];

    _statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 200, 360, 20)];
    [_statusLabel setBezeled:NO];
    [_statusLabel setDrawsBackground:NO];
    [_statusLabel setEditable:NO];
    [_statusLabel setSelectable:NO];
    [_statusLabel setStringValue:NSLocalizedString(@"Scanning for disks...", @"")];
    [_stepView addSubview:_statusLabel];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 60, 360, 130)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];

    _tableView = [[NSTableView alloc] initWithFrame:[[scrollView contentView] frame]];
    NSTableColumn *col1 = [[NSTableColumn alloc] initWithIdentifier:@"devicePath"]; [[col1 headerCell] setStringValue:NSLocalizedString(@"Device", @"")]; [col1 setWidth:120]; [_tableView addTableColumn:col1]; [col1 release];
    NSTableColumn *col2 = [[NSTableColumn alloc] initWithIdentifier:@"name"]; [[col2 headerCell] setStringValue:NSLocalizedString(@"Name", @"")]; [col2 setWidth:160]; [_tableView addTableColumn:col2]; [col2 release];
    NSTableColumn *col3 = [[NSTableColumn alloc] initWithIdentifier:@"formattedSize"]; [[col3 headerCell] setStringValue:NSLocalizedString(@"Size", @"")]; [col3 setWidth:70]; [_tableView addTableColumn:col3]; [col3 release];

    [_tableView setDelegate:(id<NSTableViewDelegate>)self];
    [_tableView setDataSource:(id<NSTableViewDataSource>)self];
    [scrollView setDocumentView:_tableView];
    [_stepView addSubview:scrollView];
    [scrollView release];

    _detailsButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 20, 80, 24)];
    [_detailsButton setTitle:NSLocalizedString(@"Details", @"")];
    [_detailsButton setTarget:self];
    [_detailsButton setAction:@selector(showDiagnostics:)];
    [_stepView addSubview:_detailsButton];

    _spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(110, 20, 16, 16)];
    [_spinner setStyle:NSProgressIndicatorSpinningStyle];
    [_spinner startAnimation:nil];
    [_stepView addSubview:_spinner];
}

- (void)refreshDiskList
{
    NSLog(@"IADiskSelectionStep: refreshDiskList");
    [_diagnostics setString:@""];
    [_statusLabel setStringValue:NSLocalizedString(@"Scanning for disks...", @"")];
    [_spinner startAnimation:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *scriptPath = IAInstallerScriptPath();
        NSLog(@"IADiskSelectionStep: using script %@", scriptPath);
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:scriptPath];
        [task setArguments:@[@"--list-disks", @"--debug"]];

        NSPipe *outPipe = [NSPipe pipe];
        NSPipe *errPipe = [NSPipe pipe];
        [task setStandardOutput:outPipe];
        [task setStandardError:errPipe];

        @try {
            [task launch];
        } @catch (NSException *ex) {
            NSDictionary *info = @{@"error": [NSString stringWithFormat:@"Exception launching script: %@", ex]};
            [self performSelectorOnMainThread:@selector(_diskScanFailed:) withObject:info waitUntilDone:NO];
            [task release];
            return;
        }

        NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
        NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        int term = [task terminationStatus];

        NSString *outStr = outData ? [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] autorelease] : @"";
        NSString *errStr = errData ? [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease] : @"";

        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        [result setObject:(outStr ?: @"") forKey:@"stdout"];
        [result setObject:(errStr ?: @"") forKey:@"stderr"];
        [result setObject:[NSNumber numberWithInt:term] forKey:@"exitCode"];
        if (outData) [result setObject:outData forKey:@"outData"];
        [self performSelectorOnMainThread:@selector(_diskScanCompleted:) withObject:result waitUntilDone:NO];

        [task release];
    });
}

/* Main-thread callback: disk scan failed to launch */
- (void)_diskScanFailed:(NSDictionary *)info
{
    [_spinner stopAnimation:nil];
    [_statusLabel setStringValue:NSLocalizedString(@"Failed to start disk enumeration script", @"")];
    [_diagnostics appendFormat:@"%@\n", [info objectForKey:@"error"]];
}

/* Main-thread callback: disk scan completed (possibly with errors) */
- (void)_diskScanCompleted:(NSDictionary *)info
{
    [_spinner stopAnimation:nil];

    NSString *outStr = [info objectForKey:@"stdout"];
    NSString *errStr = [info objectForKey:@"stderr"];
    NSData *outData = [info objectForKey:@"outData"];
    int term = [[info objectForKey:@"exitCode"] intValue];

    if (outStr && [outStr length] > 0 && outData) {
        NSError *jsonError = nil;
        id obj = nil;
        @try {
            obj = [NSJSONSerialization JSONObjectWithData:outData options:0 error:&jsonError];
        } @catch (NSException *ex) {
            obj = nil;
            [_diagnostics appendFormat:@"JSON parse exception: %@\n", ex];
        }

        if (obj && [obj isKindOfClass:[NSArray class]]) {
            [_disks removeAllObjects];
            for (NSDictionary *d in obj) {
                IADiskInfo *disk = [[IADiskInfo alloc] init];
                disk.devicePath = [d objectForKey:@"devicePath"] ?: @"";
                disk.name = [d objectForKey:@"name"] ?: @"";
                disk.diskDescription = [d objectForKey:@"description"] ?: @"";
                disk.sizeBytes = [[d objectForKey:@"sizeBytes"] unsignedLongLongValue];
                disk.formattedSize = [d objectForKey:@"formattedSize"] ?: @"";
                [_disks addObject:disk];
                [disk release];
            }
            [_statusLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Found %lu disk(s)", @""), (unsigned long)[_disks count]]];
            [_tableView reloadData];
            NSLog(@"IADiskSelectionStep: found %lu disk(s)", (unsigned long)[_disks count]);
        } else {
            [_diagnostics appendString:@"Unexpected JSON output from script\n"];
            if (jsonError) [_diagnostics appendFormat:@"JSON error: %@\n", [jsonError localizedDescription]];
            if (errStr && [errStr length] > 0) [_diagnostics appendFormat:@"Script stderr:\n%@\n", errStr];
            [_statusLabel setStringValue:NSLocalizedString(@"Error enumerating disks - see Details", @"")];
        }
    } else {
        [_diagnostics appendString:@"No output from disk enumeration script\n"];
        if (errStr && [errStr length] > 0) [_diagnostics appendFormat:@"Script stderr:\n%@\n", errStr];
        [_statusLabel setStringValue:NSLocalizedString(@"No disks found - see Details", @"")];
    }

    if (term != 0) {
        [_diagnostics appendFormat:@"Script exited with status %d\n", term];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_disks count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ((NSUInteger)row >= [_disks count]) return @"";
    IADiskInfo *d = [_disks objectAtIndex:row];
    NSString *ident = [tableColumn identifier];
    if ([ident isEqualToString:@"devicePath"]) return d.devicePath;
    if ([ident isEqualToString:@"name"]) return d.name;
    if ([ident isEqualToString:@"formattedSize"]) return d.formattedSize;
    return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    (void)notification;
    NSInteger sel = [_tableView selectedRow];
    if (sel >= 0 && (NSUInteger)sel < [_disks count]) {
        IADiskInfo *d = [_disks objectAtIndex:sel];
        if (delegate && [delegate respondsToSelector:@selector(diskSelectionStep:didSelectDisk:)]) {
            [delegate diskSelectionStep:self didSelectDisk:d];
        }
    }
    /* Update the assistant navigation buttons so Continue reflects canContinue */
    NSWindow *window = [[self stepView] window];
    if (!window) window = [NSApp keyWindow];
    NSWindowController *wc = [window windowController];
    if ([wc isKindOfClass:[GSAssistantWindow class]]) {
        [(GSAssistantWindow *)wc updateNavigationButtons];
    }
}

- (IADiskInfo *)selectedDisk
{
    NSInteger sel = [_tableView selectedRow];
    if (sel >= 0 && (NSUInteger)sel < [_disks count]) return [_disks objectAtIndex:sel];
    return nil;
}

- (void)showDiagnostics:(id)sender
{
    // Show a modal panel with diagnostics text
    NSWindow *panel = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 360)
                                                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    [panel setTitle:NSLocalizedString(@"Disk Enumeration Diagnostics", @"")];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 10, 580, 320)];
    [scrollView setHasVerticalScroller:YES];
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 560, 320)];
    [tv setEditable:NO];
    [tv setString:_diagnostics ?: @"No diagnostics available"]; 
    [scrollView setDocumentView:tv];
    [[panel contentView] addSubview:scrollView];

    NSWindow *win = [[self stepView] window];
    if (!win) win = [NSApp keyWindow];
    [NSApp runModalForWindow:panel];

    [tv release];
    [scrollView release];
    [panel release];
}

- (NSView *)stepView { return _stepView; }
- (NSString *)stepTitle { return stepTitle; }
- (NSString *)stepDescription { return stepDescription; }
- (BOOL)canContinue { return ([self selectedDisk] != nil); }

@end

// ============================================================================
// IAConfirmStep - simple confirmation before destructive action
// ============================================================================

@implementation IAConfirmStep

@synthesize stepTitle, stepDescription;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = NSLocalizedString(@"Confirm Installation", "");
        self.stepDescription = NSLocalizedString(@"Finalize and start installation", "");
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [stepTitle release];
    [stepDescription release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];

    _warningLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 120, 360, 60)];
    [_warningLabel setBezeled:NO];
    [_warningLabel setDrawsBackground:NO];
    [_warningLabel setEditable:NO];
    [_warningLabel setSelectable:NO];
    [_warningLabel setStringValue:NSLocalizedString(@"Warning: This will erase all data on the selected disk.", @"")];
    [[_warningLabel cell] setWraps:YES];
    [_stepView addSubview:_warningLabel];

    _confirmCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 90, 360, 20)];
    [_confirmCheckbox setButtonType:NSSwitchButton];
    [_confirmCheckbox setTitle:NSLocalizedString(@"I understand that all data will be erased", @"")];
    [_confirmCheckbox setState:NSOffState];
    [_confirmCheckbox setTarget:self];
    [_confirmCheckbox setAction:@selector(checkboxToggled:)];
    [_stepView addSubview:_confirmCheckbox];

    _diskInfoLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 60, 360, 20)];
    [_diskInfoLabel setBezeled:NO];
    [_diskInfoLabel setDrawsBackground:NO];
    [_diskInfoLabel setEditable:NO];
    [_diskInfoLabel setSelectable:NO];
    [_stepView addSubview:_diskInfoLabel];
}

- (void)checkboxToggled:(id)sender
{
    NSWindow *window = [[self stepView] window];
    if (!window) window = [NSApp keyWindow];
    NSWindowController *wc = [window windowController];
    if ([wc isKindOfClass:[GSAssistantWindow class]]) {
        GSAssistantWindow *assistantWindow = (GSAssistantWindow *)wc;
        [assistantWindow updateNavigationButtons];
    }
}

- (void)updateWithDisk:(IADiskInfo *)disk
{
    if (disk) {
        [_diskInfoLabel setStringValue:[NSString stringWithFormat:@"%@ (%@)", disk.devicePath, disk.formattedSize ? disk.formattedSize : @""]];
    } else {
        [_diskInfoLabel setStringValue:@""];
    }
}

- (NSView *)stepView { return _stepView; }
- (NSString *)stepTitle { return stepTitle; }
- (NSString *)stepDescription { return stepDescription; }
- (BOOL)canContinue { return ([_confirmCheckbox state] == NSOnState); }

@end

// ============================================================================
// IAInstallProgressStep - run installer script and parse PROGRESS lines
// ============================================================================

@implementation IAInstallProgressStep

@synthesize stepTitle, stepDescription, delegate;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = NSLocalizedString(@"Installing", @"");
        self.stepDescription = NSLocalizedString(@"Installing the system to the selected disk", @"");
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [_progressBar release];
    [_phaseLabel release];
    [_detailLabel release];
    [_percentLabel release];
    [_lineBuffer release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];

    _phaseLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 140, 360, 20)];
    [_phaseLabel setBezeled:NO]; [_phaseLabel setDrawsBackground:NO]; [_phaseLabel setEditable:NO]; [_phaseLabel setSelectable:NO];
    [_phaseLabel setStringValue:NSLocalizedString(@"Phase: preparing", @"")];
    [_stepView addSubview:_phaseLabel];

    _detailLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 110, 360, 20)];
    [_detailLabel setBezeled:NO]; [_detailLabel setDrawsBackground:NO]; [_detailLabel setEditable:NO]; [_detailLabel setSelectable:NO];
    [_stepView addSubview:_detailLabel];

    _percentLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 80, 360, 20)];
    [_percentLabel setBezeled:NO]; [_percentLabel setDrawsBackground:NO]; [_percentLabel setEditable:NO]; [_percentLabel setSelectable:NO];
    [_percentLabel setStringValue:@"0%"];
    [_stepView addSubview:_percentLabel];

    _progressBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, 40, 360, 20)];
    [_progressBar setIndeterminate:NO];
    [_progressBar setMinValue:0.0];
    [_progressBar setMaxValue:100.0];
    [_stepView addSubview:_progressBar];

    _lineBuffer = [[NSMutableString alloc] init];
}

- (void)startInstallationToDisk:(IADiskInfo *)disk
{
    [self startInstallationToDisk:disk source:nil];
}

- (void)startInstallationToDisk:(IADiskInfo *)disk source:(NSString *)sourcePathOrNil
{
    if (!disk) return;
    if (_isRunning) return;

    _isRunning = YES;
    _isFinished = NO;
    _wasSuccessful = NO;
    [_phaseLabel setStringValue:NSLocalizedString(@"Phase: starting", @"")];
    [_detailLabel setStringValue:@""];
    [_percentLabel setStringValue:@"0%"];
    [_progressBar setDoubleValue:0.0];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *scriptPath = IAInstallerScriptPath();
        NSLog(@"IAInstallProgressStep: using script %@", scriptPath);
        NSMutableArray *args = [NSMutableArray arrayWithObjects:@"--noninteractive", @"--disk", disk.devicePath, @"--debug", nil];
        if (sourcePathOrNil && [sourcePathOrNil length] > 0) {
            [args addObject:@"--source"];
            [args addObject:sourcePathOrNil];
            NSLog(@"IAInstallProgressStep: using image source %@", sourcePathOrNil);
        }
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:scriptPath];
        [task setArguments:args];

        NSPipe *outPipe = [NSPipe pipe];
        NSPipe *errPipe = [NSPipe pipe];
        [task setStandardOutput:outPipe];
        [task setStandardError:errPipe];

        @try {
            [task launch];
        } @catch (NSException *ex) {
            NSDictionary *info = @{@"error": [NSString stringWithFormat:@"%@", ex]};
            [self performSelectorOnMainThread:@selector(_installLaunchFailed:) withObject:info waitUntilDone:NO];
            [task release];
            return;
        }

        // Read output to end and parse PROGRESS lines
        NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
        NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        int term = [task terminationStatus];

        NSString *outStr = outData ? [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] autorelease] : @"";
        NSString *errStr = errData ? [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease] : @"";

        // Parse PROGRESS: lines and update UI via main thread
        NSArray *lines = [outStr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in lines) {
            if ([line hasPrefix:@"PROGRESS:"]) {
                NSArray *parts = [line componentsSeparatedByString:@":"];
                if ([parts count] >= 4) {
                    NSString *phase = parts[1];
                    NSString *percentStr = parts[2];
                    NSString *message = [[parts subarrayWithRange:NSMakeRange(3, [parts count]-3)] componentsJoinedByString:@":"];
                    NSDictionary *progressInfo = @{
                        @"phase": phase ?: @"",
                        @"percent": [NSNumber numberWithDouble:[percentStr doubleValue]],
                        @"message": message ?: @""
                    };
                    [self performSelectorOnMainThread:@selector(_updateProgress:) withObject:progressInfo waitUntilDone:NO];
                }
            }
        }

        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        [result setObject:[NSNumber numberWithBool:(term == 0)] forKey:@"success"];
        [result setObject:(errStr ?: @"") forKey:@"stderr"];
        [self performSelectorOnMainThread:@selector(_installCompleted:) withObject:result waitUntilDone:NO];

        [task release];
    });
}

/* Main-thread callback: installer script failed to launch */
- (void)_installLaunchFailed:(NSDictionary *)info
{
    (void)info;
    _isRunning = NO;
    _isFinished = YES;
    _wasSuccessful = NO;
    [_detailLabel setStringValue:NSLocalizedString(@"Failed to launch installer", @"")];
    if (delegate && [delegate respondsToSelector:@selector(installProgressDidFinish:)]) {
        [delegate installProgressDidFinish:NO];
    }
}

/* Main-thread callback: update progress UI */
- (void)_updateProgress:(NSDictionary *)info
{
    NSString *phase = [info objectForKey:@"phase"];
    NSNumber *percent = [info objectForKey:@"percent"];
    NSString *message = [info objectForKey:@"message"];
    [_phaseLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Phase: %@", @""), phase]];
    [_detailLabel setStringValue:message];
    [_percentLabel setStringValue:[NSString stringWithFormat:@"%.0f%%", [percent doubleValue]]];
    [_progressBar setDoubleValue:[percent doubleValue]];
}

/* Main-thread callback: installation completed */
- (void)_installCompleted:(NSDictionary *)info
{
    BOOL success = [[info objectForKey:@"success"] boolValue];
    NSString *errStr = [info objectForKey:@"stderr"];

    _isRunning = NO;
    _isFinished = YES;
    _wasSuccessful = success;
    if (!success) {
        NSString *msg = (errStr && [errStr length] > 0) ? errStr : NSLocalizedString(@"Installation failed.", @"");
        [_detailLabel setStringValue:msg];
    }
    if (delegate && [delegate respondsToSelector:@selector(installProgressDidFinish:)]) {
        [delegate installProgressDidFinish:success];
    }
}

- (NSView *)stepView { return _stepView; }
- (NSString *)stepTitle { return stepTitle; }
- (NSString *)stepDescription { return stepDescription; }
- (BOOL)isFinished { return _isFinished; }
- (BOOL)wasSuccessful { return _wasSuccessful; }
- (BOOL)canContinue { return _isFinished; }

@end

// ============================================================================
// IACompletionStep - show success/failure
// ============================================================================

@implementation IACompletionStep

@synthesize stepTitle, stepDescription;

- (instancetype)init
{
    if (self = [super init]) {
        self.stepTitle = NSLocalizedString(@"Finished", @"");
        self.stepDescription = NSLocalizedString(@"Installation complete", @"");
        [self setupView];
    }
    return self;
}

- (void)dealloc
{
    [_stepView release];
    [_messageLabel release];
    [_detailLabel release];
    [_iconView release];
    [_restartButton release];
    [super dealloc];
}

- (void)setupView
{
    _stepView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];

    _iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 120, 64, 64)];
    [_stepView addSubview:_iconView];

    _messageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 140, 280, 40)];
    [_messageLabel setBezeled:NO]; [_messageLabel setDrawsBackground:NO]; [_messageLabel setEditable:NO]; [_messageLabel setSelectable:NO];
    [_messageLabel setFont:[NSFont boldSystemFontOfSize:14]];
    [_stepView addSubview:_messageLabel];

    _detailLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 100, 280, 30)];
    [_detailLabel setBezeled:NO]; [_detailLabel setDrawsBackground:NO]; [_detailLabel setEditable:NO]; [_detailLabel setSelectable:NO];
    [_stepView addSubview:_detailLabel];

    _restartButton = [[NSButton alloc] initWithFrame:NSMakeRect(100, 20, 120, 30)];
    [_restartButton setTitle:NSLocalizedString(@"Restart", @"")];
    [_restartButton setTarget:self];
    [_restartButton setAction:@selector(restartAction:)];
    [_stepView addSubview:_restartButton];
}

- (void)showSuccessWithDisk:(IADiskInfo *)disk
{
    [_iconView setImage:[NSImage imageNamed:@"status-available"]];
    [_messageLabel setStringValue:NSLocalizedString(@"Installation completed successfully.", @"")];
    [_detailLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Installed to %@", @""), disk.devicePath ?: @""]];
}

- (void)showFailureWithMessage:(NSString *)message
{
    [_iconView setImage:[NSImage imageNamed:@"status-unavailable"]];
    [_messageLabel setStringValue:NSLocalizedString(@"Installation failed", @"")];
    if (message) [_detailLabel setStringValue:message];
}

- (void)restartAction:(id)sender
{
    // For safety, don't implement automatic restart here - leave as a no-op
    NSAlert *a = [[NSAlert alloc] init];
    [a setMessageText:NSLocalizedString(@"Restart requested", @"")];
    [a setInformativeText:NSLocalizedString(@"Please restart the system manually.", @"")];
    [a addButtonWithTitle:NSLocalizedString(@"OK", @"")];
    [a runModal];
    [a release];
}

- (NSView *)stepView { return _stepView; }
- (NSString *)stepTitle { return stepTitle; }
- (NSString *)stepDescription { return stepDescription; }
- (BOOL)canContinue { return YES; }

@end
