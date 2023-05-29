import Foundation
import RobinHood
import XNetworking

protocol ConfigServiceProtocol: AnyObject {
    var config: RemoteConfig { get }
    func setupConfig(completion: @escaping () -> Void)
}

struct RemoteConfig {
    var subqueryURL: URL
    var defaultNodes: Set<ChainNodeModel>
    var typesURL: URL?
    
    init(subqueryUrlString: String = ApplicationConfig.shared.subqueryUrl.absoluteString,
         typesUrlString: String = ApplicationConfig.shared.subqueryUrl.absoluteString,
         defaultNodes: Set<ChainNodeModel> = ApplicationConfig.shared.defaultChainNodes) {
        self.subqueryURL = URL(string: subqueryUrlString) ?? ApplicationConfig.shared.subqueryUrl
        self.typesURL = URL(string: typesUrlString)
        self.defaultNodes = defaultNodes
    }
}

final class ConfigService {
    static let shared = ConfigService()
    private let operationManager: OperationManager = OperationManager()
    var config: RemoteConfig = RemoteConfig()
}

extension ConfigService: ConfigServiceProtocol {
    
    func setupConfig(completion: @escaping () -> Void) {
        let queryOperation = SubqueryConfigInfoOperation<SoraConfig>()
        
        queryOperation.completionBlock = { [weak self] in
            guard let self = self, let response = try? queryOperation.extractNoCancellableResultData() else {
                completion()
                return
            }
            let nodes: Set<ChainNodeModel> = Set(response.nodes.compactMap({ node in
                guard let url = URL(string: node.address) else { return nil }
                return ChainNodeModel(url: url, name: node.name, apikey: nil)
            }))
            self.config = RemoteConfig(subqueryUrlString: response.blockExplorerUrl,
                                       typesUrlString: response.substrateTypesUrl,
                                       defaultNodes: nodes)
            completion()
        }
        
        operationManager.enqueue(operations: [queryOperation], in: .blockAfter)
    }
}
