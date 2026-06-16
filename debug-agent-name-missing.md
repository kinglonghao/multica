# [OPEN] debug-agent-name-missing

## 症状
- 鸿蒙端 Issue 详情页里，Assignee/Activity 中的 Agent 仍显示为通用 `Agent`，没有实际名字。
- 期望：显示真实 Agent 名称。

## 当前假设
1. `issue.assignee_name` / `comment.author_name` 本身为空，而 `listAgents()` 返回的数据里对应 agent 缺失或未命中当前 `author_id`。
2. `listAgents()` 虽然返回了数据，但当前 IssueDetailPage 查询使用的 workspace 维度、缓存 key 或刷新时机不对，导致 `this.agents?.getState().data` 仍为空。
3. comment/issue 里的 `author_id` / `assignee_id` 与 agents 列表里的 `agent.id` 不一致（例如字段来源不同、uuid 为空、拿到的是别的 actor id）。
4. 名称解析命中了 `actorName()`，但返回的 `found.name` 为空串或全空白，最终又回退成 `Agent`。
5. IssueDetailPage 某处优先使用了 `assignee_name/author_name` 的旧字段，覆盖了 agents 列表里已存在的真实名称。

## 计划
- 先给 IssueDetailPage 的名称解析路径加埋点，不改业务逻辑。
- 让用户复现一次页面，收集 issue/comment/agents 相关运行时证据。
- 根据证据再做最小修复。
