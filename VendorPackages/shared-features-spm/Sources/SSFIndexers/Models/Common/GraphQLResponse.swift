import Foundation
import SSFUtils

public struct GraphQLErrors: Error, Decodable {
    struct GraphQLError: Error, Decodable {
        let message: String
    }

    let errors: [GraphQLError]
}

public enum GraphQLResponse<D: Decodable>: Decodable {
    case data(_ value: D)
    case errors(_ value: GraphQLErrors)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let json = try container.decode(JSON.self)

        if let data = json.data {
            let value = try data.map(to: D.self)
            self = .data(value)
        } else if let errors = json.errors {
            let values = try errors.map(to: [GraphQLErrors.GraphQLError].self)
            self = .errors(GraphQLErrors(errors: values))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }

    public func result() throws -> D {
        switch self {
        case let .errors(error):
            throw error
        case let .data(response):
            return response
        }
    }
}
