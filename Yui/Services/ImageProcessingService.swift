import AVFoundation
import CoreImage
import UIKit
import os.log

// MARK: - Протокол ImageProcessingServiceProtocol
protocol ImageProcessingServiceProtocol {
    func normalizeImage(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer?
}

class ImageProcessingService: ImageProcessingServiceProtocol {
    // MARK: - Константы
    private let targetSize = CGSize(width: 256, height: 256) // Входной размер для MediaPipe Pose Landmarker
    private let ciContext = CIContext(options: nil)
    
    // MARK: - Нормализация изображения
    func normalizeImage(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        os_log("ImageProcessingService: normalizeImage вызван", log: OSLog.default, type: .debug)
        
        // 1. Извлечение CVPixelBuffer из CMSampleBuffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            os_log("ImageProcessingService: Не удалось извлечь CVPixelBuffer из CMSampleBuffer", log: OSLog.default, type: .error)
            return nil
        }
        
        // 2. Преобразование в CIImage
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 3. Масштабирование изображения до целевого размера (256x256)
        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let scale = min(scaleX, scaleY) // Сохраняем пропорции
        ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // 4. Центрирование изображения (если после масштабирования размер не совпадает с целевым)
        let offsetX = (targetSize.width - ciImage.extent.width) / 2
        let offsetY = (targetSize.height - ciImage.extent.height) / 2
        ciImage = ciImage.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
        
        // 5. Обрезка до целевого размера
        ciImage = ciImage.cropped(to: CGRect(origin: .zero, size: targetSize))
        
        // 6. Преобразование цветового пространства в RGB (MediaPipe ожидает RGB)
        if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) {
            ciImage = ciImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ]).settingProperties([kCIImageColorSpace: colorSpace])
        }
        
        // 7. Нормализация значений пикселей (диапазон [0, 1])
        let normalizedImage = ciImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1/255, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1/255, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1/255, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
        
        // 8. Преобразование обратно в CVPixelBuffer
        var newPixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: Int(targetSize.width),
            kCVPixelBufferHeightKey as String: Int(targetSize.height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                           Int(targetSize.width),
                           Int(targetSize.height),
                           kCVPixelFormatType_32BGRA,
                           attributes as CFDictionary,
                           &newPixelBuffer)
        
        guard let outputPixelBuffer = newPixelBuffer else {
            os_log("ImageProcessingService: Не удалось создать новый CVPixelBuffer", log: OSLog.default, type: .error)
            return nil
        }
        
        ciContext.render(normalizedImage, to: outputPixelBuffer)
        
        // 9. Создание нового CMSampleBuffer
        var newSampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0, timingInfoOut: &timingInfo)
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                    imageBuffer: outputPixelBuffer,
                                                    formatDescriptionOut: &formatDescription)
        
        guard let finalFormatDescription = formatDescription else {
            os_log("ImageProcessingService: Не удалось создать CMFormatDescription", log: OSLog.default, type: .error)
            return nil
        }
        
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                imageBuffer: outputPixelBuffer,
                                                formatDescription: finalFormatDescription,
                                                sampleTiming: &timingInfo,
                                                sampleBufferOut: &newSampleBuffer)
        
        guard let resultSampleBuffer = newSampleBuffer else {
            os_log("ImageProcessingService: Не удалось создать новый CMSampleBuffer", log: OSLog.default, type: .error)
            return nil
        }
        
        os_log("ImageProcessingService: Изображение успешно нормализовано", log: OSLog.default, type: .debug)
        return resultSampleBuffer
    }
}
