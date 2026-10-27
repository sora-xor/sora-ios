import RobinHood
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFIndexers

enum BaseHistoryServiceError: Error {
    case fileNotFound(name: String)
}

class BaseHistoryServiceTestCase: XCTestCase {
    var networkWorker: NetworkWorker?
    var historyService: HistoryService?

    func chainAsset(
        blockExplorerType: BlockExplorerType,
        assetSymbol: String,
        precision: UInt16,
        ethereumType: EthereumAssetType?,
        contractaddress: String?
    ) -> ChainAsset {
        let historyBlockExplorer = ChainModel.BlockExplorer(
            type: blockExplorerType.rawValue,
            url: URL(string: "https://www.google.com")!,
            apiKey: ""
        )
        let externalApi = ChainModel.ExternalApiSet(history: historyBlockExplorer)

        let asset = AssetModel(
            id: contractaddress ?? "2",
            name: "asset name",
            symbol: assetSymbol,
            isUtility: true,
            precision: precision,
            substrateType: nil,
            ethereumType: ethereumType,
            tokenProperties:
                TokenProperties(
                    priceId: nil,
                    currencyId: nil,
                    color: nil,
                    type: .normal,
                    isNative: true
                ),
            price: nil,
            priceId: nil,
            coingeckoPriceId: nil,
            priceProvider: nil
        )

        let chain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: "1",
            parentId: "2",
            paraId: "test",
            name: "test",
            tokens: ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: [asset]),
            xcm: nil,
            nodes: [],
            types: nil,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            iosMinAppVersion: nil,
            properties: ChainProperties(addressPrefix: "1")
        )

        let chainAsset = ChainAsset(
            chain: chain,
            asset: asset
        )
        return chainAsset
    }

    func getResponse<T: Decodable>(file name: String) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw BaseHistoryServiceError.fileNotFound(name: name)
        }
        let data = try Data(contentsOf: url)
        let jsonDecoder = JSONDecoder()
        let value = try jsonDecoder.decode(T.self, from: data)
        return value
    }
}
