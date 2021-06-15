import FearlessUtils
import Foundation

extension Era {

    public static let defaultEraLength: UInt64 = 64

    public init(blockNumber: UInt64, eraLength: UInt64 = defaultEraLength) {
        var calPeriod = UInt64(pow(2.0, ceil(log2(Float(eraLength)))))
        calPeriod = min(1 << 16, max(calPeriod, 4))
        let phase = blockNumber % calPeriod
        let quantizeFactor = max(1, calPeriod >> 12)
        let quatizePhase = UInt64(phase / quantizeFactor * quantizeFactor)
//        var calPeriod = 2.0.pow(ceil(log2(periodInBlocks.toDouble()))).toInt()
//        calPeriod = min(1 shl 16, max(calPeriod, 4))
//        val phase = currentBlockNumber % calPeriod
//        val quantizeFactor = max(1, calPeriod shr 12)
//        val quantizePhase = phase / quantizeFactor * quantizeFactor
        self = Era.mortal(period: calPeriod, phase: quatizePhase)
    }
}
