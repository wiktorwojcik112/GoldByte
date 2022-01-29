// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GoldByte",
	products: [
		.executable(
			name: "gbtool",
			targets: ["gbtool"]
		),
		.library(
			name: "GoldByte",
			targets: ["GoldByte"]
		)
	],
    dependencies: [],
    targets: [
		.target(
			name: "GoldByte",
			exclude: [
			],
			resources: [
				.process("Resources/std.txt"),
				.process("Resources/math.txt"),
				.process("Resources/strings.txt"),
				.process("Resources/arrays.txt"),
				.process("Resources/vectors.txt")
			]
		),
        .executableTarget(
            name: "gbtool",
            dependencies: [
				.target(name: "GoldByte")
			]
		),
        .testTarget(
            name: "GoldByteTests",
			dependencies: ["GoldByte"]
		),
    ]
)
