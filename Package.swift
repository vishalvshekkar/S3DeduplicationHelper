// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "S3DeduplicationHelper",
    dependencies: [
        .package(
            name: "Files",
            url: "https://github.com/johnsundell/files.git",
            from: "4.0.0"
        ),
        .package(
            name: "AWSSDKSwift",
            url: "https://github.com/swift-aws/aws-sdk-swift.git",
            from: "4.0.0"
        ),
    ],
    targets: [
        .target(
            name: "S3DeduplicationHelper",
            dependencies: ["S3DeduplicationHelperCore"]),
        .target(
            name: "S3DeduplicationHelperCore",
            dependencies: [
                "Files",
                .product(name: "S3", package: "AWSSDKSwift"),
                .product(name: "SES", package: "AWSSDKSwift"),
                .product(name: "IAM", package: "AWSSDKSwift"),
            ]
        ),
        .testTarget(
            name: "S3DeduplicationHelperTests",
            dependencies: ["S3DeduplicationHelperCore", "Files", "AWSSDKSwift"]
        )
    ]
)
