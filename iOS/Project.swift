import ProjectDescription

// Tuist turns this file into Lumikos.xcodeproj (`mise run generate`).
// The .xcodeproj is not in git: no merge conflicts in project files, ever.
//
// One app target with all the code (folders instead of modules) and one test target.
// Tests always need their own target in Xcode, that is the only reason for the second one.

let project = Project(
    name: "Lumikos",
    targets: [
        .target(
            name: "Lumikos",
            destinations: .iOS,
            product: .app,
            bundleId: "com.disavle.lumikos",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "1",
                "CFBundleDisplayName": "Lumikos",
                "UILaunchScreen": [:],
                // Without this iOS does not show the "Language" row in the app's settings.
                "CFBundleLocalizations": ["en", "ru"],
                // UIKit life cycle: SceneDelegate starts AppCoordinator.
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [[
                            "UISceneConfigurationName": "Default",
                            "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate",
                        ]],
                    ],
                ],
                // Plain http is allowed only to localhost: the server on your Mac.
                "NSAppTransportSecurity": ["NSAllowsLocalNetworking": true],
            ]),
            sources: ["Lumikos/**/*.swift"],
            resources: ["Lumikos/Resources/**"],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                // Your Team ID from mise.local.toml (TUIST_TEAM_ID). Empty is fine for the simulator.
                "DEVELOPMENT_TEAM": .string(Environment.teamId.getString(default: "")),
                "CODE_SIGN_STYLE": "Automatic",
            ])
        ),
        .target(
            name: "LumikosTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.disavle.lumikos.tests",
            deploymentTargets: .iOS("18.0"),
            sources: ["LumikosTests/**"],
            dependencies: [.target(name: "Lumikos")],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
    ]
)
