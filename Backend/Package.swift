// swift-tools-version:6.0
import PackageDescription

// The Lumikos server: a small Vapor app between the iOS client and TMDB.
let package = Package(
    name: "LumikosBackend",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.122.3"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.13.0"),
        // SQLite for local runs and tests, Postgres (Neon) on Render
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.14.1"),
        // SHA-256 for login tokens (Vapor itself already uses this package)
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
