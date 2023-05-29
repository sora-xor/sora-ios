import Foundation

struct NodesResponse: Decodable {
    var nodes: [ChainNodeModel]

    enum CodingKeys: String, CodingKey {
        case nodes = "DEFAULT_NETWORKS"
    }
}
