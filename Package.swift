// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealityKitViewRenderer",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "RealityKitViewRenderer",
            targets: ["RealityKitViewRenderer"]),
    ],
    dependencies: [
    ],
    targets: [
      .target(name: "RealityKitViewRenderer"),
    ]
)
