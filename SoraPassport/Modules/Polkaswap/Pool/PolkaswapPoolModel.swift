import BigInt
import RobinHood
import UIKit

class PolkaswapPoolModel: NSObject {
    var delegate: PolkaswapPoolViewDelegate?

    private var models: [PolkaswapPoolCellModel] = []
    private var pools: [PoolDetails] = []
    private weak var tableView: UITableView?

    private var amountFormatterFactory: AmountFormatterFactoryProtocol

    init(tableView: UITableView, amountFormatterFactory: AmountFormatterFactoryProtocol) {
        self.amountFormatterFactory = amountFormatterFactory

        super.init()

        tableView.delegate = self
        tableView.dataSource = self

        self.tableView = tableView
    }

    func setPoolList(_ pools: [PoolDetails], locale: Locale) {
        let oldModels = models
        let oldPools = self.pools
        self.pools = pools
        models = pools.map { newPool in
            let newModel = poolModel(from: newPool, locale: locale)

            //expand cell if it was expanded before update
            let oldPool = oldPools.first { pool in
                pool.targetAsset == newPool.targetAsset
            }
            if oldPools.count == pools.count,
               let oldPool = oldPool,
               let index = oldPools.firstIndex(of: oldPool),
               oldModels[index].isExpanded {
                newModel.onExpand({_ in })
            }

            return newModel
        }

        guard let tableView = tableView else { return }
        UIView.performWithoutAnimation {
            tableView.reloadData()
        }
    }

    private var operationWrapper: CompoundOperationWrapper<[Data]>?

    private func poolModel(from poolDetails: PoolDetails, locale: Locale) -> PolkaswapPoolCellModel {//
        let formater = amountFormatterFactory.createPolkaswapAmountFormatter().value(for: locale)
        let percentageFormatter = amountFormatterFactory.createPercentageFormatter(maxPrecision: 8).value(for: locale)

        let poolShare = percentageFormatter.stringFromDecimal(poolDetails.yourPoolShare) ?? ""
        let bonusApy = formater.stringFromDecimal(Decimal(poolDetails.sbAPYL) * 100) ?? ""

        let baseAssetPoolled = formater.stringFromDecimal(poolDetails.baseAssetPooledByAccount) ?? ""

        let targetAssetPoolled = formater.stringFromDecimal(poolDetails.targetAssetPooledByAccount) ?? ""
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        let baseAsset = assetManager.assetInfo(for: poolDetails.baseAsset)
        let targetAsset = assetManager.assetInfo(for: poolDetails.targetAsset)

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
