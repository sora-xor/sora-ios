import CommonWallet

extension WalletAsset {
    var icon: UIImage? {
        switch self.symbol {
        case String.xor:
            return R.image.assetXor()
        case String.val:
            return R.image.assetVal()
        case String.eth:
            return R.image.assetValErc()
        default:
            return UIImage()

        }
    }

    var type: WalletAssetId {
        return WalletAssetId(rawValue: self.identifier)!
    }
}
