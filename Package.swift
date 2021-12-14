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
			exclude: [
				"CHANGELOG.md",
				"README.md"
			],
			resources: [
				.process("Resources/std.txt"),
				.process("Resources/math.txt"),
				.process("Resources/stringutils.txt"),
				.process("Resources/arrays.txt"),
			]),
        .testTarget(
            name: "GoldByteTests",
			dependencies: ["GoldByte"]
		),
    ]
)
