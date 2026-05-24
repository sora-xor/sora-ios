import Foundation

final class DesiredCryptocurrencyDecoder: QRDecoder {
    enum Constants {
        static let componentsRange: ClosedRange = 2 ... 3
    }

    func decode(data: Data) throws -> QRInfoType {
        guard let decodedString = String(data: data, encoding: .utf8) else {
            throw QRDecoderError.brokenFormat
        }

        let components = decodedString.components(separatedBy: [":", "?"])

        guard Constants.componentsRange.contains(components.count) else {
            throw QRDecoderError.brokenFormat
        }

        let assetName = components[0]
        let address = components[1]
        var amount: String?

        guard let data = address.data(using: .utf8) else {
            throw QRDecoderError.brokenFormat
        }
        let cexDecoder = CexQRDecoder()
        let _ = try cexDecoder.decode(data: data)

        let amountString = components.indices.contains(2) ? components[2] : nil
        let amountComponents = amountString?.components(separatedBy: "=")
        if let amountComponents,
           amountComponents.count == 2,
           amountComponents.contains("amount")
        {
            amount = amountComponents[1]
        }

        let qrInfo = DesiredCryptocurrencyQRInfo(
            assetName: assetName,
            address: address,
            amount: amount
        )

        return .desiredCryptocurrency(qrInfo)
    }
}
