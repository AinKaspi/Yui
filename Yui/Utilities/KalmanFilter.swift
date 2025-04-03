class KalmanFilter {
    private var state: Float
    private var uncertainty: Float
    private let processNoise: Float
    private let measurementNoise: Float
    
    init(initialState: Float, initialUncertainty: Float = 1.0, processNoise: Float = 0.1, measurementNoise: Float = 0.5) {
        self.state = initialState
        self.uncertainty = initialUncertainty
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
    }
    
    func update(measurement: Float) -> Float {
        let predictedState = state
        let predictedUncertainty = uncertainty + processNoise
        
        let kalmanGain = predictedUncertainty / (predictedUncertainty + measurementNoise)
        state = predictedState + kalmanGain * (measurement - predictedState)
        uncertainty = (1 - kalmanGain) * predictedUncertainty
        
        return state
    }
}
