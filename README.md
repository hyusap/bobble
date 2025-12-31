# Bobble

A macOS command-line utility that detects head gestures (nods and shakes) using AirPods motion tracking. Perfect for hands-free yes/no interactions in scripts and automation workflows.

## Features

- Detects **nods** (yes) and **head shakes** (no) using CMHeadphoneMotionManager
- Returns boolean results via exit codes for easy scripting
- Configurable timeout, sensitivity, and gesture modes
- **Instant device availability check** with `--check` flag
- Verbose mode for debugging
- **Auto-generated shell completions** (bash, zsh, fish)
- Built with Apple's Swift Argument Parser for robust CLI experience
- Works with AirPods Pro, AirPods Max, and Beats Fit Pro

## Requirements

- macOS 14.0 or later (Sonoma)
- AirPods Pro, AirPods Max, or Beats Fit Pro
- Swift 5.9+ (for building from source)

## Installation

### Via Homebrew (Recommended)

```bash
brew install hyusap/tap/bobble
```

Homebrew will automatically:
- Build from source
- Install to `/opt/homebrew/bin/bobble` (Apple Silicon) or `/usr/local/bin/bobble` (Intel)
- Set up shell completions

### Building from Source

```bash
./build.sh
```

This creates a release build at `.build/release/bobble`

### Install Globally (Optional)

```bash
sudo cp .build/release/bobble /usr/local/bin/
```

### Shell Completions (Optional)

Generate completions for your shell:

```bash
# Bash
bobble --generate-completion-script bash > /usr/local/etc/bash_completion.d/bobble

# Zsh
bobble --generate-completion-script zsh > /usr/local/share/zsh/site-functions/_bobble

# Fish
bobble --generate-completion-script fish > ~/.config/fish/completions/bobble.fish
```

## Usage

### Basic Usage

```bash
# Wait for either nod or shake (30s default timeout)
bobble

# Check the exit code
echo $?  # 0 = nod, 1 = shake, 2 = timeout, 3 = error
```

### Options

```
-h, --help              Show help message
-c, --check             Check if headphone motion is available and exit
-t, --timeout SECONDS   Timeout in seconds (default: 30, range: 1-300)
-s, --sensitivity VALUE Sensitivity 0.1 (very sensitive) to 1.0 (less sensitive)
                        Default: 0.5
-g, --gesture TYPE      Gesture to detect: 'nod', 'shake', or 'both' (default: both)
-v, --verbose           Enable verbose logging to stderr
```

### Exit Codes

- `0` - Nod detected (YES) / Device available (with `--check`)
- `1` - Shake detected (NO)
- `2` - Timeout (no gesture detected)
- `3` - Error (device not available or invalid arguments)

## Examples

### Check Device Availability

```bash
#!/bin/bash

# Quick check if AirPods with motion support are available
if bobble --check; then
    echo "AirPods ready for gesture detection"
else
    echo "No compatible AirPods detected"
    exit 1
fi
```

### Simple Yes/No Prompt

```bash
#!/bin/bash

echo "Do you want to continue? (Nod for yes, shake for no)"
bobble --timeout 15

if [ $? -eq 0 ]; then
    echo "User said YES - continuing..."
    # Your code here
elif [ $? -eq 1 ]; then
    echo "User said NO - aborting..."
    exit 1
fi
```

### Detect Only Nods

```bash
# Wait for a nod gesture only
bobble --gesture nod --timeout 10

if [ $? -eq 0 ]; then
    echo "Nod confirmed!"
fi
```

### High Sensitivity with Verbose Output

```bash
# More sensitive detection with debug logging
bobble --sensitivity 0.3 --verbose
```

### In a Loop (Confirmation Retries)

```bash
#!/bin/bash

attempt=1
max_attempts=3

while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt/$max_attempts: Nod to confirm"
    bobble --gesture nod --timeout 10
    
    if [ $? -eq 0 ]; then
        echo "Confirmed!"
        break
    elif [ $? -eq 2 ]; then
        echo "Timeout - try again"
        ((attempt++))
    else
        echo "Error"
        exit 1
    fi
done
```

### Python Integration

```python
import subprocess
import sys

print("Nod for yes, shake for no")
result = subprocess.run(['bobble', '--timeout', '20'])

if result.returncode == 0:
    print("User said YES")
elif result.returncode == 1:
    print("User said NO")
elif result.returncode == 2:
    print("Timeout")
else:
    print("Error - headphones not available")
    sys.exit(1)
```

### Node.js Integration

```javascript
const { spawn } = require('child_process');

console.log('Waiting for gesture...');

const bobble = spawn('bobble', ['--timeout', '15']);

bobble.on('close', (code) => {
    if (code === 0) {
        console.log('User nodded (YES)');
    } else if (code === 1) {
        console.log('User shook head (NO)');
    } else if (code === 2) {
        console.log('Timeout');
    } else {
        console.error('Error or device unavailable');
    }
});
```

## How It Works

The tool uses Apple's `CMHeadphoneMotionManager` to track the orientation of supported headphones:

1. **Nod Detection**: Monitors pitch (forward/backward tilt)
   - Detects downward head motion followed by return to neutral
   - Default threshold: ~9-23° depending on sensitivity

2. **Shake Detection**: Monitors yaw (left/right rotation)
   - Detects left rotation followed by right rotation (or vice versa)
   - Default threshold: ~17-37° depending on sensitivity

3. **State Machine**: Tracks gesture progress with timing windows and cooldowns to prevent false positives

4. **Smoothing**: Applies moving average filter to reduce noise

## Tips

- **Sensitivity**: Start with default (0.5) and adjust as needed
  - Lower values (0.1-0.4) = more sensitive, may have false positives
  - Higher values (0.6-1.0) = less sensitive, requires more pronounced gestures

- **Verbose Mode**: Use `--verbose` to see real-time motion data and debug detection
  - Helpful for calibrating sensitivity for your use case
  
- **Gesture Style**: 
  - **Nod**: Natural up/down head motion (like nodding "yes")
  - **Shake**: Clear left-to-right or right-to-left rotation (like shaking "no")

- **Timeout**: Set realistic timeouts based on your use case
  - Quick confirmations: 10-15 seconds
  - Longer interactions: 30-60 seconds

## Troubleshooting

**"Headphone motion not available"**
- Make sure AirPods Pro/Max or Beats Fit Pro are connected
- Check Bluetooth connection
- Try reconnecting headphones

**Gestures not being detected**
- Increase sensitivity with `--sensitivity 0.3`
- Use `--verbose` to see motion data
- Make more pronounced gestures
- Ensure headphones fit properly

**Too many false positives**
- Decrease sensitivity with `--sensitivity 0.7`
- Make more deliberate, slower gestures
- Ensure you're returning to neutral position between gestures

## License

MIT

## Contributing

Feel free to open issues or submit pull requests!
