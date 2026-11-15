// swift-tools-version:6.0
import PackageDescription

// API models shared by the iOS app and the Vapor server.
// Only Foundation here: no Vapor, no SwiftUI, so both sides can import it.
let package = Package(
    name: "Shared",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [.library(name: "Shared", targets: ["Shared"])],
    targets: [.target(name: "Shared")]
)
