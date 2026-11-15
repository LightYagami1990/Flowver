// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Flowver",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Flowver", targets: ["Flowver"])
    ],
    dependencies: [
        // ZIP 解压（EPUB 本质是 ZIP）
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.1"),
        // 轻量 XML/HTML 解析，用于读取 OPF / NCX / XHTML
        .package(url: "https://github.com/cezheng/Fuzi.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "Flowver",
            dependencies: ["Zip", "Fuzi"],
            path: "ListenBooks"
        )
    ]
)
