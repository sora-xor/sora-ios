import Foundation

public enum QRMatcherType {
    case qrInfo(QRInfoType)
    case walletConnect(String)
    case preinstalledWallet(String)

    public var address: String? {
        switch self {
        case let .qrInfo(qRInfoType):
            switch qRInfoType {
            case let .sora(soraQRInfo):
                return soraQRInfo.address
            case let .cex(cexQRInfo):
                return cexQRInfo.address
            case let .bokoloCash(qrInfo):
                return qrInfo.address
            case let .desiredCryptocurrency(qrInfo):
                return qrInfo.address
            }
        case .walletConnect, .preinstalledWallet:
            return nil
        }
    }

    public var qrInfo: QRInfoType? {
        switch self {
        case let .qrInfo(qRInfoType):
            return qRInfoType
        case .walletConnect, .preinstalledWallet:
            return nil
        }
    }

    public var uri: String? {
        switch self {
        case .qrInfo, .preinstalledWallet:
            return nil
        case let .walletConnect(uri):
            return uri
        }
    }

    public var preinstalledWallet: String? {
        switch self {
        case .qrInfo, .walletConnect:
            return nil
        case let .preinstalledWallet(preinstalledWallet):
            return preinstalledWallet
        }
    }
}
