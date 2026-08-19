// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SSFUtils
import RobinHood

struct SubqueryErrors: Error, Decodable {
    struct SubqueryError: Error, Decodable {
        let message: String
    }

    let errors: [SubqueryError]
}

enum SubqueryResponse<D: Decodable>: Decodable {
    case data(_ value: D)
    case errors(_ value: SubqueryErrors)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let json = try container.decode(JSON.self)

        if let data = json.data {
            let value = try data.map(to: D.self)
            self = .data(value)
        } else if let errors = json.errors {
            let values = try errors.map(to: [SubqueryErrors.SubqueryError].self)
            self = .errors(SubqueryErrors(errors: values))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }
}

struct SoraIndexerPageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

struct SoraIndexerConnection<Node: Decodable>: Decodable {
    let nodes: [Node]
    let pageInfo: SoraIndexerPageInfo
}

struct SoraIndexerEntitiesPayload<Node: Decodable>: Decodable {
    let entities: SoraIndexerConnection<Node>
}

enum SoraIndexerClientError: Error {
    case invalidResponse
    case httpStatus(Int)
    case responseTooLarge
    case timedOut
    case invalidPagination
    case resultTypeMismatch
}

private final class SoraIndexerResponseBox {
    var result: Result<Data, Error>?
}

enum SoraIndexerClient {
    static let maximumResponseSize = 10 * 1_024 * 1_024
    static let maximumPages = 100

    static func fetchEntities<Node: Decodable>(
        from url: URL,
        query: (String) -> String
    ) throws -> [Node] {
        var cursor = ""
        var seenCursors: Set<String> = []
        var nodes: [Node] = []

        for pageIndex in 0..<maximumPages {
            let requestQuery = query(cursor)
            let payload: SoraIndexerEntitiesPayload<Node> = try execute(
                url: url,
                query: requestQuery
            )
            nodes.append(contentsOf: payload.entities.nodes)

            guard payload.entities.pageInfo.hasNextPage else {
                Logger.shared.info(
                    "SORA indexer query succeeded: \(queryName(from: requestQuery)), " +
                    "pages=\(pageIndex + 1), host=\(url.host ?? "unknown host")"
                )
                return nodes
            }
            guard let nextCursor = payload.entities.pageInfo.endCursor,
                  !nextCursor.isEmpty,
                  seenCursors.insert(nextCursor).inserted else {
                throw SoraIndexerClientError.invalidPagination
            }
            cursor = nextCursor
        }

        throw SoraIndexerClientError.invalidPagination
    }

    static func failureCategory(for error: Error) -> String {
        if let indexerError = error as? SoraIndexerClientError {
            switch indexerError {
            case .invalidResponse:
                return "invalid-response"
            case let .httpStatus(statusCode):
                return "http-\(statusCode)"
            case .responseTooLarge:
                return "response-too-large"
            case .timedOut:
                return "timed-out"
            case .invalidPagination:
                return "invalid-pagination"
            case .resultTypeMismatch:
                return "result-type-mismatch"
            }
        }

        if error is SubqueryErrors {
            return "graphql"
        }
        if error is DecodingError {
            return "decoding"
        }
        if let urlError = error as? URLError {
            return "transport-\(urlError.errorCode)"
        }

        return "unknown"
    }

    private static func queryName(from query: String) -> String {
        let tokens = query.split(whereSeparator: { $0.isWhitespace })
        guard tokens.count >= 2, tokens[0] == "query" else {
            return "anonymous"
        }

        let candidate = tokens[1].filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return candidate.isEmpty ? "anonymous" : String(candidate.prefix(64))
    }

    static func execute<Response: Decodable>(
        url: URL,
        query: String,
        timeout: TimeInterval = 20
    ) throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = HttpMethod.post.rawValue
        request.timeoutInterval = timeout
        request.setValue(
            HttpContentType.json.rawValue,
            forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
        )
        request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

        let semaphore = DispatchSemaphore(value: 0)
        let box = SoraIndexerResponseBox()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                box.result = .failure(error)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                box.result = .failure(SoraIndexerClientError.invalidResponse)
                return
            }
            guard response.statusCode == 200 else {
                box.result = .failure(SoraIndexerClientError.httpStatus(response.statusCode))
                return
            }
            guard let data else {
                box.result = .failure(SoraIndexerClientError.invalidResponse)
                return
            }
            guard data.count <= maximumResponseSize else {
                box.result = .failure(SoraIndexerClientError.responseTooLarge)
                return
            }
            box.result = .success(data)
        }
        task.resume()

        guard semaphore.wait(timeout: .now() + timeout + 2) == .success else {
            task.cancel()
            throw SoraIndexerClientError.timedOut
        }
        guard let result = box.result else {
            throw SoraIndexerClientError.invalidResponse
        }
        let data = try result.get()

        let response = try JSONDecoder().decode(SubqueryResponse<Response>.self, from: data)
        switch response {
        case let .data(payload):
            return payload
        case let .errors(errors):
            throw errors
        }
    }
}
