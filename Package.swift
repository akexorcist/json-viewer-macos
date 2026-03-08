// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JSON Viewer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "JSON Viewer",
            path: "JSONViewer",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "JSONViewer/Info.plist"
                ])
            ]
        )
    ]
)
