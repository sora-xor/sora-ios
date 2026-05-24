import XNetworking

final class RestClientConfig: AbstractRestClientConfig {
    override func isLoggingEnabled() -> Bool {
        false
    }

    override func getSocketTimeoutMillis() -> Int64 {
        30000
    }

    override func getConnectTimeoutMillis() -> Int64 {
        30000
    }

    override func getRequestTimeoutMillis() -> Int64 {
        30000
    }

    override func getOrCreateJsonConfig() -> Kotlinx_serialization_jsonJson {
        JsonExtsKt.createJson(
            isPrettyPrintEnabled: true,
            isLenient: true,
            shouldIgnoreUnknownKeys: true
        )
    }
}
