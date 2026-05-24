import Foundation
import SSFModels

public struct SeedExportData {
    public let seed: Data
    public let derivationPath: String?
    public let chain: ChainModel
    public let cryptoType: CryptoType
}
