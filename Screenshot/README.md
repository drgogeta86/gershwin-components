# Screenshot

Screenshot.app is a production-ready GNUstep application for taking screenshots. It allows you to:
- Click on a window to capture that window
- Select an area with the mouse to capture that region
- Capture the full screen

The application provides both a GUI interface and command-line operation.

## Usage

### GUI Mode

Launch the application without arguments to show the graphical interface.

### Command Line Mode

```bash
Screenshot.app/Screenshot [options] [output-file]
```

Options:
- `-h, --help`         Show help message
- `-s, --select`       Select area to screenshot (interactive - drag to select)
- `-w, --window`       Select window to screenshot (interactive - click on window)
- `-d, --delay SEC`    Wait SEC seconds before taking screenshot
- `-o, --output FILE`  Save screenshot to FILE

Examples:
```bash
# Full screen screenshot
Screenshot.app/Screenshot screenshot.png

# Window selection - you'll be prompted to click on a window
Screenshot.app/Screenshot -w window.png

# Interactive area selection - you'll drag to select the area
Screenshot.app/Screenshot --select area.png

# Full screen with 5 second delay
Screenshot.app/Screenshot -d 5 delayed.png
```

**Note**: For window (-w) and area (-s) modes, the program waits for your interaction:
- **Window mode**: Click on any window to capture it
- **Area mode**: Click and drag to select a rectangular area