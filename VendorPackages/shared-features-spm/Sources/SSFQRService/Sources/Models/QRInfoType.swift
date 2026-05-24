import Foundation

public enum QRInfoType {
    case bokoloCash(BokoloCashQRInfo)
    case sora(SoraQRInfo)
    case cex(CexQRInfo)
    case desiredCryptocurrency(DesiredCryptocurrencyQRInfo)
}
