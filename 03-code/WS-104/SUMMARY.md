# WS-104 — [HarmonyOS][M1] 稳定基线：类型镜像、WS 断言、payload 兜底与 CI smoke

## 任务概述

完成里程碑 1 的稳定基线建设，解决父 Issue `WS-103` 梳理出的三个 P0 稳定性缺口：

1. WebSocket 事件名与上游 `packages/core/types/events.ts` 漂移（鸿蒙端只有 15/71 个事件名）。
2. API 响应缺少 `parseWithFallback` 兜底（直接 `JSON.parse` 后 `as T`，坏 payload 会白屏）。
3. CI 完全未覆盖 `apps/harmonyos/`。

## 变更范围

### 新增文件

| 路径 | 作用 |
|---|---|
| `apps/harmonyos/entry/src/main/ets/lib/ws-events.ets` | 运行时事件注册表（71 个事件名）。`ws-client.ets::dispatch()` 用它做漂移检测。 |
| `apps/harmonyos/entry/src/main/ets/lib/parse-response.ets` | `parseWithFallback<T>` 兜底解析器。手写实现，规避 ArkTS 严格模式对 zod 的不兼容。 |
| `apps/harmonyos/entry/src/main/ets/lib/schemas.ets` | 6 类核心实体的 schema + `EMPTY_*` fallback 常量。 |
| `apps/harmonyos/entry/src/ohosTest/ets/test/parse-response.test.ets` | `parseWithFallback` 单元测试（happy path + 失败路径 + 不抛异常）。 |
| `apps/harmonyos/entry/src/ohosTest/ets/test/realtime-contract.test.ets` | WS payload 形状契约测试 + `assertWSEventRegistry` 启动期断言测试。 |
| `scripts/diff-harmonyos-types.mjs` | 漂移检测脚本，比对上游 union / 鸿蒙 union / 运行时注册表三方一致性。 |
| `.github/workflows/harmonyos-smoke.yml` | 鸿蒙 CI 静态闸门（drift gate + 结构检查 + ArkTS 括号平衡）。 |

### 修改文件

| 路径 | 修改 |
|---|---|
| `apps/harmonyos/entry/src/main/ets/models/types.ets` | `WSEventType` union 从 15 个事件扩展到 71 个，与上游 `packages/core/types/events.ts` 对齐。 |
| `apps/harmonyos/entry/src/main/ets/realtime/ws-client.ets` | 引入 `isKnownWSEvent` 检测已知事件漏注册；新增 `assertWSEventRegistry()` 启动期断言 + `registeredEventNames()` 公开 API。 |
| `apps/harmonyos/entry/src/main/ets/data/api.ets` | 7 个读端点接入 `parseWithFallback`（`listInbox`、`listIssues`、`getIssue`、`listComments`、`createComment`、`updateComment`、`listProjects`、`getProject`、`listChatMessages`、`listAgentTasks`）。覆盖 Issue / Comment / Project / InboxItem / AgentTask / ChatMessage + 三个 list envelope。 |
| `apps/harmonyos/entry/src/ohosTest/ets/test/List.test.ets` | 注册新增的两个测试套件。 |
| `apps/harmonyos/CLAUDE.md` | 增补 "rebase / merge `main` 后跑 diff 脚本" 的硬性约束 + 运行时注册表的必要性说明。 |

## 关键实现

### 1. WS 事件名三源一致性

```
packages/core/types/events.ts::WSEventType  (上游, 71 个)
        ↓ 手动镜像
apps/harmonyos/.../models/types.ets::WSEventType  (71 个)
        ↓ 手动镜像
apps/harmonyos/.../lib/ws-events.ets::WSEventNames  (71 个, 运行时)
```

三源必须保持一致，否则 `scripts/diff-harmonyos-types.mjs` 在 CI 中会失败。脚本是纯 Node、无依赖，可在每次 PR 上跑。

### 2. parseWithFallback 手写版

ArkTS 严格模式禁用 `any`，zod 的 TypeScript 输出依赖动态属性访问，无法在鸿蒙构建中运行。`lib/parse-response.ets` 提供一个 30 行级别的 `Schema<T> = { validate(value): { success, data } | { success: false, error, issues } }` 接口，`parseWithFallback` 在 `validate` 失败时返回 fallback + 写 warn 日志，**绝不抛入 UI**。契约与 iOS 的 `apps/mobile/lib/parse-response.ts` 完全对齐。

### 3. WS 启动期断言

`ws-client.ets` 新增 `assertWSEventRegistry(): { total, unhandled }`：启动时遍历 `WSEventNames`，报告本地无 handler 的事件名。注册表为空时（最严重的"静默吞所有事件"模式）直接 `throw`。

`dispatch()` 在事件名 `isKnownWSEvent` 但 `handlers.get(event).size === 0` 时打 warn 日志（避免 throw 阻塞 socket 主循环）。

### 4. CI 烟囱

`.github/workflows/harmonyos-smoke.yml` 跑：
1. `node scripts/diff-harmonyos-types.mjs`（drift gate）
2. 必填文件存在性检查
3. 事件计数三方一致性（grep + 对比）
4. ArkTS 源文件括号 / 大括号 / 方括号平衡（Python 实现，正确处理字符串和注释）

完整的 `hvigorw assembleHap` + `ohosTest` 需要 HarmonyOS SDK（多 GB），不适合 Linux runner。Workflow 文档化了本地完整构建步骤，留 `harmonyos-build-manual` 占位 job（`if: false`）供后续接入社区 Action 时替换。

## 风险与兼容性

- **API 行为变更**：`api.listInbox`、`api.listIssues`、`api.getIssue`、`api.listComments`、`api.createComment`、`api.updateComment`、`api.listProjects`、`api.getProject`、`api.listChatMessages`、`api.listAgentTasks` 现在在坏 payload 下返回 `EMPTY_*` 而非抛 `ApiError`。下游 UI 应检查 `id === ''` 等 sentinel 值（`IssueDetailPage` 等已存在的页面已按这个模式编写，新接入的页面需要跟进）。
- **写入端点未做 fallback**：comment / issue / project 的写端点保持原样（写失败应该让上层 optimistic patch 回滚，不应该 silent-fallback）。
- **`WSEventType` union 末尾的 `| string`**：刻意保留，保证鸿蒙端不会因为上游新增未镜像的事件而崩溃，配合 `lib/ws-events.ets` 做 loud-detection 而非 hard-block。

## 验证结果

```text
$ node scripts/diff-harmonyos-types.mjs
upstream (packages/core/types/events.ts)        : 71 events
harmonyos types.ets::WSEventType                : 71 events
harmonyos lib/ws-events.ets::WSEventNames       : 71 events
[diff-harmonyos-types] OK — all three sources are in lockstep (71 events).

$ # Drift-detection check (after temporarily deleting one entry)
$ # Exit code: 1 — script correctly fails on drift.
```

CI 工作流的 4 个静态检查全部在本机通过（72 个 .ets 文件括号平衡、所有必填文件存在、三方事件计数均为 71）。

由于鸿蒙 SDK 在 Linux runner 上不可用，`hvigorw assembleHap` + `ohosTest` 的完整运行需要在本地 DevEco Studio 环境下执行：
```bash
cd apps/harmonyos
hvigorw assembleHap --mode module -p product=default
hvigorw ohosTest --mode module -p product=default
```

新增的单元测试（`parse-response.test.ets`、`realtime-contract.test.ets`）已注册到 `ohosTest/ets/test/List.test.ets`，等待本地 hvigorw 环境运行验证。

## 分支信息

- 工作分支：`feat/harmonyos-mobile`（已与 `main` 同步）
- 提交尚未推送，下一步会按任务流程推送。

## 关联提交

待 `git push` 后回填。