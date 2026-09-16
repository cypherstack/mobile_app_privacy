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
        // Pin the latest 3.x revision (2026-09-15) for reproducible builds.
        // Includes newer device models, the privacy manifest, and the SwiftPM
        // Release assertion fix missing from the 3.0.0 tag.
        .package(
            url: "https://github.com/SVGKit/SVGKit.git",
            revision: "9b573a08e7698149de1a0ed576f22f68f5a0e30b"
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
