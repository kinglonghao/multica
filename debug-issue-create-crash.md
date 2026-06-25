# debug-issue-create-crash.md

Status: [OPEN]
Session: issue-create-crash

## Symptom
- 在鸿蒙端创建 issue 后直接崩溃。
- 日志显示 WebSocket 握手失败：`ws upgrade response not 101`，并出现 handle finalized。

## Hypotheses
1. 创建 issue 成功后跳转到详情页，详情页初始化了错误的 WebSocket URL，服务端返回 200 非 101，随后原生侧异常退出。
2. 创建 issue 成功后触发了重复的 WebSocket 连接/销毁竞争，导致已 finalized 的 handle 被后续逻辑继续使用。
3. issue 详情页依赖的某个 query / realtime hook 在 issue id 切换后收到空值或非法值，触发运行时异常，日志里 WebSocket 失败只是伴随现象。
4. `appNavigation.pushName('IssueDetailPage', ...)` 后，IssueDetailPage 在 `aboutToAppear` 或订阅阶段对网络层做了未兼容的调用，导致崩溃。
5. 创建后缓存失效逻辑触发了多个页面同时重连 WS，HarmonyOS NETSTACK 对当前握手路径不兼容，导致 crash。

## Evidence Plan
- 先检查 NewIssuePage -> IssueDetailPage -> realtime hooks / ws-client 调用链。
- 第一处逻辑改动只添加埋点，不改业务逻辑。
- 收集：创建成功、跳转参数、详情页进入、WS connect url、WS error、页面销毁顺序。
