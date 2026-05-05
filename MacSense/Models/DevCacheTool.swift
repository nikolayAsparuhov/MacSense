import Foundation
import SwiftUI

/// Catalog of dev-tool caches we can detect + clean. Each entry maps
/// to one or more on-disk paths plus a brand-tinted icon shown in the
/// Developer Caches grouped view. The catalog deliberately covers the
/// broad set of package managers, build tools, runtimes, and infra
/// CLIs that produce per-user caches on macOS.
struct DevCacheTool: Identifiable, Hashable {
    let id: String      // stable key used as `subCategory`
    let displayName: String
    let symbol: String  // SF Symbol fallback when no asset
    let textMark: String?  // 1-3 char text badge ("py", "rb"); nil = use symbol
    let accent: Color
    let paths: [String]
    let explanation: String

    static func hash(into hasher: inout Hasher, _ tool: DevCacheTool) {
        hasher.combine(tool.id)
    }

    static func == (lhs: DevCacheTool, rhs: DevCacheTool) -> Bool { lhs.id == rhs.id }
}

enum DevCacheCatalog {
    static let home = NSHomeDirectory()

    /// Lookup by `subCategory` id. Returns nil for sub-categories
    /// owned by the dedicated scanners (Xcode / Homebrew / Docker /
    /// Node) which use friendlier free-text labels rather than ids.
    static func tool(forSubCategory sub: String?) -> DevCacheTool? {
        guard let sub else { return nil }
        return all.first { $0.id == sub }
    }

    static let all: [DevCacheTool] = [
        // Already covered by dedicated scanners (Xcode / Homebrew /
        // Docker / Node) — included here for parity but the scan
        // skips paths owned by those scanners so we don't double-count.

        // --- Node.js ecosystem ---
        DevCacheTool(
            id: "npm", displayName: "npm",
            symbol: "shippingbox.fill", textMark: "n",
            accent: Color(red: 0.80, green: 0.20, blue: 0.20),
            paths: ["\(home)/.npm"],
            explanation: "Cached package tarballs downloaded by `npm install`. Safe to delete; npm re-fetches on next install."
        ),
        DevCacheTool(
            id: "yarn", displayName: "Yarn",
            symbol: "shippingbox.fill", textMark: "y",
            accent: Color(red: 0.16, green: 0.45, blue: 0.74),
            paths: [
                "\(home)/Library/Caches/Yarn",
                "\(home)/.cache/yarn",
                "\(home)/.yarn/cache",
            ],
            explanation: "Yarn classic + Berry global package cache. Re-downloads on next install."
        ),
        DevCacheTool(
            id: "pnpm", displayName: "pnpm",
            symbol: "shippingbox.fill", textMark: "p",
            accent: Color(red: 0.97, green: 0.59, blue: 0.20),
            paths: [
                "\(home)/Library/pnpm/store",
                "\(home)/.local/share/pnpm/store",
                "\(home)/.pnpm-store",
            ],
            explanation: "pnpm content-addressed package store. Projects rehydrate via hardlinks on next install."
        ),
        DevCacheTool(
            id: "bun", displayName: "Bun",
            symbol: "shippingbox.fill", textMark: "b",
            accent: Color(red: 0.99, green: 0.95, blue: 0.85),
            paths: ["\(home)/.bun/install/cache"],
            explanation: "Bun runtime install cache."
        ),

        // --- Python ecosystem ---
        DevCacheTool(
            id: "pip", displayName: "pip",
            symbol: "snowflake", textMark: "py",
            accent: Color(red: 0.20, green: 0.40, blue: 0.65),
            paths: [
                "\(home)/Library/Caches/pip",
                "\(home)/.cache/pip",
            ],
            explanation: "Python pip wheel + HTTP cache. Re-downloaded on next pip install."
        ),
        DevCacheTool(
            id: "poetry", displayName: "Poetry",
            symbol: "drop.fill", textMark: "po",
            accent: Color(red: 0.24, green: 0.40, blue: 0.85),
            paths: [
                "\(home)/Library/Caches/pypoetry",
                "\(home)/.cache/pypoetry",
            ],
            explanation: "Poetry's resolver + artifact cache."
        ),
        DevCacheTool(
            id: "pipx", displayName: "pipx",
            symbol: "snowflake", textMark: "px",
            accent: Color(red: 0.30, green: 0.50, blue: 0.75),
            paths: ["\(home)/.local/pipx/.cache"],
            explanation: "pipx download cache. The actual installed apps live in pipx/venvs and are NOT touched."
        ),
        DevCacheTool(
            id: "conda", displayName: "Conda packages",
            symbol: "drop.circle", textMark: "co",
            accent: Color(red: 0.25, green: 0.55, blue: 0.40),
            paths: [
                "\(home)/anaconda3/pkgs",
                "\(home)/miniconda3/pkgs",
                "\(home)/.conda/pkgs",
                "\(home)/miniforge3/pkgs",
            ],
            explanation: "Conda package archive cache. Environments stay intact; conda re-extracts pkgs as needed."
        ),
        DevCacheTool(
            id: "pyenv", displayName: "pyenv cache",
            symbol: "snowflake.circle", textMark: "pe",
            accent: Color(red: 0.18, green: 0.45, blue: 0.75),
            paths: ["\(home)/.pyenv/cache"],
            explanation: "pyenv source/build download cache. Installed Python versions are not affected."
        ),

        // --- Ruby ecosystem ---
        DevCacheTool(
            id: "rubygems", displayName: "RubyGems",
            symbol: "diamond.fill", textMark: "rb",
            accent: Color(red: 0.78, green: 0.18, blue: 0.18),
            paths: ["\(home)/.gem"],
            explanation: "RubyGems user-level cached gems."
        ),
        DevCacheTool(
            id: "bundler", displayName: "Bundler",
            symbol: "shippingbox.fill", textMark: "bu",
            accent: Color(red: 0.85, green: 0.35, blue: 0.30),
            paths: ["\(home)/.bundle/cache"],
            explanation: "Bundler global gem cache."
        ),

        // --- Java / JVM ---
        DevCacheTool(
            id: "maven", displayName: "Maven",
            symbol: "shippingbox.fill", textMark: "M",
            accent: Color(red: 0.78, green: 0.36, blue: 0.18),
            paths: ["\(home)/.m2/repository"],
            explanation: "Maven local artifact repository. Removing forces re-download from remotes on next build."
        ),
        DevCacheTool(
            id: "gradle", displayName: "Gradle",
            symbol: "hammer.fill", textMark: "G",
            accent: Color(red: 0.05, green: 0.42, blue: 0.50),
            paths: [
                "\(home)/.gradle/caches",
                "\(home)/.gradle/wrapper",
            ],
            explanation: "Gradle dependency, build, and wrapper-distribution caches."
        ),
        DevCacheTool(
            id: "sdkman", displayName: "SDKMAN",
            symbol: "tray.full.fill", textMark: "sk",
            accent: Color(red: 0.30, green: 0.55, blue: 0.30),
            paths: ["\(home)/.sdkman/archives"],
            explanation: "SDKMAN downloaded SDK archives. Installed SDKs stay; only the installer ZIPs are removed."
        ),

        // --- Rust ---
        DevCacheTool(
            id: "cargo", displayName: "Cargo",
            symbol: "wrench.adjustable", textMark: "rs",
            accent: Color(red: 0.85, green: 0.40, blue: 0.20),
            paths: [
                "\(home)/.cargo/registry",
                "\(home)/.cargo/git",
            ],
            explanation: "Cargo's package registry + git source cache. Re-fetched on next `cargo build`."
        ),
        DevCacheTool(
            id: "rustup", displayName: "rustup",
            symbol: "wrench.adjustable.fill", textMark: "ru",
            accent: Color(red: 0.65, green: 0.30, blue: 0.18),
            paths: ["\(home)/.rustup/downloads"],
            explanation: "rustup toolchain download cache. Installed toolchains stay intact."
        ),

        // --- Go ---
        DevCacheTool(
            id: "go-mod", displayName: "Go module cache",
            symbol: "shippingbox", textMark: "go",
            accent: Color(red: 0.00, green: 0.65, blue: 0.85),
            paths: [
                "\(home)/go/pkg/mod",
                "\(home)/go/pkg/mod/cache",
            ],
            explanation: "Go module download cache. Re-fetched on next `go build`."
        ),
        DevCacheTool(
            id: "go-build", displayName: "Go build cache",
            symbol: "hammer", textMark: "gb",
            accent: Color(red: 0.00, green: 0.55, blue: 0.75),
            paths: ["\(home)/Library/Caches/go-build"],
            explanation: "Go incremental build cache. Re-built on demand; first build after delete is slower."
        ),

        // --- .NET ---
        DevCacheTool(
            id: "nuget", displayName: "NuGet",
            symbol: "shippingbox.fill", textMark: "Nu",
            accent: Color(red: 0.20, green: 0.30, blue: 0.65),
            paths: [
                "\(home)/.nuget/packages",
                "\(home)/.local/share/NuGet/v3-cache",
            ],
            explanation: ".NET NuGet global package store + HTTP cache."
        ),
        DevCacheTool(
            id: "dotnet", displayName: ".NET CLI",
            symbol: "circle.grid.cross.fill", textMark: "dn",
            accent: Color(red: 0.30, green: 0.30, blue: 0.70),
            paths: [
                "\(home)/.dotnet/toolResolverCache",
                "\(home)/.dotnet/optimizationdata",
            ],
            explanation: ".NET CLI tool resolver + optimization caches."
        ),

        // --- PHP ---
        DevCacheTool(
            id: "composer", displayName: "Composer",
            symbol: "music.note.list", textMark: "ph",
            accent: Color(red: 0.45, green: 0.35, blue: 0.65),
            paths: [
                "\(home)/.composer/cache",
                "\(home)/.config/composer/cache",
            ],
            explanation: "Composer PHP package cache."
        ),

        // --- Swift / Apple ---
        DevCacheTool(
            id: "swiftpm", displayName: "Swift PM",
            symbol: "swift", textMark: "sw",
            accent: Color(red: 0.95, green: 0.45, blue: 0.20),
            paths: [
                "\(home)/Library/Caches/org.swift.swiftpm",
                "\(home)/Library/org.swift.swiftpm",
            ],
            explanation: "Swift Package Manager dependency + checkout cache."
        ),

        // --- Dart / Flutter ---
        DevCacheTool(
            id: "pub", displayName: "Dart pub",
            symbol: "drop.triangle.fill", textMark: "pb",
            accent: Color(red: 0.20, green: 0.55, blue: 0.85),
            paths: ["\(home)/.pub-cache"],
            explanation: "Dart / Flutter pub package cache."
        ),

        // --- Elixir / Erlang ---
        DevCacheTool(
            id: "hex", displayName: "Hex",
            symbol: "hexagon.fill", textMark: "hx",
            accent: Color(red: 0.40, green: 0.20, blue: 0.45),
            paths: ["\(home)/.hex/packages"],
            explanation: "Erlang/Elixir Hex package cache."
        ),
        DevCacheTool(
            id: "mix", displayName: "Mix",
            symbol: "drop", textMark: "mx",
            accent: Color(red: 0.50, green: 0.30, blue: 0.55),
            paths: ["\(home)/.mix/archives"],
            explanation: "Mix archives cache."
        ),

        // --- Haskell ---
        DevCacheTool(
            id: "cabal", displayName: "Cabal",
            symbol: "lambda", textMark: "hs",
            accent: Color(red: 0.40, green: 0.25, blue: 0.55),
            paths: ["\(home)/.cabal/packages"],
            explanation: "Cabal Hackage package cache."
        ),
        DevCacheTool(
            id: "stack", displayName: "Stack",
            symbol: "cube.transparent", textMark: "st",
            accent: Color(red: 0.30, green: 0.40, blue: 0.65),
            paths: ["\(home)/.stack/programs"],
            explanation: "Stack tool / GHC download cache."
        ),

        // --- Scala ---
        DevCacheTool(
            id: "coursier", displayName: "Coursier",
            symbol: "arrow.triangle.2.circlepath.circle.fill", textMark: "co",
            accent: Color(red: 0.85, green: 0.30, blue: 0.30),
            paths: [
                "\(home)/Library/Caches/Coursier",
                "\(home)/.cache/coursier",
            ],
            explanation: "Coursier (Scala) artifact cache."
        ),
        DevCacheTool(
            id: "ivy", displayName: "Ivy / SBT",
            symbol: "leaf.fill", textMark: "iv",
            accent: Color(red: 0.50, green: 0.65, blue: 0.30),
            paths: [
                "\(home)/.ivy2/cache",
                "\(home)/.sbt/boot",
            ],
            explanation: "SBT / Ivy resolution cache."
        ),

        // --- C/C++ build accelerators ---
        DevCacheTool(
            id: "ccache", displayName: "ccache",
            symbol: "bolt.horizontal.fill", textMark: "cc",
            accent: Color(red: 0.45, green: 0.55, blue: 0.65),
            paths: [
                "\(home)/.ccache",
                "\(home)/Library/Caches/ccache",
            ],
            explanation: "C/C++ compiler output cache. Speeds up subsequent builds; safe to delete."
        ),
        DevCacheTool(
            id: "sccache", displayName: "sccache",
            symbol: "bolt.fill", textMark: "sc",
            accent: Color(red: 0.55, green: 0.45, blue: 0.65),
            paths: ["\(home)/Library/Caches/Mozilla.sccache"],
            explanation: "Mozilla sccache compiler cache."
        ),

        // --- Build systems ---
        DevCacheTool(
            id: "bazel", displayName: "Bazel",
            symbol: "square.grid.3x3.fill", textMark: "bz",
            accent: Color(red: 0.45, green: 0.65, blue: 0.30),
            paths: [
                "\(home)/.cache/bazel",
                "/private/var/tmp/_bazel_\(NSUserName())",
            ],
            explanation: "Bazel disk cache + symlink trees. Re-built on next invocation."
        ),

        // --- Containers / VMs ---
        DevCacheTool(
            id: "vagrant", displayName: "Vagrant",
            symbol: "shippingbox.and.arrow.backward.fill", textMark: "vg",
            accent: Color(red: 0.20, green: 0.40, blue: 0.65),
            paths: ["\(home)/.vagrant.d/boxes"],
            explanation: "Vagrant downloaded box cache. Active VMs stay intact."
        ),

        // --- Cloud / infra ---
        DevCacheTool(
            id: "terraform", displayName: "Terraform plugins",
            symbol: "globe.americas.fill", textMark: "tf",
            accent: Color(red: 0.40, green: 0.20, blue: 0.65),
            paths: [
                "\(home)/.terraform.d/plugin-cache",
                "\(home)/Library/Caches/terraform",
            ],
            explanation: "Terraform provider plugin cache. Re-downloaded on next `terraform init`."
        ),
        DevCacheTool(
            id: "pulumi", displayName: "Pulumi",
            symbol: "cloud.fill", textMark: "pu",
            accent: Color(red: 0.55, green: 0.30, blue: 0.65),
            paths: ["\(home)/.pulumi/plugins"],
            explanation: "Pulumi plugin download cache."
        ),
        DevCacheTool(
            id: "aws-sam", displayName: "AWS SAM",
            symbol: "cube.box.fill", textMark: "sa",
            accent: Color(red: 0.95, green: 0.55, blue: 0.18),
            paths: ["\(home)/.aws-sam"],
            explanation: "AWS SAM build cache + deployment artifacts."
        ),
    ]
}
