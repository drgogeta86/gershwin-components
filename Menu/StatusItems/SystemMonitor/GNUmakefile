GNUSTEP_INSTALLATION_DOMAIN = SYSTEM
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = SystemMonitor
BUNDLE_EXTENSION = .bundle

SystemMonitor_PRINCIPAL_CLASS = SystemMonitorProvider
SystemMonitor_OBJC_FILES = SystemMonitorProvider.m
SystemMonitor_RESOURCE_FILES = Info.plist

SystemMonitor_HEADER_FILES = SystemMonitorProvider.h

# Link with Foundation and AppKit
SystemMonitor_GUI_LIBS += -lgnustep-gui -lgnustep-base -lobjc

# Compiler flags
ADDITIONAL_OBJCFLAGS = -Wall -Wextra -O2 -fobjc-runtime=gnustep-2.0 -fobjc-arc -Wno-unused-parameter

include $(GNUSTEP_MAKEFILES)/bundle.make
