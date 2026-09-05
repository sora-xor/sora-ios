import Foundation

public protocol NetworkWorker {
    func performRequest<T: Decodable>(
        with config: RequestConfig
    ) async throws -> T
}

public final class NetworkWorkerDefault: NetworkWorker {
    private let requestSignerFactory: RequestSignerFactory
    private let networkClientFactory: NetworkClientFactory
    private let responseDecoderFactory: ResponseDecodersFactory

    public init(
        requestSignerFactory: RequestSignerFactory = BaseRequestSignerFactory(),
        networkClientFactory: NetworkClientFactory = BaseNetworkClientFactory(),
        responseDecoderFactory: ResponseDecodersFactory = BaseResponseDecoderFactory()
    ) {
        self.requestSignerFactory = requestSignerFactory
        self.networkClientFactory = networkClientFactory
        self.responseDecoderFactory = responseDecoderFactory
    }

    public func performRequest<T: Decodable>(
        with config: RequestConfig
    ) async throws -> T {
        let requestConfiguratorFactory = BaseRequestConfiguratorFactory()
        let requestConfigurator = try requestConfiguratorFactory.buildRequestConfigurator(
            with: config.requestType,
            baseURL: config.baseURL
        )
        let requestSigner = try requestSignerFactory.buildRequestSigner(with: config.signingType)
        let networkClient = networkClientFactory.buildNetworkClient(with: config.networkClientType)
        let responseDecoder = responseDecoderFactory.buildResponseDecoder(with: config.decoderType)

        var request = try requestConfigurator.buildRequest(with: config)
        try requestSigner?.sign(request: &request, config: config)
        let response = try await networkClient.perform(request: request)

        let decoded: T = try responseDecoder.decode(data: response)
        return decoded
    }
}
