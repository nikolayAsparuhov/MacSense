# 内嵌登录项

应用通过 `SMAppService`(macOS 13+)注册自身的登录项。出于安全原因,第三方工具(包括 MacSense)无法禁用、修改或删除它们。

## 详情

苹果引入 `SMAppService` 替代旧的登录项 API。优势:

- 应用从自己的 bundle 内将自身注册为登录代理。
- macOS 保证应用之外的任何东西都无法篡改注册。
- 用户通过系统设置保留完全控制权。

代价:像 MacSense 这样的工具可以显示这些注册,但无法切换。点击“禁用”操作会打开**系统设置 → 通用 → 登录项**到正确的面板,以便你自己切换。

通过旧 API(LSSharedFileList、`~/Library/LaunchAgents` 中的 launchd plist)注册的旧式登录项仍可在 MacSense 中管理。
