// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "ForECore", targets: ["ForECore"])]
var targets: [Target] = [
    .target(name: "ForECore"),
    .testTarget(name: "ForECoreTests", dependencies: ["ForECore"])
]

// The timer/journal logic is testable on Linux. macOS adds the real app and
// integration tests with a fake Screen Time driver, without touching settings.
#if os(macOS)
products.append(.executable(name: "ForEScreenTime", targets: ["ForEScreenTime"]))
targets.append(.executableTarget(
    name: "ForEScreenTime", dependencies: ["ForECore"], path: "ForE",
    exclude: ["Resources"], sources: ["App", "Services", "Views"]
))
targets.append(.testTarget(name: "ForEAppTests", dependencies: ["ForEScreenTime", "ForECore"]))
#endif

let package = Package(name: "ForEScreenTime", platforms: [.macOS(.v13)],
    products: products, targets: targets)
