import UIKit
import MediaPipeTasksVision
import os.log

class PoseOverlayView: UIView {
    // MARK: - Свойства
    private var visualLandmarks: [VisualLandmark] = []
    private var previousLandmarks: [VisualLandmark] = []
    private var animationProgress: CGFloat = 0.0
    private var isAnimatingRepetition: Bool = false
    private var isCorrectPose: Bool = true
    
    // MARK: - Инициализация
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Обновление лендмарков
    func updateVisualLandmarks(visualLandmarks: [VisualLandmark], previousLandmarks: [VisualLandmark], animationProgress: CGFloat, isAnimatingRepetition: Bool, isCorrectPose: Bool) {
        os_log("PoseOverlayView: updateVisualLandmarks вызван", log: OSLog.default, type: .debug)
        self.visualLandmarks = visualLandmarks
        self.previousLandmarks = previousLandmarks
        self.animationProgress = animationProgress
        self.isAnimatingRepetition = isAnimatingRepetition
        self.isCorrectPose = isCorrectPose
        setNeedsDisplay()
    }
    
    // MARK: - Отрисовка
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.clear(rect)
        
        // Определяем текущие позиции с учётом анимации
        let currentLandmarks = visualLandmarks.enumerated().map { (index, landmark) -> VisualLandmark in
            guard index < previousLandmarks.count else { return landmark }
            let prev = previousLandmarks[index]
            let interpolatedX = prev.position.x + (landmark.position.x - prev.position.x) * animationProgress
            let interpolatedY = prev.position.y + (landmark.position.y - prev.position.y) * animationProgress
            return VisualLandmark(
                position: CGPoint(x: interpolatedX * bounds.width, y: interpolatedY * bounds.height),
                visibility: landmark.visibility,
                isActive: landmark.isActive,
                color: landmark.color
            )
        }
        
        // Отрисовка лендмарков
        for landmark in currentLandmarks {
            guard landmark.visibility > 0.5 else { continue }
            
            let point = landmark.position
            let radius: CGFloat = landmark.isActive ? 7 : 5
            let alpha: CGFloat = isAnimatingRepetition ? (sin(animationProgress * .pi) * 0.5 + 0.5) : 1.0
            
            context.setFillColor(landmark.color.withAlphaComponent(alpha).cgColor)
            context.addArc(center: point, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            context.fillPath()
        }
        
        // Отрисовка линий
        let connections: [(Int, Int)] = [
            (11, 12), (11, 13), (13, 15), (12, 14), (14, 16), // Верхняя часть тела
            (11, 23), (12, 24), (23, 24), // Таз
            (23, 25), (25, 27), (24, 26), (26, 28) // Ноги
        ]
        
        for (startIdx, endIdx) in connections {
            guard startIdx < currentLandmarks.count, endIdx < currentLandmarks.count else { continue }
            let startLandmark = currentLandmarks[startIdx]
            let endLandmark = currentLandmarks[endIdx]
            
            guard startLandmark.visibility > 0.5, endLandmark.visibility > 0.5 else { continue }
            
            let startPoint = startLandmark.position
            let endPoint = endLandmark.position
            
            let isActiveConnection = startLandmark.isActive && endLandmark.isActive
            let lineColor = isCorrectPose ? (isActiveConnection ? UIColor.green : UIColor.white) : UIColor.orange
            let lineWidth: CGFloat = isActiveConnection ? 3 : 2
            
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
        
        // Отрисовка углов (например, угол колена для приседаний)
        let angleConnections: [(Int, Int, Int)] = [
            (23, 25, 27), // Левый таз - левое колено - левая лодыжка
            (24, 26, 28)  // Правый таз - правое колено - правая лодыжка
        ]
        
        for (p1Idx, p2Idx, p3Idx) in angleConnections {
            guard p1Idx < currentLandmarks.count, p2Idx < currentLandmarks.count, p3Idx < currentLandmarks.count else { continue }
            let p1 = currentLandmarks[p1Idx]
            let p2 = currentLandmarks[p2Idx]
            let p3 = currentLandmarks[p3Idx]
            
            guard p1.visibility > 0.5, p2.visibility > 0.5, p3.visibility > 0.5 else { continue }
            
            let angle = calculateAngle(point1: p1.position, point2: p2.position, point3: p3.position)
            let textPoint = CGPoint(x: p2.position.x + 20, y: p2.position.y)
            
            let angleText = String(format: "%.0f°", angle)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: isCorrectPose ? UIColor.white : UIColor.orange
            ]
            angleText.draw(at: textPoint, withAttributes: attributes)
        }
    }
    
    // MARK: - Вспомогательные методы
    private func calculateAngle(point1: CGPoint, point2: CGPoint, point3: CGPoint) -> Float {
        let vector1 = (x: point1.x - point2.x, y: point1.y - point2.y)
        let vector2 = (x: point3.x - point2.x, y: point3.y - point2.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        guard magnitude1 > 0, magnitude2 > 0 else { return 0 }
        
        let cosTheta = dotProduct / (magnitude1 * magnitude2)
        let angleRad = acos(min(max(cosTheta, -1), 1))
        return Float(angleRad * 180 / .pi) // Переводим в градусы
    }
}
