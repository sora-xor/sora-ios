import Foundation

public enum NetworkRequestType {
    case plain
    case multipart
    case custom(configurator: RequestConfigurator)
}
