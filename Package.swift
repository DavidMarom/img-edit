// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ImgEdit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ImgEdit",
            path: "Sources/ImgEdit"
        )
    ]
)
