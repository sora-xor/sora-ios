import Foundation

struct ConstantCodingPath {
    let moduleName: String
    let constantName: String
}

extension ConstantCodingPath {
    static var slashDeferDuration: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "SlashDeferDuration")
    }

    static var maxNominatorRewardedPerValidator: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "MaxNominatorRewardedPerValidator")
    }

    static var existentialDeposit: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Balances", constantName: "ExistentialDeposit")
    }

    static var chainPrefix: ConstantCodingPath {
        ConstantCodingPath(moduleName: "System", constantName: "SS58Prefix")
    }

    static var assetInfos: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Assets", constantName: "AssetInfos")
    }
}
