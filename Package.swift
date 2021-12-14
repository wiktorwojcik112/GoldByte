// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GoldByte",
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GoldByte",
            dependencies: [],
			resources: [
				.process("Resources/std.txt"),
			]),
        .testTarget(
            name: "GoldByteTests",
			dependencies: ["GoldByte"]
		),
    ]
)
