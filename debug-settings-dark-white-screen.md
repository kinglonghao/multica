# [OPEN] debug-settings-dark-white-screen

## Bug
- Settings 页开启 dark 模式后出现白屏/近似白屏。

## Symptoms
- 全局 dark 已正常：导航栏、tab bar、其他 more 子页都能正确变黑。
- 仅 settings 页异常。
- 最新截图显示底部 `Projects / Issues / Pinned / Agents` 内容出现在 settings 页面视觉区域内，说明异常不一定只来自 settings.tsx 本体，也可能有下层内容透出或 overlay 未关闭。

## Updated Hypotheses
1. Settings 页本体没有铺满或背景透明，导致下层 More 内容透出。
2. More dropdown / overlay 在导航到 settings 后没有完全销毁，仍在参与绘制。
3. settings.tsx 内部局部组件仍回退到浅色默认 token，导致分组卡片看起来发白。
4. HarmonyOS 上 route transition / ScrollView 绘制层级与 iOS 不同，需要显式根容器背景或独立 SafeAreaView。
5. WS 错误是旁路噪音，不是 settings 白屏根因；除非它触发特定页面级遮罩，但当前证据不足。

## Plan
- 检查 `[workspace]/_layout.tsx` 对 more/settings 的路由注册与 presentation。
- 检查 More dropdown 打开/关闭与 push settings 的生命周期。
- 根据证据决定是修 settings.tsx 根容器，还是修 more overlay/navigation。
