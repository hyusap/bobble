import Foundation
import CoreMotion

@available(macOS 14.0, *)
class MotionDetector {
    private let motionManager = CMHeadphoneMotionManager()
    private let config: GestureConfig
    private var gestureRecognizer: GestureRecognizer?
    private var timeoutTimer: DispatchSourceTimer?
    private let queue = OperationQueue()
    
    init(config: GestureConfig) {
        self.config = config
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }
    
    func start(completion: @escaping (GestureResult) -> Void) {
        // Check if headphone motion is available
        guard motionManager.isDeviceMotionAvailable else {
            config.log("Error: Headphone motion not available. Make sure AirPods Pro/Max or Beats Fit Pro are connected.")
            completion(.error)
            return
        }
        
        config.log("Headphone motion available, starting detection...")
        config.log("Waiting for gesture (timeout: \(Int(config.timeout))s)...")
        
        // Initialize gesture recognizer
        gestureRecognizer = GestureRecognizer(config: config) { [weak self] result in
            self?.stop()
            completion(result)
        }
        
        // Set up timeout
        setupTimeout(completion: completion)
        
        // Start receiving motion updates
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self = self else { return }
            
            if let error = error {
                self.config.log("Motion error: \(error.localizedDescription)")
                self.stop()
                completion(.error)
                return
            }
            
            guard let motion = motion else { return }
            
            // Pass motion data to gesture recognizer
            self.gestureRecognizer?.processMotion(motion)
        }
    }
    
    private func setupTimeout(completion: @escaping (GestureResult) -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + config.timeout)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.config.log("Timeout reached, no gesture detected")
            self.stop()
            completion(.timeout)
        }
        timer.resume()
        timeoutTimer = timer
    }
    
    func stop() {
        motionManager.stopDeviceMotionUpdates()
        timeoutTimer?.cancel()
        timeoutTimer = nil
    }
    
    deinit {
        stop()
    }
}
