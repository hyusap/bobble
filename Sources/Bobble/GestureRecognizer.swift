import Foundation
import CoreMotion

@available(macOS 14.0, *)
class GestureRecognizer {
    private let config: GestureConfig
    private let completion: (GestureResult) -> Void
    
    // State tracking for nod detection
    private enum NodState {
        case idle
        case detectingDown
    }
    private var nodState: NodState = .idle
    private var nodStartTime: TimeInterval = 0
    private var lastNodGestureTime: TimeInterval = 0
    
    // State tracking for shake detection
    private enum ShakeState {
        case idle
        case detectingLeft
        case detectingRight
    }
    private var shakeState: ShakeState = .idle
    private var shakeStartTime: TimeInterval = 0
    private var lastShakeGestureTime: TimeInterval = 0
    
    // Reference orientation for relative measurements
    private var baselinePitch: Double = 0
    private var baselineYaw: Double = 0
    private var hasBaseline = false
    
    // Smoothing
    private var pitchHistory: [Double] = []
    private var yawHistory: [Double] = []
    private let smoothingWindow = 3
    
    init(config: GestureConfig, completion: @escaping (GestureResult) -> Void) {
        self.config = config
        self.completion = completion
    }
    
    func processMotion(_ motion: CMDeviceMotion) {
        let currentTime = Date().timeIntervalSince1970
        
        // Extract pitch and yaw from attitude
        let pitch = motion.attitude.pitch  // Forward/backward tilt
        let yaw = motion.attitude.yaw      // Left/right rotation
        
        // Smooth the values
        pitchHistory.append(pitch)
        yawHistory.append(yaw)
        if pitchHistory.count > smoothingWindow {
            pitchHistory.removeFirst()
            yawHistory.removeFirst()
        }
        
        let smoothedPitch = pitchHistory.reduce(0, +) / Double(pitchHistory.count)
        let smoothedYaw = yawHistory.reduce(0, +) / Double(yawHistory.count)
        
        // Set baseline on first reading
        if !hasBaseline {
            baselinePitch = smoothedPitch
            baselineYaw = smoothedYaw
            hasBaseline = true
            config.log("Baseline set - pitch: \(String(format: "%.2f", smoothedPitch)), yaw: \(String(format: "%.2f", smoothedYaw))")
            return
        }
        
        // Calculate relative changes from baseline
        let relativePitch = smoothedPitch - baselinePitch
        let relativeYaw = smoothedYaw - baselineYaw
        
        // Debug: Log pitch values when significant change detected
        if config.verbose && (abs(relativePitch) > 0.15 || abs(relativeYaw) > 0.15) {
            config.log("Motion - pitch: \(String(format: "%.2f", relativePitch)), yaw: \(String(format: "%.2f", relativeYaw))")
        }
        
        // Check for nod gesture (if enabled)
        if config.mode == .both || config.mode == .nodOnly {
            detectNod(relativePitch: relativePitch, currentTime: currentTime)
        }
        
        // Check for shake gesture (if enabled)
        if config.mode == .both || config.mode == .shakeOnly {
            detectShake(relativeYaw: relativeYaw, currentTime: currentTime)
        }
    }
    
    private func detectNod(relativePitch: Double, currentTime: TimeInterval) {
        // Check cooldown
        guard currentTime - lastNodGestureTime > config.cooldownPeriod else { return }
        
        switch nodState {
        case .idle:
            // Looking for downward pitch (negative relative pitch)
            if relativePitch < -config.nodPitchThreshold {
                nodState = .detectingDown
                nodStartTime = currentTime
                config.log("Nod: Down motion detected (pitch: \(String(format: "%.2f", relativePitch)))")
            }
            
        case .detectingDown:
            // Check timeout
            if currentTime - nodStartTime > config.gestureTimeWindow {
                config.log("Nod: Timeout in down state, resetting")
                nodState = .idle
                return
            }
            
            // Looking for return toward neutral (significant upward movement from down position)
            // We're looking for the head coming back up, not necessarily a positive pitch
            if relativePitch > -config.nodPitchThreshold * 0.3 {
                config.log("NOD DETECTED - User indicated YES (pitch returned: \(String(format: "%.2f", relativePitch)))")
                lastNodGestureTime = currentTime
                nodState = .idle
                completion(.nod)
            }
        }
    }
    
    private func detectShake(relativeYaw: Double, currentTime: TimeInterval) {
        // Check cooldown
        guard currentTime - lastShakeGestureTime > config.cooldownPeriod else { return }
        
        switch shakeState {
        case .idle:
            // Looking for left rotation (negative yaw)
            if relativeYaw < -config.shakeYawThreshold {
                shakeState = .detectingLeft
                shakeStartTime = currentTime
                config.log("Shake: Left rotation detected (yaw: \(String(format: "%.2f", relativeYaw)))")
            }
            // Or right rotation (positive yaw)
            else if relativeYaw > config.shakeYawThreshold {
                shakeState = .detectingRight
                shakeStartTime = currentTime
                config.log("Shake: Right rotation detected (yaw: \(String(format: "%.2f", relativeYaw)))")
            }
            
        case .detectingLeft:
            // Check timeout
            if currentTime - shakeStartTime > config.gestureTimeWindow {
                config.log("Shake: Timeout in left state, resetting")
                shakeState = .idle
                return
            }
            
            // Looking for right rotation to complete shake
            if relativeYaw > config.shakeYawThreshold {
                config.log("SHAKE DETECTED - User indicated NO")
                lastShakeGestureTime = currentTime
                completion(.shake)
            }
            
        case .detectingRight:
            // Check timeout
            if currentTime - shakeStartTime > config.gestureTimeWindow {
                config.log("Shake: Timeout in right state, resetting")
                shakeState = .idle
                return
            }
            
            // Looking for left rotation to complete shake
            if relativeYaw < -config.shakeYawThreshold {
                config.log("SHAKE DETECTED - User indicated NO")
                lastShakeGestureTime = currentTime
                completion(.shake)
            }
        }
    }
}
