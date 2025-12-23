include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = appwrap

# Source files
appwrap_OBJC_FILES = \
	appwrap.m

# Install explicitly into the GNUstep Tools directory
appwrap_INSTALL_DIR = $(GNUSTEP_TOOLS)

# Compiler and flags per project guidelines
# Prefer clang19; fall back to clang or system cc if unavailable
CC ?= $(shell command -v clang19 2>/dev/null || command -v clang 2>/dev/null || echo cc)
ADDITIONAL_OBJCFLAGS += -Wall -Wextra -Werror -O2

# Link GNUstep Foundation (and GUI if needed)
ADDITIONAL_LDFLAGS += -lgnustep-base

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble
