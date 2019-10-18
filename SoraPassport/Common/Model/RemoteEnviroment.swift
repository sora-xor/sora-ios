import Foundation

enum RemoteEnviroment: String, CaseIterable {
    case development = "dev"
    case test = "tst"
    case staging = "stg"
    case release = ""
}
