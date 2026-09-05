import Foundation

enum JSONResponseDecoderError: Error {
    case typeNotDecodable
}

final class JSONResponseDecoder: ResponseDecoder {
    private let jsonDecoder: JSONDecoder

    init(jsonDecoder: JSONDecoder = JSONDecoder()) {
        self.jsonDecoder = jsonDecoder
    }

    func decode<T: Decodable>(data: Data) throws -> T {
        try jsonDecoder.decode(T.self, from: data)
    }
}
