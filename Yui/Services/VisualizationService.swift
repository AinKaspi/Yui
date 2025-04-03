import UIKit
import MediaPipeTasksVision

class VisualizationService {
    private let overlayView: OverlayView
    
    init(overlayView: OverlayView) {
        self.overlayView = overlayView
    }
    
    func updateOverlay(with landmarks: [NormalizedLandmark]?) {
        overlayView.landmarks = landmarks ?? []
    }
}

class OverlayView: UIView {
    var landmarks: [NormalizedLandmark] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !landmarks.isEmpty else { return }
        
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(2.0)
        
        let connections: [(Int, Int)] = [
            (11, 13), (13, 15), // Left arm
            (12, 14), (14, 16), // Right arm
            (11, 23), (12, 24), // Shoulders to hips
            (23, 25), (25, 27), // Left leg
            (24, 26), (26, 28)  // Right leg
        ]
        
        for (startIdx, endIdx) in connections where startIdx < landmarks.count && endIdx < landmarks.count {
            let start = landmarks[startIdx]
            let end = landmarks[endIdx]
            
            let startX = CGFloat(start.x)
            let startY = CGFloat(start.y)
            let endX = CGFloat(end.x)
            let endY = CGFloat(end.y)
            
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: endX, y: endY))
        }
        
        context.strokePath()
    }
}
