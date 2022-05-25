import BigInt
import CommonWallet
import RobinHood
import UIKit

class PolkaswapPoolModel: NSObject {
    var delegate: PolkaswapPoolViewDelegate?

    private var models: [PolkaswapPoolCellModel] = []
    private var pools: [PoolDetails] = []
    private weak var tableView: UITableView?

    init(tableView: UITableView) {
        super.init()

        tableView.delegate = self
        tableView.dataSource = self

        self.tableView = tableView
    }

    func setPoolList(_ pools: [PoolDetails]) {
        self.pools = pools
        models = pools.map { poolModel(from: $0) }
        tableView?.reloadData()
    }

    private var operationWrapper: CompoundOperationWrapper<[Data]>?

    private func poolModel(from poolDetails: PoolDetails) -> PolkaswapPoolCellModel {
        let formater = NumberFormatter.decimalFormatter(
            precision: 7,
            rounding: .halfUp,
            usesIntGrouping: false
        )

        let poolShare = "\(NumberFormatter.poolShare.stringFromDecimal(Decimal(poolDetails.yourPoolShare)) ?? "0.0")%"

        let bonusApy = "\(formater.stringFromDecimal(Decimal(poolDetails.sbAPYL) * 100) ?? "0.0")%"

        let baseAssetPoolled = formater.stringFromDecimal(Decimal.fromSubstrateAmount(
            BigUInt(poolDetails.xorPooled),
            precision: 18
        ) ?? .zero) ?? "0.0"

        let targetAssetPoolled = formater.stringFromDecimal(Decimal.fromSubstrateAmount(
            BigUInt(poolDetails.targetAssetPooled),
            precision: 18
        ) ?? .zero) ?? "0.0"

        let baseAsset = AssetManager.shared.assetInfo(for: WalletAssetId.xor.rawValue)
        let targetAsset = AssetManager.shared.assetInfo(for: poolDetails.targetAsset)

        return .init(
            poolShare: poolShare,
            bonusApy: bonusApy,
            baseAssetPoolled: baseAssetPoolled,
            targetAssetPoolled: targetAssetPoolled,
            baseAssetFee: "",
            targetAssetFee: "",
            baseAssetInfo: baseAsset,
            targetAssetInfo: targetAsset,
            details: poolDetails,
            onAddLiquidy: { [unowned self] poolDetails in
                self.delegate?.onAdd(pool: poolDetails)
            },
            onRemoveLiquidy: { [unowned self] poolDetails in
                self.delegate?.onRemove(pool: poolDetails)
            },
            onExpand: { [weak tableView] in
                tableView?.beginUpdates()
                tableView?.endUpdates()
            }
        )
    }
}

extension PolkaswapPoolModel: UITableViewDelegate {
}

extension PolkaswapPoolModel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.register(PolkaswapPoolCell.self, forCellReuseIdentifier: PolkaswapPoolCell.cellId)
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PolkaswapPoolCell.cellId,
            for: indexPath
        ) as? PolkaswapPoolCell else { return UITableViewCell() }

        guard models.indices.contains(indexPath.row) else { return UITableViewCell() }

        cell.configure(viewModel: models[indexPath.row])
        return cell
    }
}
