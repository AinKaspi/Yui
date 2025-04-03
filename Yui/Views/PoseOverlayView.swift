import UIKit
import MediaPipeTasksVision
import os.log

class PoseOverlayView: UIView {
    // MARK: - Свойства
    private var landmarks: [NormalizedLandmark]?
    
    // MARK: - Инициализация
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
    }
    
    // MARK: - Публичные методы
    func updateLandmarks(_ landmarks: [NormalizedLandmark]?) {
        self.landmarks = landmarks
        setNeedsDisplay() // Перерисовка
    }
    
    // MARK: - Отрисовка
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let landmarks = landmarks else {
            os_log("PoseOverlayView: Нет ключевых точек для отрисовки", log: OSLog.default, type: .debug)
            return
        }
        
        let screenWidth = bounds.width
        let screenHeight = bounds.height
        
        var points: [Int: CGPoint] = [:]
        
        // Отрисовка точек
        for (index, landmark) in landmarks.enumerated() {
            let visibility = landmark.visibility?.floatValue ?? 0.0
            let presence = landmark.presence?.floatValue ?? 0.0
            if visibility < 0.7 || presence < 0.7 {
                continue
            }
            
            let x = CGFloat(landmark.x)
            let y = CGFloat(landmark.y)
            
            if x < 0 || x > 1 || y < 0 || y > 1 {
                os_log("PoseOverlayView: Недопустимые координаты для точки %d: x=%f, y=%f", log: OSLog.default, type: .debug, index, x, y)
                continue
            }
            
            let rotatedX = 1.0 - x
            let rotatedY = y
            
            let scaledX = rotatedX * screenWidth
            let scaledY = rotatedY * screenHeight
            
            points[index] = CGPoint(x: scaledX, y: scaledY)
            
            // Отрисовка точки
            let pointPath = UIBezierPath(ovalIn: CGRect(x: scaledX - 2.5, y: scaledY - 2.5, width: 5, height: 5))
            UIColor.green.setFill()
            pointPath.fill()
        }
        
        // Отрисовка линий
        let connections: [(Int, Int)] = [
            (11, 12), (11, 23), (12, 24), (23, 24),
            (11, 13), (13, 15),
            (12, 14), (14, 16),
            (23, 25), (25, 27),
            (24, 26), (26, 28)
        ]
        
        for (startIndex, endIndex) in connections {
            guard let startPoint = points[startIndex], let endPoint = points[endIndex] else {
                continue
            }
            
            let linePath = UIBezierPath()
            linePath.move(to: startPoint)
            linePath.addLine(to: endPoint)
            
            UIColor.white.setStroke()
            linePath.lineWidth = 2.0
            linePath.stroke()
        }
    }
}
