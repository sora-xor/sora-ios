import Foundation
import IrohaCrypto

protocol WebSocketSubscribing {}

protocol WebSocketSubscriptionFactoryProtocol {
    func createStartSubscriptions(type: SNAddressType,
                                  engine: JSONRPCEngine) throws -> [WebSocketSubscribing]

    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing]
}
