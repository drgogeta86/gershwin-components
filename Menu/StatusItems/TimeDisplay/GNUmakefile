GNUSTEP_INSTALLATION_DOMAIN = SYSTEM
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = TimeDisplay
BUNDLE_EXTENSION = .bundle

TimeDisplay_PRINCIPAL_CLASS = TimeDisplayProvider
TimeDisplay_OBJC_FILES = TimeDisplayProvider.m
TimeDisplay_RESOURCE_FILES = Info.plist

TimeDisplay_HEADER_FILES = TimeDisplayProvider.h

# Link with Foundation and AppKit
TimeDisplay_GUI_LIBS += -lgnustep-gui -lgnustep-base -lobjc

# Compiler flags
ADDITIONAL_OBJCFLAGS = -Wall -Wextra -O2 -fobjc-runtime=gnustep-2.0 -fobjc-arc -Wno-unused-parameter

include $(GNUSTEP_MAKEFILES)/bundle.make
