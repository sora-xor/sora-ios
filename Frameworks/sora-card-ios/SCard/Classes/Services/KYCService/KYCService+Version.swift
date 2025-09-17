extension KYCService {

    enum VersionChanges {
        case none
        case patch
        case minor
        case major
    }

    func version() async -> SCVersion? {
        if await ClientVersionStorage.shared.clientVersion == nil {
            _ = await fetchVersion()
        }
        return await ClientVersionStorage.shared.clientVersion
    }

    func fetchVersion() async -> Result<SCVersion, NetworkingError> {
        let request = APIRequest(method: .get, endpoint: SCEndpoint.version)
        let result: Result<SCVersion, NetworkingError> = await client.performDecodable(
            request: request,
            withAuthorization: false
        )

        switch result {
        case .success(let respose):
            await ClientVersionStorage.shared.set(clientVersion: respose)
        case .failure(let error):
            print(error)
        }
        return result
    }

    func verionsChangesNeeded() async -> VersionChanges {

        guard let iosClientVersion = await version()?.iosClientVersion else { return .none }

        let neededVersionParts = iosClientVersion.split(separator: ".").map { Int($0) ?? 0 }
        let currentVersionParts = SCard.currentSDKVersion.split(separator: ".").map { Int($0) ?? 0 }
        guard neededVersionParts.count == 3, currentVersionParts.count == 3 else { return .none }

        if neededVersionParts[0] > currentVersionParts[0] {
            return .major
        }

        if neededVersionParts[1] > currentVersionParts[1] {
            return .minor
        }

        if neededVersionParts[2] > currentVersionParts[2] {
            return .patch
        }

        return .none
    }
}

struct SCVersion: Codable {
    let iosClientVersion: String
    let androidSoraClientVersion: String
    let androidFearlessClientVersion: String
    let apiVersion: String
    let buildTimestamp: String
    let gitPretty: String

    enum CodingKeys: String, CodingKey {
        case iosClientVersion = "ios_client_version"
        case androidSoraClientVersion = "android_sora_client_version"
        case androidFearlessClientVersion = "android_fearless_client_version"
        case apiVersion = "api_version"
        case buildTimestamp = "build_timestamp"
        case gitPretty = "git_pretty"
    }
}
