# [OPEN] issue-detail-crash

## 症状
- 点开个别 issue 后，HarmonyOS 模拟器应用直接闪退。
- 预期行为：进入 issue 详情页，至少展示加载态或错误态，而不是进程崩溃。

## 复现条件
- 进入某些 issue 详情页时触发。
- 当前用户补充现象：直接闪退。

## 初始假设（待证伪）
1. 某些 issue 字段为 `null/undefined`，在详情页渲染阶段被当作非空字符串使用，触发运行时崩溃。
2. 个别 issue/comment 的富文本或时间字段格式异常，导致 [IssueDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/IssueDetailPage.ets) 内部组件渲染崩溃。
3. 某些 assignee/creator/comment author 数据缺失，头像或文本组件接收到不合法值，触发 ArkUI 渲染异常。
4. `queryClient.onAnyStateChange` / `syncFromCache()` 在特定数据下把异常状态写入 `@Local`，导致页面 build 期崩溃。
5. 详情接口成功返回，但 comments / members / agents 某一路返回异常结构，页面在组合显示时崩溃。

## 已读代码
- [IssueDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/IssueDetailPage.ets)
- [api.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/data/api.ets)
- [Avatar.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/components/ui/Avatar.ets)
- [MarkdownText.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/components/ui/MarkdownText.ets)
- [cache.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/queries/cache.ets)

## 当前计划
- 先只加埋点，不改业务逻辑。
- 让用户复现一次，收集崩溃前最后一批日志。
- 根据证据锁定根因后再做最小修复。

## 当前证据
- 用户提供的 `PARAM_WATCHER` / `BEGET` 日志看起来是系统层噪音，未直接指向业务崩溃点。
- 同一时段可见 issue 详情接口 `GET /api/issues/:id` 返回 200，说明至少有一部分详情请求成功。
- 目前缺少应用侧最后一条业务日志，无法判断是 `aboutToAppear`、`syncFromCache` 还是具体某个渲染节点触发闪退。

## 已加埋点
- [IssueDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/IssueDetailPage.ets) 已增加 `hilog` 调试点：页面进入、cache 同步。

## 运行时证据
- 崩溃栈明确指向 [IssueDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/IssueDetailPage.ets) 的 `actorName()` → `commentAuthorName()` → `CommentRow()`。
- 具体异常：`TypeError: Cannot read property display_name of undefined`。
- 说明 `members.find(...)` 命中后，`found.user` 在个别数据下为 `undefined`，但代码直接读取了 `found.user.display_name`。
- 该问题会在评论作者为 member 且成员数据不完整时触发，从而导致详情页渲染期闪退。

## 根因判断
- 已确认假设 3：某些 assignee/creator/comment author 关联到的 member 记录存在，但 `user` 对象缺失，页面未做空值保护，渲染评论作者名称时直接崩溃。
- 第二次验证表明同类问题也存在于头像路径：`actorAvatar()` 直接读取 `found.user.avatar_url`，导致继续闪退。

## 下一步
- 在 [IssueDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/IssueDetailPage.ets) 对 `found.user` 增加最小空值保护。
- 修复后请再次复现，对比修复前后的结果。
