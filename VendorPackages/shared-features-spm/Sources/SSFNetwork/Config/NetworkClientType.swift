import Foundation

public enum NetworkClientType {
    case plain
    case custom(client: NetworkClient)
}
