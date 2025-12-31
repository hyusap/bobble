import Foundation
import CoreMotion
import ArgumentParser

// MARK: - Main Command

@available(macOS 14.0, *)
@main
struct Bobble: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bobble",
        abstract: "Detect head nods (yes) and shakes (no) using AirPods motion",
        discussion: """
            Bobble uses CoreMotion to detect head gestures through AirPods Pro, AirPods Max, 
            or Beats Fit Pro. Perfect for hands-free yes/no interactions.
            
            EXIT CODES:
              0 - Nod detected (YES) / Device available (with --check)
              1 - Shake detected (NO)
              2 - Timeout (no gesture detected)
              3 - Error (device not available or invalid arguments)
            
            REQUIREMENTS:
              - macOS 14.0 or later
              - AirPods Pro, AirPods Max, or Beats Fit Pro connected
            """,
        version: "1.0.0"
    )
    
    @Flag(name: .shortAndLong, help: "Check if headphone motion is available and exit")
    var check: Bool = false
    
    @Option(name: .shortAndLong, help: "Timeout in seconds (range: 1-300)")
    var timeout: Double = 30.0
    
    @Option(name: .shortAndLong, help: "Sensitivity from 0.1 (very sensitive) to 1.0 (less sensitive)")
    var sensitivity: Double = 0.5
    
    @Option(name: .shortAndLong, help: "Gesture to detect: 'nod', 'shake', or 'both'")
    var gesture: GestureType = .both
    
    @Option(name: .shortAndLong, help: "Speak this prompt through AirPods before detecting gesture")
    var prompt: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose logging to stderr")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard timeout >= 1.0 && timeout <= 300.0 else {
            throw ValidationError("Timeout must be between 1 and 300 seconds")
        }
        
        guard sensitivity >= 0.1 && sensitivity <= 1.0 else {
            throw ValidationError("Sensitivity must be between 0.1 and 1.0")
        }
    }
    
    func run() throws {
        // Check availability mode
        if check {
            let motionManager = CMHeadphoneMotionManager()
            if motionManager.isDeviceMotionAvailable {
                if verbose {
                    fputs("Headphone motion available\n", stderr)
                }
                throw ExitCode.success
            } else {
                if verbose {
                    fputs("Headphone motion not available\n", stderr)
                }
                throw ExitCode(3)
            }
        }
        
        // Speak prompt if provided using macOS 'say' command
        if let promptText = prompt {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            task.arguments = [promptText]
            try? task.run()
            task.waitUntilExit()
        }
        
        // Create configuration
        let config = GestureConfig(
            sensitivity: sensitivity,
            timeout: timeout,
            mode: gesture.detectionMode,
            verbose: verbose
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
        throw ExitCode(finalResult.rawValue)
    }
}

// MARK: - Gesture Type Enum

enum GestureType: String, ExpressibleByArgument {
    case nod
    case shake
    case both
    
    var detectionMode: GestureConfig.DetectionMode {
        switch self {
        case .nod:
            return .nodOnly
        case .shake:
            return .shakeOnly
        case .both:
            return .both
        }
    }
}
