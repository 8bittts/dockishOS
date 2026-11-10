import Foundation

/// Single source for the app's version/build strings read from the bundle.
enum AppVersion {
    static var short: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    static var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }
}

/// Project pages the status menu and the About tab link to.
enum AppLinks {
    static let repository = URL(string: "https://github.com/8bittts/dockishOS")!
    static let releases = repository.appending(path: "releases")
    static let license = repository.appending(path: "blob/main/LICENSE")
}
