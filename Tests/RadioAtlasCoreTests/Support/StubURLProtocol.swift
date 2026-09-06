import Foundation

final class StubURLProtocol: URLProtocol {
    static var responseData: Data = Data()
    static var responseStatus: Int = 200
    static var responseError: Error?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lastRequest = request
        if let responseError = StubURLProtocol.responseError {
            client?.urlProtocol(self, didFailWithError: responseError)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: StubURLProtocol.responseStatus,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: StubURLProtocol.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}
