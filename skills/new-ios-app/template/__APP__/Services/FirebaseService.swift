import FirebaseCore
import Foundation

enum FirebaseService {
    // FirebaseApp.configure() traps when GoogleService-Info.plist is missing;
    // skipping keeps the app runnable before Firebase is provisioned.
    static func start() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
    }
}
