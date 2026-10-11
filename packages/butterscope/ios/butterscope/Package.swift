// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "butterscope",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "butterscope", targets: ["butterscope"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "butterscope",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
