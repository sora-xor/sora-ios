import Foundation

enum CryptoType: UInt8, Codable, CaseIterable {
    case sr25519
    case ed25519
    case ecdsa
    
    var googleIdentifier: String {
        switch self {
        case .sr25519: return "SR25519"
        case .ed25519: return "ED25519"
        case .ecdsa: return "ECDSA"
        }
    }
    
    init(googleIdentifier: String) {
        switch googleIdentifier {
        case "SR25519":
            self = .sr25519
        case "ED25519":
            self = .ed25519
        case "ECDSA":
            self = .ecdsa
        default:
            self = .sr25519
        }
    }
}

struct AccountItem: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case address
        case cryptoType
        case networkType
        case username
        case publicKeyData
        case settings
        case isSelected
        case order
    }

    let address: String
    let cryptoType: CryptoType
    let networkType: SNAddressType
    let username: String
    let publicKeyData: Data
    let settings: AccountSettings
    let isSelected: Bool
    let order: Int16

    public init(from decoder: Decoder) throws {
        let containter = try decoder.container(keyedBy: CodingKeys.self)
        address = try containter.decode(String.self, forKey: .address)
        cryptoType = try containter.decode(CryptoType.self, forKey: .cryptoType)
        networkType = try containter.decodeIfPresent(SNAddressType.self, forKey: .networkType) ?? ApplicationConfig.shared.addressType
        username = try containter.decode(String.self, forKey: .username)
        publicKeyData = try containter.decode(Data.self, forKey: .publicKeyData)
        settings = try containter.decodeIfPresent(AccountSettings.self, forKey: .settings) ?? AccountSettings(visibleAssetIds: [], orderedAssetIds: [])
        isSelected = try containter.decodeIfPresent(Bool.self, forKey: .isSelected) ?? false
        order = try containter.decodeIfPresent(Int16.self, forKey: .order) ?? 0
    }

    init(address: String,
         cryptoType: CryptoType,
         networkType: SNAddressType,
         username: String,
         publicKeyData: Data,
         settings: AccountSettings,
         order: Int16,
         isSelected: Bool) {
        self.address = address
        self.cryptoType = cryptoType
        self.networkType = networkType
        self.username = username
        self.publicKeyData = publicKeyData
        self.settings = settings
        self.isSelected = isSelected
        self.order = order
    }
}

extension AccountItem {
    init(managedItem: ManagedAccountItem) {
        self = AccountItem(address: managedItem.address,
                           cryptoType: managedItem.cryptoType,
                           networkType: managedItem.networkType,
                           username: managedItem.username,
                           publicKeyData: managedItem.publicKeyData,
                           settings: managedItem.settings,
                           order: managedItem.order,
                           isSelected: managedItem.isSelected)
    }

    var addressType: SNAddressType {
        ApplicationConfig.shared.addressType
    }

    func replacingUsername(_ newUsername: String) -> AccountItem {
        AccountItem(address: address,
                    cryptoType: cryptoType,
                    networkType: networkType,
                    username: newUsername,
                    publicKeyData: publicKeyData,
                    settings: settings,
                    order: order,
                    isSelected: isSelected)
    }

    func replacingSettings(_ newSettings: AccountSettings) -> AccountItem {
        AccountItem(address: address,
                    cryptoType: cryptoType,
                    networkType: networkType,
                    username: username,
                    publicKeyData: publicKeyData,
                    settings: newSettings,
                    order: order,
                    isSelected: isSelected)
    }
}
