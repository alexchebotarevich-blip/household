import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Errors that can occur when configuring Firebase for the application lifecycle.
public enum FirebaseConfigurationError: Error {
    case missingConfigurationFile(path: String)
    case invalidConfiguration(String)
}

public protocol FirebaseConfiguring: AnyObject {
    /// Indicates whether Firebase has already been configured for the current process.
    var isConfigured: Bool { get }

    /// Configures Firebase if it has not already been configured.
    /// - Parameter plistPath: Optional path to an explicit `GoogleService-Info.plist` file. When `nil`
    ///   the default lookup behaviour provided by Firebase will be used.
    func configureIfNeeded(using plistPath: String?) throws
}

/// Coordinates Firebase initialization. This wrapper keeps the configuration logic isolated from
/// the UI layer, making it easy to unit test and customise for different environments.
public final class FirebaseAppConfigurator: FirebaseConfiguring {
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "FirebaseAppConfigurator.serial")
    private var configurationState: ConfigurationState = .notConfigured

    private enum ConfigurationState {
        case notConfigured
        case configured
    }

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var isConfigured: Bool {
        queue.sync { configurationState == .configured }
    }

    public func configureIfNeeded(using plistPath: String? = nil) throws {
        var configurationResult: Result<Void, Error> = .success(())

        queue.sync {
            guard configurationState == .notConfigured else { return }

            do {
                if let plistPath {
                    guard fileManager.fileExists(atPath: plistPath) else {
                        throw FirebaseConfigurationError.missingConfigurationFile(path: plistPath)
                    }
                }

                #if canImport(FirebaseCore)
                if let plistPath {
                    guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
                        throw FirebaseConfigurationError.invalidConfiguration(
                            "Unable to build FirebaseOptions from plist at \(plistPath)."
                        )
                    }

                    FirebaseApp.configure(options: options)
                } else if FirebaseApp.app() == nil {
                    FirebaseApp.configure()
                }
                #endif

                configurationState = .configured
            } catch {
                configurationResult = .failure(error)
            }
        }

        try configurationResult.get()
    }
}
