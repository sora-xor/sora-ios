actor ClientVersionStorage {
    static let shared = ClientVersionStorage()

    var clientVersion: SCVersion?

    func set(clientVersion: SCVersion) {
        self.clientVersion = clientVersion
    }
}
