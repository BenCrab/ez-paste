// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EzPaste",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EzPaste",
            path: "Sources/EzPaste"
        )
    ]
)
