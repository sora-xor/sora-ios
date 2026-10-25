import Foundation

// import SSFUtils

public protocol ResponseDecodersFactory {
    func buildResponseDecoder(with type: ResponseDecoderType) -> any ResponseDecoder
}

public final class BaseResponseDecoderFactory: ResponseDecodersFactory {
    public init() {}

    public func buildResponseDecoder(with type: ResponseDecoderType) -> any ResponseDecoder {
        switch type {
        case let .codable(jsonDecoder):
            return JSONResponseDecoder(jsonDecoder: jsonDecoder)
        case let .custom(decoder):
            return decoder
        }
    }
}
