# Debug: 鸿蒙 Inbox 一直 loading

**Status**: [OPEN]
**SessionId**: `inbox-stuck-loading`
**Reporter**: 用户截图 + hilog
**Date**: 2026-06-15

## 症状

- 鸿蒙 app 进入 Inbox tab
- 看到 6 行 skeleton（LoadingState）
- My Issues 同样症状
- 一直显示 loading，从没出现过 EmptyState / List / ErrorState

## 运行时证据（用户已提供）

```
[api] → GET /api/inbox rid=6gx8x57dmqefsie0
[api] ← 200 /api/inbox rid=6gx8x57dmqefsie0 dur=832ms
[api] → GET /api/inbox rid=kiwzysxnmqeftihm
[api] ← 200 /api/inbox rid=kiwzysxnmqeftihm dur=213ms
[api] → GET /api/inbox rid=49stvm0amqeg0qhs
[api] ← 200 /api/inbox rid=49stvm0amqeg0qhs dur=729ms
```

- 请求 3 次都 200 成功
- 响应时间 < 1s
- 但 UI 永远停在 LoadingState

## 假设（H1 ~ H5）

| ID | 假设 | 验证方式 |
|----|------|---------|
| **H1** | 服务端返回的 body 不是数组（或不是 InboxItem[]），`InboxListSchema.validate()` 失败 → `parseWithFallback` 返回 `[]` → UI 应该走 EmptyState，但如果 build 没被重新执行，UI 还在 loading | 在 build() 顶部打印 `data.length` / `isLoading` / `version` |
| **H2** | `cache.ets` 的 then 块执行后 `isLoading=false`，但 `onUpdate` 触发的 `version++` 没让 ArkUI 重新 build | 同上，看 build() 是否被多次调用 |
| **H3** | `useInboxQuery` 触发了多次 refetch（staleTime=30s + WS invalidate 风暴），但每次 refetch 之间 UI 都跑回 LoadingState，用户视觉上"一直转" | 看 `[api] → GET /api/inbox` 的频率和 build 调用次数 |
| **H4** | `getState()` 返回的是旧的 state 引用，build() 读到的不是最新 | 看 build 时打印的 isLoading 与最后一次 cache state 是否一致 |
| **H5** | 服务端返回 `[]` 真的没问题，但 `deduplicateInboxItems([])` 走了非预期的分支（不太可能，但要排除） | 看 build 日志中 dataLen |

## 修复迭代

### v1（失败）：`@Local renderTick: number = 0` + `.id(\`InboxPage-${renderTick}\`)`
- **问题**：`renderTick` 在 build() 中**没被实际"使用"**（`.id()` 参数 ArkUI 可能静态求值），ArkUI 反应式追踪不到
- **结果**：用户报告"还是白屏"——build 还是没重跑

### v2（成功）：把 cache state 镜像到 @Local 字段 + build 实际读这些字段
- 新增 `@Local _isLoading: boolean` / `@Local _data: InboxItem[] | undefined` / `@Local _error: Error | null`
- `syncFromCache()` 同步 cache state → 这三个 @Local 字段
- onUpdate 调 `syncFromCache()` → @Local 变化 → ArkUI 重 build
- build 中**实际使用** `if (this._isLoading)` / `this._data` / `this._error` —— ArkUI 必然追踪
- **用户报告：Inbox 正常显示** ✅

### v3（批量修复）：所有 8 个用了 useQuery 的页面都加 v2 模式
- 用户报告："收件箱好了，但是详情点进去看不到而且除了收件箱，其他也都是空白"
- **根因**：所有用 `useXxxQuery` 的页面都受同样问题影响
- 批量加：InboxPage / MyIssuesPage / IssueDetailPage (2 query) / ChatPage / AgentsPage / ChatDetailPage (2 query) / NotificationsPage / ProjectDetailPage (2 query)
- 同时改 [cache.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/queries/cache.ets)：
  - 新增 `queryClient.onAnyStateChange(cb)` 全局状态变化 hook
  - 在 `notify` / `setQueryData` / `invalidate` / `invalidatePrefix` / `clear` 中触发全局 listeners
  - 这样 page 的 `syncFromCache` 能 catch 到所有 cache 状态变化（包括 setQueryData 乐观更新）

## 关键洞察

**ArkUI 反应式追踪基于 build() 中实际读到的 @Local 字段**：
- `version` 没在 build 读到 → version++ 不触发
- `issueCache` 在 build 中通过 `.get()` 读到 → issueCache 引用替换触发
- v2+ 的 `_isLoading` / `_data` / `_error` 在 build 的 if 条件中读到 → 必然追踪

**Cache 的 setQueryData / invalidate / notify 都不通知 page**，所以 page 必须订阅一个全局状态变化 hook 才能 catch 所有变化。

## 关键文件

- [cache.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/queries/cache.ets) — 加了 `onAnyStateChange`
- [InboxPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/InboxPage.ets) — 首次应用 v2 模式
- [MyIssuesPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/MyIssuesPage.ets)
- [IssueDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/IssueDetailPage.ets) — 2 query
- [ChatPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/ChatPage.ets)
- [AgentsPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/AgentsPage.ets)
- [ChatDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/ChatDetailPage.ets) — 2 query
- [NotificationsPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/NotificationsPage.ets)
- [ProjectDetailPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/ProjectDetailPage.ets) — 2 query

- [InboxPage.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/pages/InboxPage.ets)
- [queries/cache.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/queries/cache.ets)
- [queries/inbox.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/queries/inbox.ets)
- [lib/schemas.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/lib/schemas.ets)
- [lib/parse-response.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/lib/parse-response.ets)
- [realtime/realtime-hooks.ets](file:///Users/kinglong/mycode/multica/apps/harmonyos/entry/src/main/ets/realtime/realtime-hooks.ets)

## 计划

1. **Step 1（插桩）**：在 `InboxPage.build()` 顶部 + `useInboxQuery` 回调 + `cache.ets` 的 notify 处加 hilog
2. **Step 2（验证）**：用户重新跑 app，收集新 hilog
3. **Step 3（分析）**：根据证据确认/拒绝假设
4. **Step 4（修复）**：最小改动修复
5. **Step 5（验证）**：对比 pre-fix / post-fix 证据

## 进度

- [x] Step 0: 收集症状 + 运行时证据
- [ ] Step 1: 插桩
- [ ] Step 2: 收集 post-instrumentation 日志
- [ ] Step 3: 假设确认/拒绝
- [ ] Step 4: 实施修复
- [x] Step 4: 实施修复（v2）
- [ ] Step 5: 验证修复（v2）
- [ ] Step 6: 清理 + 关闭 session
