# 开发者缓存

来自开发工具的构建产物和已下载包。下次使用时会重建,在开发者机器上常占用数十 GB。

## 详情

MacSense 检索 30 多种工具的缓存,包括:

- **Xcode** — `~/Library/Developer/Xcode/DerivedData`、归档的模拟器、设备支持。
- **Homebrew** — `~/Library/Caches/Homebrew`。
- **Node 生态** — `npm`、`yarn`、`pnpm` 全局缓存。
- **Python** — `pip`、`pipenv`、`poetry` wheel 缓存。
- **Rust** — `~/.cargo/registry/cache`。
- **Go** — `$GOPATH/pkg/mod/cache`。
- **Docker** — 悬挂镜像、构建缓存、已停止容器。
- **JetBrains IDE**、**Maven**、**NuGet**、**Gradle** 等。

删除会让*下次*项目构建变慢,之后一切恢复正常。你的项目内 `node_modules` 或 `target/` 目录中的活跃产物绝不会被触及 — 只有共享的全局缓存。
