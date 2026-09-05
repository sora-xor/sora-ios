import Foundation
import SSFCrypto

final class CexQREncoder {
    func encode(address: String) throws -> Data {
        guard let data = address.data(using: .utf8) else {
            throw QREncoderError.brokenData
        }
        return data
    }
}

final class CexQRDecoder: QRDecoder {
    func decode(data: Data) throws -> QRInfoType {
        guard let address = String(data: data, encoding: .utf8) else {
            throw QRDecoderError.brokenFormat
        }

        let substrateAccountId = try? address.toAccountIdWithTryExtractPrefix()
        let ethereumAccountId = try? address.toAccountIdWithTryExtractPrefix()

        let isSubstrateValid = substrateAccountId != nil && substrateAccountId?
            .count == AddressFactory.Constants.substrateAccountIdLehgth
        let isEthereumValid = ethereumAccountId != nil && ethereumAccountId?.count == AddressFactory
            .Constants.ethereumAccountIdLength

        guard isSubstrateValid || isEthereumValid else {
            throw QRDecoderError.brokenFormat
        }

        return .cex(CexQRInfo(address: address))
    }
}
