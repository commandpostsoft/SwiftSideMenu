// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SideMenu",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "SideMenu",  targets: ["SideMenu"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SideMenu",
            path: "Pod/Classes",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        )
    ],
    swiftLanguageVersions: [.v4_2, .v5]
)

