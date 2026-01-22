/*
 * Copyright (c) 2025 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "WindowMonitor.h"
#import <dispatch/dispatch.h>
#import <X11/Xatom.h>
#import <X11/Xutil.h>

@interface WindowMonitor ()
{
    Display *_display;
    Window _rootWindow;
    Atom _netActiveWindowAtom;
    Atom _gstepAppAtom;
    dispatch_source_t _x11EventSource;
    dispatch_queue_t _x11Queue;
    unsigned long _currentActiveWindow;
    BOOL _monitoring;
}
@end

@implementation WindowMonitor

+ (instancetype)sharedMonitor
{
    static WindowMonitor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _display = NULL;
        _rootWindow = 0;
        _netActiveWindowAtom = 0;
        _gstepAppAtom = 0;
        _x11EventSource = NULL;
        _currentActiveWindow = 0;
        _monitoring = NO;
        
        // Create serial queue for X11 operations (all Xlib calls must be on same queue)
        _x11Queue = dispatch_queue_create("org.gnustep.menu.windowmonitor", DISPATCH_QUEUE_SERIAL);
        
        NSLog(@"WindowMonitor: Initialized");
    }
    return self;
}

- (void)dealloc
{
    [self stopMonitoring];
}

- (Display *)display
{
    return _display;
}

- (Window)rootWindow
{
    return _rootWindow;
}

- (unsigned long)currentActiveWindow
{
    return _currentActiveWindow;
}

- (BOOL)startMonitoring
{
    if (_monitoring) {
        NSLog(@"WindowMonitor: Already monitoring");
        return YES;
    }
    
    NSLog(@"WindowMonitor: Starting event-driven monitoring using GCD");
    
    // Open X11 display
    _display = XOpenDisplay(NULL);
    if (!_display) {
        NSLog(@"WindowMonitor: ERROR - Cannot open X11 display");
        return NO;
    }
    
    _rootWindow = DefaultRootWindow(_display);
    
    // Intern required atoms
    _netActiveWindowAtom = XInternAtom(_display, "_NET_ACTIVE_WINDOW", False);
    _gstepAppAtom = XInternAtom(_display, "_GNUSTEP_WM_ATTR", False);
    
    // Subscribe to PropertyNotify events on root window
    XSelectInput(_display, _rootWindow, PropertyChangeMask);
    XSync(_display, False);
    
    // Get X11 connection file descriptor
    int xfd = ConnectionNumber(_display);
    NSLog(@"WindowMonitor: X11 file descriptor: %d", xfd);
    
    // Create GCD dispatch source for X11 events (event-driven, zero-polling)
    _x11EventSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, xfd, 0, _x11Queue);
    
    if (!_x11EventSource) {
        NSLog(@"WindowMonitor: ERROR - Failed to create dispatch source");
        XCloseDisplay(_display);
        _display = NULL;
        return NO;
    }
    
    // Set up event handler
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_x11EventSource, ^{
        [weakSelf handleX11Events];
    });
    
    // Set up cancellation handler
    dispatch_source_set_cancel_handler(_x11EventSource, ^{
        NSLog(@"WindowMonitor: Dispatch source cancelled");
    });
    
    // Activate the dispatch source
    dispatch_resume(_x11EventSource);
    
    _monitoring = YES;
    NSLog(@"WindowMonitor: Monitoring started - event-driven, zero-polling");
    
    // Get initial active window and notify delegate
    dispatch_async(dispatch_get_main_queue(), ^{
        unsigned long initialWindow = [weakSelf getActiveWindow];
        if (weakSelf.delegate && initialWindow != 0) {
            [weakSelf.delegate activeWindowChanged:initialWindow];
        }
    });
    
    return YES;
}

- (void)stopMonitoring
{
    if (!_monitoring) {
        return;
    }
    
    NSLog(@"WindowMonitor: Stopping monitoring");
    
    _monitoring = NO;
    
    // Cancel and release dispatch source
    if (_x11EventSource) {
        dispatch_source_cancel(_x11EventSource);
        _x11EventSource = NULL;
    }
    
    // Close X11 display
    if (_display) {
        XCloseDisplay(_display);
        _display = NULL;
    }
    
    _rootWindow = 0;
    _netActiveWindowAtom = 0;
    _currentActiveWindow = 0;
    
    NSLog(@"WindowMonitor: Monitoring stopped");
}

- (void)handleX11Events
{
    // Process all pending X11 events
    while (XPending(_display) > 0) {
        XEvent event;
        XNextEvent(_display, &event);
        
        if (event.type == PropertyNotify &&
            event.xproperty.window == _rootWindow &&
            event.xproperty.atom == _netActiveWindowAtom) {
            
            // Active window changed - read new value
            unsigned long newActiveWindow = [self getActiveWindow];
            
            if (newActiveWindow != _currentActiveWindow) {
                NSLog(@"WindowMonitor: Active window changed: 0x%lx -> 0x%lx", 
                      _currentActiveWindow, newActiveWindow);
                
                _currentActiveWindow = newActiveWindow;
                
                // Notify delegate on main queue
                if (self.delegate) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate activeWindowChanged:newActiveWindow];
                    });
                }
            }
        }
    }
}

- (unsigned long)getActiveWindow
{
    if (!_display) {
        return 0;
    }
    
    Atom actualType;
    int actualFormat;
    unsigned long nItems, bytesAfter;
    unsigned char *prop = NULL;
    unsigned long activeWindow = 0;
    
    int result = XGetWindowProperty(_display, _rootWindow, _netActiveWindowAtom,
                                    0, 1, False, XA_WINDOW,
                                    &actualType, &actualFormat, &nItems, &bytesAfter, &prop);
    
    if (result == Success && prop && nItems > 0) {
        activeWindow = *(Window*)prop;
        XFree(prop);
    }
    
    return activeWindow;
}

- (BOOL)isGNUstepWindow:(unsigned long)windowId
{
    if (!_display || windowId == 0) {
        return NO;
    }
    
    // Check for _GNUSTEP_WM_ATTR property which identifies GNUstep windows
    Atom actualType;
    int actualFormat;
    unsigned long nItems, bytesAfter;
    unsigned char *prop = NULL;
    
    int result = XGetWindowProperty(_display, (Window)windowId, _gstepAppAtom,
                                    0, 32, False, AnyPropertyType,
                                    &actualType, &actualFormat, &nItems, &bytesAfter, &prop);
    
    if (result == Success && prop) {
        XFree(prop);
        return YES;
    }
    
    return NO;
}

@end
