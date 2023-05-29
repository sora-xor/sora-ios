import Foundation

protocol SwapMarketSourcerProtocol {
    init(fromAssetId: String, toAssetId: String)
    func getMarketSources() -> [LiquiditySourceType]
    func getMarketSource(at index: Int) -> LiquiditySourceType?
    func isEmpty() -> Bool
    func isLoaded() -> Bool
    func didLoad(_ serverMarketSources: [String])
    func getServerMarketSources() -> [String]
    func index(of marketSource: LiquiditySourceType) -> Int?
    func contains(_ marketSource: LiquiditySourceType) -> Bool
}

class SwapMarketSourcer: SwapMarketSourcerProtocol {
    private var marketSources: [LiquiditySourceType]?
    private var fromAssetId: String
    private var toAssetId: String

    required init(fromAssetId: String, toAssetId: String) {
        self.fromAssetId = fromAssetId
        self.toAssetId = toAssetId
    }

    func getMarketSources() -> [LiquiditySourceType] {
        return marketSources ?? []
    }

    func getMarketSource(at index: Int) -> LiquiditySourceType? {
        guard let marketSources = marketSources, index < marketSources.count else {
            return nil
        }
        return marketSources[index]
    }

    func isEmpty() -> Bool {
        return marketSources?.isEmpty ?? true
    }

    func isLoaded() -> Bool {
        return marketSources != nil
    }

    func didLoad(_ serverMarketSources: [String]) {
        setMarketSources(from: serverMarketSources)
        forceAddSmartMarketSourceIfNecessary()
        addSmartIfNotEmpty()
    }

    func setMarketSources(_ marketSources: [LiquiditySourceType]) {
        self.marketSources = marketSources
    }

    func setMarketSources(from serverMarketSources: [String]) {
        marketSources = serverMarketSources.compactMap({LiquiditySourceType(rawValue: $0)})
    }

    func forceAddSmartMarketSourceIfNecessary() {
        if isEmpty() {
            add(.smart)
        }
    }

    func isXSTUSD(_ assetId: String) -> Bool {
        return assetId == WalletAssetId.xstusd.rawValue
    }

    func add(_ marketSource: LiquiditySourceType) {
        marketSources?.append(marketSource)
    }

    func addSmartIfNotEmpty() {
        guard let marketSources = marketSources else { return }

        let notEmpty = !marketSources.isEmpty
        let hasNoSmart = !marketSources.contains(.smart)
        if notEmpty && hasNoSmart {
            add(.smart)
        }
    }

    func getServerMarketSources() -> [String] {
        let filteredMarketSources = marketSources?.filter({shouldSendToServer($0)}) ?? []
        return filteredMarketSources.map({ $0.rawValue })
    }

    func shouldSendToServer(_ markerSource: LiquiditySourceType) -> Bool {
        return markerSource != .smart
    }

    func index(of marketSource: LiquiditySourceType) -> Int? {
        return marketSources?.firstIndex(where: { $0 == marketSource })
    }

    func contains(_ marketSource: LiquiditySourceType) -> Bool {
        return index(of: marketSource) != nil
    }
}
