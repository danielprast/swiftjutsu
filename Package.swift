// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftJutsu",
  platforms: [
    .macOS(.v12),
    .iOS("16.4")
  ],
  products: [
    .library(
      name: "JutsuKit",
      targets: ["CoreJutsu", "NetworkJutsu"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.10.2"),
  ],
  targets: [
    .target(
      name: "CoreJutsu",
      swiftSettings: [
        .enableUpcomingFeature("ApproachableConcurrency"),
      ],
    ),
    .target(
      name: "NetworkJutsu",
      dependencies: ["CoreJutsu", "Alamofire"],
      swiftSettings: [
        .enableUpcomingFeature("ApproachableConcurrency"),
      ],
    ),
    .testTarget(
      name: "JutsuKitTests",
      dependencies: ["CoreJutsu"],
      swiftSettings: [
        .enableUpcomingFeature("ApproachableConcurrency"),
      ],
    ),
  ]
)
