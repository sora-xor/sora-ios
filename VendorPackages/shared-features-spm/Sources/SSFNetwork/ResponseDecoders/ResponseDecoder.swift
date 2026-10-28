import Foundation

public protocol ResponseDecoder {
    func decode<T: Decodable>(data: Data) throws -> T
}
