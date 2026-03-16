// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Yapper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Yapper",
            targets: ["Yapper"]
        )
    ],
    dependencies: [
        // Add dependencies here as needed
    ],
    targets: [
        .systemLibrary(
            name: "CWhisper",
            path: "Vendor/CWhisper"
        ),
        .executableTarget(
            name: "Yapper",
            dependencies: ["CWhisper"],
            path: "Sources/Yapper",
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/src",
                    "-L", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src",
                    "-L", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src/ggml-blas",
                    "-L", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src/ggml-metal",
                    "-L", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src/ggml-cpu",
                    "-lwhisper",
                    "-lggml",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/src",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src/ggml-blas",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src/ggml-metal",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/ahmedelhanafy/Documents/Dev/AI Apps/VoxFlow/Vendor/whisper.cpp/build/ggml/src/ggml-cpu"
                ], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "YapperTests",
            dependencies: ["Yapper"],
            path: "Tests/YapperTests"
        )
    ]
)
