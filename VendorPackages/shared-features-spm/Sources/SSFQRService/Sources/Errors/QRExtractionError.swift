import Foundation
import UIKit

public enum QRExtractionError: Error {
    case invalidImage
    case detectorUnavailable
    case noFeatures
    case invalidQrCode
    case severalCoincidences
}
