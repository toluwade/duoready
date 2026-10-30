import AVFoundation
import UIKit

/// Device orientation is the right input for capture rotation: no findings expected.
final class CameraController {
    let connection: AVCaptureConnection

    init(connection: AVCaptureConnection) {
        self.connection = connection
    }

    func updateRotation() {
        switch UIDevice.current.orientation {
        case .landscapeLeft: connection.videoOrientation = .landscapeRight
        case .landscapeRight: connection.videoOrientation = .landscapeLeft
        default: connection.videoOrientation = .portrait
        }
    }
}
