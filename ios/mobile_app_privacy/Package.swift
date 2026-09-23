// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "mobile_app_privacy",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "mobile-app-privacy", targets: ["mobile_app_privacy"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Pin SVGKit's CocoaLumberjack compatibility fix.
        // Includes newer device models, the privacy manifest, and the SwiftPM
        // Release assertion fix missing from the 3.0.0 tag.
        .package(
            url: "https://github.com/SVGKit/SVGKit.git",
            revision: "6002a0ff6b2d4405805395959b92b38aa24662cb"
        )
    ],
    targets: [
        .target(
            name: "mobile_app_privacy",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "SVGKit", package: "SVGKit")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
