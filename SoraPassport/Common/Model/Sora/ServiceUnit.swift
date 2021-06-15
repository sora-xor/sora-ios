import Foundation
//import SoraCrypto

//struct ServiceUnit: Equatable, Codable {
//    enum CodingKeys: String, CodingKey {
//        case typeMapping = "typeMapping"
//        case document = "ddo"
//    }
//
//    var typeMapping: [String: String]
//    var document: DecentralizedDocumentObject
//}
//
//extension ServiceUnit {
//    func service(for type: String) -> DDOService? {
//        let resolvedType = self.typeMapping[type] ?? type
//        return document.service?.first { $0.type == resolvedType }
//    }
//}
