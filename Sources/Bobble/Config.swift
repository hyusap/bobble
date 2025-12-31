import Foundation

struct GestureConfig {
    // Angle thresholds in radians
    var nodPitchThreshold: Double
    var shakeYawThreshold: Double
    
    // Timing parameters
    var gestureTimeWindow: TimeInterval
    var cooldownPeriod: TimeInterval
    var updateInterval: TimeInterval
    var timeout: TimeInterval
    
    // Detection mode
    enum DetectionMode {
        case both      // Detect either nod or shake
        case nodOnly   // Only detect nods
        case shakeOnly // Only detect shakes
    }
    var mode: DetectionMode
    
    // Output settings
    var verbose: Bool
    
    init(sensitivity: Double = 0.5, timeout: TimeInterval = 30.0, mode: DetectionMode = .both, verbose: Bool = false) {
        // Scale thresholds based on sensitivity (0.1 = very sensitive, 1.0 = less sensitive)
        // Lower threshold = more sensitive
        // Rescaled so that 0.2 old sensitivity ≈ 0.5 new sensitivity
        self.nodPitchThreshold = 0.075 + (sensitivity * 0.25)    // ~6° to ~19°
        self.shakeYawThreshold = 0.195 + (sensitivity * 0.35)    // ~13° to ~33°
        
        self.gestureTimeWindow = 1.2  // seconds to complete gesture
        self.cooldownPeriod = 0.5     // seconds between gestures
        self.updateInterval = 1.0/60.0 // 60Hz sampling
        self.timeout = timeout
        self.mode = mode
        self.verbose = verbose
    }
    
    func log(_ message: String) {
        if verbose {
            fputs("[\(Date().timeIntervalSince1970)] \(message)\n", stderr)
        }
    }
}

enum GestureResult: Int32 {
    case nod = 0        // YES
    case shake = 1      // NO
    case timeout = 2    // No gesture detected
    case error = 3      // Device unavailable or error
}
