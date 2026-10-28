import Foundation

public struct DesiredCryptocurrencyQRInfo: QRInfo, Equatable {
    public let assetName: String
    public let address: String
    public let amount: String?
}
