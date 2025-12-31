import Foundation
import CoreMotion

// MARK: - CLI Argument Parser

struct Arguments {
    var timeout: TimeInterval = 30.0
    var sensitivity: Double = 0.5
    var mode: GestureConfig.DetectionMode = .both
    var verbose: Bool = false
    var showHelp: Bool = false
    var checkAvailability: Bool = false
    var prompt: String? = nil
    
    init(args: [String]) {
        var i = 1 // Skip program name
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--help", "-h":
                showHelp = true
                
            case "--check", "-c":
                checkAvailability = true
                
            case "--timeout", "-t":
                if i + 1 < args.count, let value = Double(args[i + 1]) {
                    timeout = max(1.0, min(300.0, value)) // Clamp between 1-300 seconds
                    i += 1
                } else {
                    fputs("Error: --timeout requires a numeric value\n", stderr)
                    exit(3)
                }
                
            case "--sensitivity", "-s":
                if i + 1 < args.count, let value = Double(args[i + 1]) {
                    sensitivity = max(0.1, min(1.0, value)) // Clamp between 0.1-1.0
                    i += 1
                } else {
                    fputs("Error: --sensitivity requires a value between 0.1 and 1.0\n", stderr)
                    exit(3)
                }
                
            case "--gesture", "-g":
                if i + 1 < args.count {
                    let gestureType = args[i + 1].lowercased()
                    switch gestureType {
                    case "nod", "yes":
                        mode = .nodOnly
                    case "shake", "no":
                        mode = .shakeOnly
                    case "both", "any":
                        mode = .both
                    default:
                        fputs("Error: --gesture must be 'nod', 'shake', or 'both'\n", stderr)
                        exit(3)
                    }
                    i += 1
                } else {
                    fputs("Error: --gesture requires a value (nod/shake/both)\n", stderr)
                    exit(3)
                }
                
            case "--verbose", "-v":
                verbose = true
                
            case "--prompt", "-p":
                if i + 1 < args.count {
                    prompt = args[i + 1]
                    i += 1
                } else {
                    fputs("Error: --prompt requires a text value\n", stderr)
                    exit(3)
                }
                
            default:
                fputs("Error: Unknown argument '\(arg)'\n", stderr)
                fputs("Use --help for usage information\n", stderr)
                exit(3)
            }
            
            i += 1
        }
    }
    
    static func printHelp() {
        print("""
        HeadGesture - Detect head nods (yes) and shakes (no) using AirPods motion
        
        USAGE:
            headgesture [OPTIONS]
        
        OPTIONS:
            -h, --help              Show this help message
            -c, --check             Check if headphone motion is available and exit
            -t, --timeout SECONDS   Timeout in seconds (default: 30, range: 1-300)
            -s, --sensitivity VALUE Sensitivity from 0.1 (very sensitive) to 1.0 (less sensitive)
                                    Default: 0.5
            -g, --gesture TYPE      Gesture to detect: 'nod', 'shake', or 'both' (default: both)
            -p, --prompt TEXT       Speak this prompt through AirPods before detecting gesture
            -v, --verbose           Enable verbose logging to stderr
        
        EXIT CODES:
            0 - Nod detected (YES) / Device available (with --check)
            1 - Shake detected (NO)
            2 - Timeout (no gesture detected)
            3 - Error (device not available or invalid arguments)
        
        EXAMPLES:
            # Check if AirPods with motion support are available
            headgesture --check
            
            # Wait for either nod or shake (30s timeout)
            headgesture
            
            # Only detect nods with 15 second timeout
            headgesture --gesture nod --timeout 15
            
            # High sensitivity shake detection with verbose output
            headgesture --gesture shake --sensitivity 0.3 --verbose
            
            # Speak a prompt before detecting gesture
            headgesture --prompt "Do you want to proceed?"
            
            # Use in a shell script
            headgesture --timeout 10
            if [ $? -eq 0 ]; then
                echo "User said YES"
            elif [ $? -eq 1 ]; then
                echo "User said NO"
            fi
        
        REQUIREMENTS:
            - macOS 14.0 or later
            - AirPods Pro, AirPods Max, or Beats Fit Pro connected
        """)
    }
}

// MARK: - Main Program

@available(macOS 14.0, *)
func runDetector() {
    let args = Arguments(args: CommandLine.arguments)
    
    if args.showHelp {
        Arguments.printHelp()
        exit(0)
    }
    
    // Check availability mode
    if args.checkAvailability {
        let motionManager = CMHeadphoneMotionManager()
        if motionManager.isDeviceMotionAvailable {
            if args.verbose {
                fputs("Headphone motion available\n", stderr)
            }
            exit(0)
        } else {
            if args.verbose {
                fputs("Headphone motion not available\n", stderr)
            }
            exit(3)
        }
    }
    
    // Speak prompt if provided using macOS 'say' command
    if let promptText = args.prompt {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        task.arguments = [promptText]
        try? task.run()
        task.waitUntilExit()
    }
    
    // Create configuration
    let config = GestureConfig(
        sensitivity: args.sensitivity,
        timeout: args.timeout,
        mode: args.mode,
        verbose: args.verbose
    )
    
    // Create detector
    let detector = MotionDetector(config: config)
    
    // Set up semaphore to keep program running until gesture detected
    let semaphore = DispatchSemaphore(value: 0)
    var finalResult: GestureResult = .timeout
    
    // Start detection
    detector.start { result in
        finalResult = result
        semaphore.signal()
    }
    
    // Wait for result
    semaphore.wait()
    
    // Exit with appropriate code
    exit(finalResult.rawValue)
}

// Check macOS version and run
if #available(macOS 14.0, *) {
    runDetector()
} else {
    fputs("Error: This tool requires macOS 14.0 or later\n", stderr)
    exit(3)
}
