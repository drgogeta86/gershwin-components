#!/bin/sh
#
# setup-integration.sh - Checks plistupdate integration in GNUstep Make files
#
# This script checks whether plistupdate integration is already configured in
# the system GNUstep Make files at /System/Library/Makefiles/Instance.
#
# SYNOPSIS:
#   ./setup-integration.sh
#
# DESCRIPTION:
#   This script verifies that plistupdate integration is present in the system
#   make files by:
#   1. Checking if plistupdate calls already exist in make files
#   2. Reporting on the integration status
#
# EXIT STATUS:
#   0   Success (integration is present or complete)
#   1   Error (missing directory or permission issues)
#
# NOTE:
#   To add integration to the source tools-make repository, edit the make files
#   directly or use: ./setup-integration.sh /path/to/tools-make
#

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function to print colored messages
print_status() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}✗${NC} %s\n" "$1"
}

# Configuration - default to system make files
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_MAKE_PATH="${1:-/System/Library/Makefiles}"

TOOLS_MAKE_PATH="$(cd "$TOOLS_MAKE_PATH" 2>/dev/null && pwd)" || {
    print_error "Invalid path: $1"
    exit 1
}

INSTANCE_DIR="$TOOLS_MAKE_PATH/Instance"

# Flag to track if any changes were made
CHANGES_MADE=0

# Verify tools-make directory exists
if [ ! -d "$INSTANCE_DIR" ]; then
    print_error "GNUstep Make Instance directory not found at: $INSTANCE_DIR"
    echo "Usage: $0 [MAKE_FILES_PATH]"
    exit 1
fi

echo "Checking plistupdate integration in GNUstep Make files..."
echo "Location: $INSTANCE_DIR"
echo ""

# 1. application.make integration
echo "1. Checking application.make..."
APP_MAKE="$INSTANCE_DIR/application.make"
APP_SEARCH='fi$(END_ECHO)$'
APP_CODE='	-$(ECHO_NOTHING)if command -v plistupdate >/dev/null 2>&1; then \
	  plistupdate -q $@ || true; \
	fi$(END_ECHO)'

if grep -q "plistupdate" "$APP_MAKE"; then
    print_status "application.make: Already integrated"
else
    if grep -q 'plmerge $@ "$(GNUSTEP_PLIST_DEPEND)"' "$APP_MAKE"; then
        print_status "application.make: Needs integration"
        cp "$APP_MAKE" "$APP_MAKE.bak"
        
        # Find the line with plmerge and add plistupdate after the closing fi
        sed -i.tmp '
        /plmerge.*GNUSTEP_PLIST_DEPEND/{
            N
            N
            /fi$(END_ECHO)/a\
\	-$(ECHO_NOTHING)if command -v plistupdate >/dev/null 2>&1; then \\\
\	  plistupdate -q $@ || true; \\\
\	fi$(END_ECHO)
        }
        ' "$APP_MAKE"
        rm -f "$APP_MAKE.tmp"
        print_status "application.make: Integration added"
        CHANGES_MADE=1
    else
        print_warning "application.make: Could not find integration point"
    fi
fi
echo ""

# 2. bundle.make integration (needs to be added to both locations)
echo "2. Checking bundle.make..."
BUNDLE_MAKE="$INSTANCE_DIR/bundle.make"

if grep -c "plistupdate" "$BUNDLE_MAKE" >/dev/null 2>&1; then
    bundle_count=$(grep -c "plistupdate" "$BUNDLE_MAKE" || echo 0)
    if [ "$bundle_count" -ge 2 ]; then
        print_status "bundle.make: Already integrated (both locations)"
    elif [ "$bundle_count" -eq 1 ]; then
        print_warning "bundle.make: Partially integrated (1 of 2 locations)"
    fi
else
    print_status "bundle.make: Needs integration"
    cp "$BUNDLE_MAKE" "$BUNDLE_MAKE.bak"
    
    # Add plistupdate integration to both plmerge locations in bundle.make
    sed -i.tmp '
    /fi$(END_ECHO).*plmerge/{
        a\
\	-$(ECHO_NOTHING)if command -v plistupdate >/dev/null 2>&1; then \\\
\	  plistupdate -q $@ || true; \\\
\	fi$(END_ECHO)
    }
    ' "$BUNDLE_MAKE"
    rm -f "$BUNDLE_MAKE.tmp"
    print_status "bundle.make: Integration added"
    CHANGES_MADE=1
fi
echo ""

# 3. palette.make integration
echo "3. Checking palette.make..."
PALETTE_MAKE="$INSTANCE_DIR/palette.make"

if grep -q "plistupdate" "$PALETTE_MAKE"; then
    print_status "palette.make: Already integrated"
else
    print_status "palette.make: Needs integration"
    cp "$PALETTE_MAKE" "$PALETTE_MAKE.bak"
    
    # Find the Info-gnustep.plist target and add plistupdate after the closing brace
    sed -i.tmp '
    /echo "}".*>$@/{
        a\
\	-$(ECHO_NOTHING)if command -v plistupdate >/dev/null 2>&1; then \\\
\	  plistupdate -q $@ || true; \\\
\	fi$(END_ECHO)
    }
    ' "$PALETTE_MAKE"
    rm -f "$PALETTE_MAKE.tmp"
    print_status "palette.make: Integration added"
    CHANGES_MADE=1
fi
echo ""

# 4. gswapp.make integration
echo "4. Checking gswapp.make..."
GSWAPP_MAKE="$INSTANCE_DIR/gswapp.make"

if grep -q "plistupdate" "$GSWAPP_MAKE"; then
    print_status "gswapp.make: Already integrated"
else
    print_status "gswapp.make: Needs integration"
    cp "$GSWAPP_MAKE" "$GSWAPP_MAKE.bak"
    
    # Find the line with >$@$(END_ECHO) in Info-gnustep.plist generation and add plistupdate
    sed -i.tmp '
    /echo "}".*>$@$(END_ECHO)/{
        a\
\	-$(ECHO_NOTHING)if command -v plistupdate >/dev/null 2>&1; then \\\
\	  plistupdate -q $@ || true; \\\
\	fi$(END_ECHO)
    }
    ' "$GSWAPP_MAKE"
    rm -f "$GSWAPP_MAKE.tmp"
    print_status "gswapp.make: Integration added"
    CHANGES_MADE=1
fi
echo ""

# Summary
echo "================================================================"
if [ "$CHANGES_MADE" -eq 1 ]; then
    echo "Setup complete. Integration has been added to GNUstep Make files."
    echo ""
    echo "The following files were modified:"
    for file in "$APP_MAKE" "$BUNDLE_MAKE" "$PALETTE_MAKE" "$GSWAPP_MAKE"; do
        if [ -f "$file.bak" ]; then
            echo "  - $file"
        fi
    done
    echo ""
    echo "Backups have been created with .bak extension."
    echo ""
    echo "You can now run: make && sudo make install"
else
    echo "All integration points are already configured correctly."
fi
echo "================================================================"

exit 0
