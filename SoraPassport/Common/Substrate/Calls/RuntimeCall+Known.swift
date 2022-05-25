import Foundation
import FearlessUtils

extension RuntimeCall {
    static func bond(_ args: BondCall) -> RuntimeCall<BondCall> {
        RuntimeCall<BondCall>(moduleName: "Staking", callName: "bond", args: args)
    }

    static func nominate(_ args: NominateCall) -> RuntimeCall<NominateCall> {
        RuntimeCall<NominateCall>(moduleName: "Staking", callName: "nominate", args: args)
    }

    static func migrate(_ args: MigrateCall) -> RuntimeCall<MigrateCall> {
        RuntimeCall<MigrateCall>(moduleName: "IrohaMigration", callName: "migrate", args: args)
    }

    static func transfer(_ args: SoraTransferCall) -> RuntimeCall<SoraTransferCall> {
        RuntimeCall<SoraTransferCall>(moduleName: "Assets", callName: "transfer", args: args)
    }

    static func swap(_ args: SwapCall) -> RuntimeCall<SwapCall> {
        RuntimeCall<SwapCall>(moduleName: "LiquidityProxy", callName: "swap", args: args)
    }
}
