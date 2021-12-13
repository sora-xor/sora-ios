import Foundation

enum RemoteEnviroment: String, CaseIterable {
    case development = "dev"
    case test = "test"
    case staging = "stage"
    case release = ""
}
