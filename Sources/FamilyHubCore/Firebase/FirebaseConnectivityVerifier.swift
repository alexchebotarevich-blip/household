import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol FirebaseConnectivityVerifying {
    func verifyConnectivity(timeout: TimeInterval, completion: @escaping (Result<Bool, Error>) -> Void)
}

/// Performs a lightweight reachability request against the Firestore public endpoint. This does not
/// mutate data on the backend, but provides a fast verification that credentials and networking are
/// functioning after Firebase has been configured.
public final class FirebaseConnectivityVerifier: FirebaseConnectivityVerifying {
    private let session: URLSession
    private let endpoint: URL
    private let callbackQueue: DispatchQueue

    public init(
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://firestore.googleapis.com/")!,
        callbackQueue: DispatchQueue = .main
    ) {
        self.session = session
        self.endpoint = endpoint
        self.callbackQueue = callbackQueue
    }

    public func verifyConnectivity(timeout: TimeInterval = 5.0, completion: @escaping (Result<Bool, Error>) -> Void) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        let task = session.dataTask(with: request) { _, response, error in
            self.callbackQueue.async {
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.success(false))
                    return
                }

                completion(.success((200...499).contains(httpResponse.statusCode)))
            }
        }

        task.resume()
    }
}
