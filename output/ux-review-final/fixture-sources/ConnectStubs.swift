import UIKit
import Foundation

enum NetworkId { case sora2, taira, minamoto }
struct IrohaConnectLaunch { let networkId: NetworkId = .taira; let receivedAt = Date(); let webSocketURL = URL(string:"ws://127.0.0.1")!; let webSocketProtocol = "fixture" }
struct IrohaConnectWalletContext { let accountId: String }
struct IrohaConnectAppMetadata { let name: String; let url: String?; let iconHash: String? }
struct IrohaConnectPermissions { let methods: [String]; let resources: [String]? }
enum IrohaConnectError: Error { case expired }
final class IrohaConnectWalletProvider { func sign(_ bytes:Data, context:IrohaConnectWalletContext) throws -> Data { fatalError("The visual fixture has no signer") } }
final class IrohaConnectAuthenticator { func authenticate(reason:String,completion:@escaping (Result<Void,Error>)->Void) { completion(.failure(IrohaConnectError.expired)) } }
final class IrohaConnectWebSocket {
 var onOpen:(()->Void)?;var onData:((Data)->Void)?;var onClosed:((String)->Void)?;var onFailure:((Error)->Void)?
 init(url:URL,protocol:String){};func connect(){ fatalError("The visual fixture must not open a relay") };func send(_ data:Data){};func cancel(){}
}
final class IrohaConnectSessionEngine {
 enum Event { case open(metadata:IrohaConnectAppMetadata?,permissions:IrohaConnectPermissions?);case signingRequest(IrohaConnectSigningRequest);case display(title:String,body:String);case closed(String);case none }
 struct Result { let event:Event;let outbound:[Data] }
 static let approvalLifetime:Double=120;static let requestLifetime:Double=120
 var pendingRequest:IrohaConnectSigningRequest?
 init(launch:IrohaConnectLaunch){}
 func receive(_ data:Data)throws->Result { Result(event:.none,outbound:[]) }
 func close(reason:String)->Data? { nil }
 func rejectPendingSignature()throws->Data { Data() }
 func rejectPairing()throws->Data? { nil }
 func approve(account:IrohaConnectWalletContext,signer:(Data)throws->Data)throws->Data { fatalError("No signing in fixture") }
 func approvePendingSignature(account:IrohaConnectWalletContext,signer:(Data)throws->Data)throws->Data { fatalError("No signing in fixture") }
}
enum IrohaConnectSigningRequest: Equatable {
    case raw(domain: String, bytes: Data)
    case transaction(bytes: Data)

    var bytes: Data {
        switch self {
        case let .raw(_, bytes), let .transaction(bytes): return bytes
        }
    }
}

/// A signature may be offered only when its entire meaning can be displayed.
/// Opaque transactions require a qualified transaction decoder, not app-supplied metadata.
struct IrohaConnectSigningReview {
    let request: IrohaConnectSigningRequest
    static let maximumMessageBytes = 4096

    var readableMessage: String? {
        guard case let .raw(_, bytes) = request,
              !bytes.isEmpty, bytes.count <= Self.maximumMessageBytes,
              let text = String(data: bytes, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !text.unicodeScalars.contains(where: { scalar in
                  scalar.properties.generalCategory == .format ||
                      (CharacterSet.controlCharacters.contains(scalar) && scalar.value != 10 && scalar.value != 9)
              }) else { return nil }
        return text
    }

    var canSign: Bool { readableMessage != nil }
    var unavailableReason: String {
        switch request {
        case .transaction:
            return "This wallet cannot yet explain this transaction's actions, recipients, amounts, or permissions. It cannot be signed here. Return to the app and use a supported transfer flow."
        case .raw:
            return "This message cannot be shown completely as readable text. It cannot be signed here. Ask the app for a readable message."
        }
    }
}

