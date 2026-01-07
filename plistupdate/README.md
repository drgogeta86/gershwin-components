# plistupdate

A command-line tool that automatically updates `Info-gnustep.plist` files with build metadata, including git revision information and release dates.

## Overview

`plistupdate` is designed to integrate seamlessly with the GNUstep build system to automatically maintain version information in application property list files. It updates two key fields:

* **NSBuildVersion** - Set to the short git commit hash (e.g., "a1b2c3d") if the plist file is contained in a git repository, otherwise set to "dev"
* **ApplicationRelease** - Set to the current date in YYYYMMDD format (e.g., 20260107)

## Installation

### Building from Source

```bash
cd gershwin-components/plistupdate
make
sudo make install
```

This will install:
- The `plistupdate` tool to `$GNUSTEP_LOCAL_ROOT/Tools`
- The man page to `$GNUSTEP_LOCAL_ROOT/share/man/man1`

## Usage

### Command-Line Usage

```bash
plistupdate [OPTIONS] PLIST_FILE
```

#### Options

- `-h, --help` - Display help message and exit
- `-v, --version` - Display version information and exit
- `-b, --build VERSION` - Manually set NSBuildVersion (overrides git detection)
- `-d, --date DATE` - Manually set ApplicationRelease in YYYYMMDD format
- `-n, --no-git` - Skip git version detection, use "dev" for NSBuildVersion
- `-q, --quiet` - Suppress informational messages (errors still shown)

#### Examples

Update with automatic git version and current date:
```bash
plistupdate MyApp.app/Resources/Info-gnustep.plist
```

Set specific version and date:
```bash
plistupdate -b 1.0 -d 20260107 Info-gnustep.plist
```

Quiet mode (no informational output):
```bash
plistupdate -q MyApp.app/Resources/Info-gnustep.plist
```

## GNUstep Build System Integration

The tool is automatically integrated into the GNUstep build system and runs whenever an application, bundle, palette, or gswapp is built. plistupdate updates the `Info-gnustep.plist` file after it's generated during the build process.

### Installation

```bash
# Build plistupdate
cd gershwin-components/plistupdate
export GNUSTEP_MAKEFILES=/System/Library/Makefiles
make clean && make
GNUSTEP_MAKEFILES=/System/Library/Makefiles sudo -E make install

# Rebuild and reinstall tools-make to apply integration to /System/Library/Makefiles
cd ../../../tools-make
./configure
make
sudo make install
```

### Verification

After installation, verify the integration works by building a test GNUstep app in a git repository:

```bash
mkdir /tmp/test-app && cd /tmp/test-app
git init && git config user.email "test@example.com" && git config user.name "Test"

cat > GNUmakefile << 'EOF'
include $(GNUSTEP_MAKEFILES)/common.make
APP_NAME = TestApp
TestApp_PRINCIPAL_CLASS = NSApplication
TestApp_OBJC_FILES = main.m
include $(GNUSTEP_MAKEFILES)/application.make
EOF

cat > main.m << 'EOF'
#import <Foundation/Foundation.h>
int main() { return 0; }
EOF

git add . && git commit -m "Initial commit"
make

# Check that NSBuildVersion contains the git hash (not "dev")
grep NSBuildVersion TestApp.app/Resources/Info-gnustep.plist
```

Expected output: `NSBuildVersion = <git-hash>;` (e.g., `4370fd0`)

### How It Works

During the build process, after the `Info-gnustep.plist` file is created/merged, plistupdate is automatically invoked to update the build metadata:

1. **application.make** - for GNUstep applications
2. **bundle.make** - for bundles (2 locations)
3. **palette.make** - for palettes
4. **gswapp.make** - for web applications

The tool uses this pattern in each make file:

```make
-$(ECHO_NOTHING)if command -v plistupdate >/dev/null 2>&1; then \
  plistupdate -q $@ || true; \
fi$(END_ECHO)
```

**Key features:**
- Non-fatal execution (prefixed with `-` and `|| true`) - build continues even if plistupdate fails
- Quiet mode (`-q`) - suppresses informational output
- Conditional (`command -v`) - only runs if plistupdate is installed
- Follows GNUstep make conventions with `$(ECHO_NOTHING)` and `$(END_ECHO)`

## File Format

The tool works with GNUstep-style property list files. Example structure:

```
{
    ApplicationDescription = "The Gershwin Desktop Experience";
    ApplicationIcon = "FileManager.tiff";
    ApplicationName = Workspace;
    ApplicationRelease = 20260107;
    Authors = (
        "Simon Peter",
        "Joseph Maloney"
    );
    CFBundleIdentifier = "org.gnustep.Workspace";
    Copyright = "Workspace Copyright (C) 2003-2026 Free Software Foundation, Inc.";
    CopyrightDescription = "Released under the GNU General Public License 2.0 or later";
    GSMainMarkupFile = "";
    NOTE = "Automatically generated, do not edit!";
    NSBuildVersion = "a1b2c3d";
    NSExecutable = Workspace;
    NSIcon = "FileManager.tiff";
    NSMainNibFile = "";
    NSMainStoryboardFile = "";
    NSPrincipalClass = Workspace;
    NSRole = Viewer;
}
```

## Git Integration

The tool automatically detects if the plist file is within a git repository by searching for a `.git` directory starting from the file's location and traversing up the directory tree.

**Important:** The tool correctly handles both absolute and relative file paths. When the make system calls plistupdate with a relative path (e.g., `TestApp.app/Resources/Info-gnustep.plist`), the tool automatically converts it to an absolute path before searching for the git repository.

When found, it executes:
```bash
git rev-parse --short HEAD
```

If git is unavailable, the repository is not found, or the command fails, `NSBuildVersion` is set to "dev".

## Error Handling

The tool handles various error conditions gracefully:

- **File not found** - Reports error and exits with status 1
- **Invalid plist format** - Reports parsing error and exits with status 1
- **Git command fails** - Falls back to "dev" for NSBuildVersion
- **Write failure** - Reports error and exits with status 1

## Exit Status

- **0** - Success
- **1** - Error occurred

## Requirements

- GNUstep Base library
- Foundation framework
- Git (optional, for automatic version detection)

## See Also

- `plmerge(1)` - Tool for merging property lists
- `gmake(1)` - GNU Make
- `git(1)` - Git version control
- GNUstep Make Documentation: http://www.gnustep.org/resources/documentation/make/

```