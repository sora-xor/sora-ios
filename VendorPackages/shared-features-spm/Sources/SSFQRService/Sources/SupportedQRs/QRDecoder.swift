import Foundation

// sourcery: AutoMockable
public protocol QRDecoder {
    func decode(data: Data) throws -> QRInfoType
}

public final class QRDecoderDefault: QRDecoder {
    public static let defaultDecoders: [QRDecoder] = [
        BokoloCashDecoder(),
        SoraQRDecoder(),
        CexQRDecoder(),
        DesiredCryptocurrencyDecoder(),
    ]

    private let qrDecoders: [QRDecoder]

    public init(qrDecoders: [QRDecoder] = QRDecoderDefault.defaultDecoders) {
        self.qrDecoders = qrDecoders
    }

    public func decode(data: Data) throws -> QRInfoType {
        let types = qrDecoders.compactMap {
            try? $0.decode(data: data)
        }
        guard types.count == 1,
              let infoType = types.first else
        {
            throw QRDecoderError.manyCoincidence
        }

        return infoType
    }
}
