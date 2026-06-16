# [OPEN] debug-agent-name-flaky

## 问题描述
鸿蒙端 Issue 评论流中，Agent 名字展示不稳定，一会显示真实名字，一会退回为 `Agent` 或丢失，头像也伴随不稳定。

## 当前现象
- 修复过 UI 侧预计算与 ForEach key 后，问题仍然存在
- 说明根因大概率不只是列表复用

## 初始假设
1. 评论接口返回的 `author_id` 与 `/api/agents` 返回的 `agent.id` 不是同一种 ID，导致有时匹配失败。
2. 评论接口中的 `author_name` / `author_avatar_url` 本身不稳定，某些刷新返回为空，UI fallback 后表现为忽有忽无。
3. 当前 workspace 变化或请求头中的 workspace slug 不稳定，导致同一 issue 页面有时查到的 agents 列表不是当前 issue 所属 workspace 的数据。
4. query cache 在 comments / agents 更新先后顺序上存在竞态，导致 `_commentDisplayMeta` 用旧 issue/旧 agents 预计算。
5. 某些 Agent 评论实际上服务端返回 `author_type` 或关联字段不一致，导致前端进入 member/unknown 分支。

## 排查计划
- 只加埋点，不改业务逻辑
- 记录 comment author 原始字段、issue workspace、当前 workspace、agents 首项与匹配结果
- 复现后根据日志确认是接口字段问题、ID 对不齐，还是 workspace/query 竞态
