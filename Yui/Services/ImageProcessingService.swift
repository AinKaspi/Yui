import AVFoundation
import CoreImage
import os.log

protocol ImageProcessingServiceProtocol {
    func scaleImage(_ sampleBuffer: CMSampleBuffer, scaleFactor: CGFloat) -> CMSampleBuffer?
    func normalizeImage(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer?
}

class ImageProcessingService: ImageProcessingServiceProtocol {
    private let ciContext = CIContext()
    
    func scaleImage(_ sampleBuffer: CMSampleBuffer, scaleFactor: CGFloat) -> CMSampleBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            os_log("ImageProcessingService: Не удалось получить pixelBuffer из sampleBuffer", log: OSLog.default, type: .error)
            return nil
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let newWidth = Int(CGFloat(width) * scaleFactor)
        let newHeight = Int(CGFloat(height) * scaleFactor)
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        
        var newPixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: newWidth,
            kCVPixelBufferHeightKey as String: newHeight
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, newWidth, newHeight, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &newPixelBuffer)
        guard status == kCVReturnSuccess, let outputPixelBuffer = newPixelBuffer else {
            os_log("ImageProcessingService: Не удалось создать новый pixelBuffer", log: OSLog.default, type: .error)
            return nil
        }
        
        ciContext.render(scaledImage, to: outputPixelBuffer)
        
        var newSampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0, timingInfoOut: &timingInfo)
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: outputPixelBuffer, formatDescriptionOut: &formatDescription)
        
        let createStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: outputPixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &newSampleBuffer
        )
        
        guard createStatus == kCVReturnSuccess, let finalSampleBuffer = newSampleBuffer else {
            os_log("ImageProcessingService: Не удалось создать новый sampleBuffer", log: OSLog.default, type: .error)
            return nil
        }
        
        return finalSampleBuffer
    }
    
    func normalizeImage(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        // Реализация нормализации будет добавлена позже
        return sampleBuffer
    }
}
