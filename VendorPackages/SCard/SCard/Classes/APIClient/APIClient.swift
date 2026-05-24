import Foundation
import PayWingsOAuthSDK

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct HTTPHeader: Equatable {
    let field: String
    let value: String
}

protocol Endpoint {
    var path: String { get }
}

protocol BearerProvider {
    func bearer(url: String, method: HttpRequestMethod) async -> String?
}

final class APIRequest {
    let method: HTTPMethod
    let endpoint: Endpoint
    var queryItems: [URLQueryItem]?
    var headers: [HTTPHeader]?
    var body: Data?

    init(method: HTTPMethod, endpoint: Endpoint) {
        self.method = method
        self.endpoint = endpoint
    }

    init(
        method: HTTPMethod,
        endpoint: Endpoint,
        body: Data
    ) {
        self.method = method
        self.endpoint = endpoint
        self.body = body
    }
}

extension APIRequest: Hashable {
    static func == (lhs: APIRequest, rhs: APIRequest) -> Bool {
        lhs.method == rhs.method &&
        lhs.endpoint.path == rhs.endpoint.path &&
        lhs.queryItems == rhs.queryItems &&
        lhs.headers == rhs.headers &&
        lhs.body == rhs.body
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(endpoint.path)
    }
}

actor APIClient {

    init(
        baseURL: URL,
        baseAuth: String,
        bearerProvider: BearerProvider?,
        logLevels: NetworkingLogLevel = .debug
    ) {
        self.baseURL = baseURL
        self.baseAuth = baseAuth
        self.bearerProvider = bearerProvider
        self.logger.logLevels = logLevels
        self.headers = [
            .init(field: "appName", value: Bundle.main.appName),
            .init(field: "displayName", value: Bundle.main.displayName),
            .init(field: "language", value: Bundle.main.language),
            .init(field: "appBuild", value: Bundle.main.appBuild),
            .init(field: "appVersionLong", value: Bundle.main.appVersionLong),
        ]
    }

    private let apiKey = ""
    private let baseAuth: String
    private let baseURL: URL
    private let headers: [HTTPHeader]

    private let bearerProvider: BearerProvider?
    private let session = URLSession.shared
    private let logger = NetworkingLogger()

    private var cache: [APIRequest: CacheEntry] = [:]

    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-mm-dd"
        jsonDecoder.dateDecodingStrategy = .formatted(dateFormatter)
        return jsonDecoder
    }()

    func performDecodable<T: Decodable>(
        request: APIRequest,
        withAuthorization: Bool = true
    ) async -> Result<T, NetworkingError> {
        let result = await perform(request: request, withAuthorization: withAuthorization)

        switch result {
        case let .success(data):
            do {
                let decodedData = try jsonDecoder.decode(T.self, from: data)
                return .success(decodedData)
            } catch let error {
                print(error)
                return .failure(.init(status: .cannotDecodeRawData))
            }
        case let .failure(error):
            return .failure(error)
        }
    }

    private enum CacheEntry {
        case inProgress(Task<(Data, URLResponse), Error>)
        case ready(Data)
    }

    func perform(request: APIRequest, withAuthorization: Bool) async -> Result<Data, NetworkingError> {

        if let cached = cache[request] {
            switch cached {
            case .ready(let data):
                /// cache return .success(data)
                cache[request] = nil
            case .inProgress(let task):
                do {
                    let (data, response) = try await task.value
                    return processDataResponse(data: data, response: response)
                } catch let error as NSError {
                    return .failure(.init(errorCode: error.code))
                }
            }
        }

        guard var urlRequest = prepareURLRequest(request: request) else {
            return .failure(.init(status: .badURL))
        }

        if withAuthorization {
            guard let accessToken = await bearerProvider?.bearer(
                url: request.endpoint.path,
                method: request.method.pwMethod
            ) else {
                return .failure(NetworkingError.unauthorized)
            }
            urlRequest.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        }

        let task = Task { [urlRequest] in
            try await session.data(for: urlRequest)
        }

        cache[request] = .inProgress(task)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await task.value
            logger.log(response: response, data: data)
        } catch (let error as NSError) {
            cache[request] = nil
            return .failure(.init(errorCode: error.code))
        }

        cache[request] = .ready(data)
        return processDataResponse(data: data, response: response)
    }

    private func prepareURLRequest(request: APIRequest) -> URLRequest? {
        var urlComponents = URLComponents()
        urlComponents.scheme = baseURL.scheme
        urlComponents.host = baseURL.host
        urlComponents.port = baseURL.port
        urlComponents.path = baseURL.path
        if !apiKey.isEmpty {
            urlComponents.queryItems = (request.queryItems ?? []) + [URLQueryItem(name: "api_key", value: apiKey)]
        } else {
            urlComponents.queryItems = request.queryItems
        }

        guard let url = urlComponents.url?.appendingPathComponent(request.endpoint.path) else {
            return nil
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        (headers + (request.headers ?? [])).forEach {
            urlRequest.addValue($0.value, forHTTPHeaderField: $0.field)
        }
        return urlRequest
    }

    private func processDataResponse(
        data: Data,
        response: URLResponse
    ) -> Result<Data, NetworkingError> {

        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            return .failure(.init(status: .unknown))
        }
        guard 200 ..< 299 ~= statusCode else {
            return .failure(.init(errorCode: statusCode))
        }

        return .success(data)
    }
}

extension Bundle {
    public var appName: String { getInfo("CFBundleName")  }
    public var displayName: String { getInfo("CFBundleDisplayName")}
    public var language: String { getInfo("CFBundleDevelopmentRegion")}
    public var identifier: String { getInfo("CFBundleIdentifier")}
    public var appBuild: String { getInfo("CFBundleVersion") }
    public var appVersionLong: String { getInfo("CFBundleShortVersionString") }
    fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "" }
}

extension HTTPMethod {
    var pwMethod: PayWingsOAuthSDK.HttpRequestMethod {
        switch self {
        case .get: .GET
        case .post: .POST
        }
    }
}
