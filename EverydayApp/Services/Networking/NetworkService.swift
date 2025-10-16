import Foundation
import Combine
import Alamofire
import CombineExt

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let parameters: Parameters?
    let encoding: ParameterEncoding
    let headers: HTTPHeaders?

    init(path: String,
         method: HTTPMethod = .get,
         parameters: Parameters? = nil,
         encoding: ParameterEncoding = URLEncoding.default,
         headers: HTTPHeaders? = nil) {
        self.path = path
        self.method = method
        self.parameters = parameters
        self.encoding = encoding
        self.headers = headers
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to build a valid URL for the request."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

protocol NetworkServicing {
    func request<T: Decodable>(_ endpoint: APIEndpoint, decoder: JSONDecoder) -> AnyPublisher<T, NetworkError>
}

final class NetworkService: NetworkServicing {
    private let session: Session
    private let configuration: AppConfiguration

    init(configuration: AppConfiguration = AppConfiguration(), session: Session = .default) {
        self.configuration = configuration
        self.session = session
    }

    func request<T>(_ endpoint: APIEndpoint, decoder: JSONDecoder = JSONDecoder()) -> AnyPublisher<T, NetworkError> where T: Decodable {
        guard let url = URL(string: endpoint.path, relativeTo: configuration.baseURL) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }

        return session.request(url,
                               method: endpoint.method,
                               parameters: endpoint.parameters,
                               encoding: endpoint.encoding,
                               headers: endpoint.headers)
            .validate()
            .publishDecodable(type: T.self, decoder: decoder)
            .value()
            .mapError { NetworkError.underlying($0) }
            .shareReplay(1)
    }
}
