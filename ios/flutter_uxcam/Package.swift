// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_uxcam",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-uxcam", targets: ["flutter_uxcam"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(
            url: "https://github.com/uxcam/uxcam-ios",
            .upToNextMinor(from: "3.10.1")
        )
    ],
    targets: [
        .target(
            name: "flutter_uxcam",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "UXCam", package: "uxcam-ios")
            ],
            cSettings: [
                .headerSearchPath("include/flutter_uxcam")
            ]
        )
    ]
)
