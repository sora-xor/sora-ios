import Foundation

struct EthNodeData: Codable {
    let ethereumPassword: String
    let ethereumURL: String
    let etherscanBaseUrl: String
    let ethereumUsername, masterContractAddress: String

    enum CodingKeys: String, CodingKey {
        case ethereumPassword
        case ethereumURL = "ethereumUrl"
        case ethereumUsername, masterContractAddress, etherscanBaseUrl
    }
}
