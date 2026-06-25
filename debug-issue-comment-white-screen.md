# [OPEN] issue-comment-white-screen

## 问题描述
鸿蒙 issue 详情页在发表评论后出现白屏/骨架屏，页面未正常回到评论列表展示。

## 已知现象
- 评论提交已成功或至少流程进入提交后阶段
- 提交后 issue 页面出现大面积 skeleton / 白屏感
- 近期改动涉及评论请求体、评论作者名解析、Inbox 样式、Header 留白

## 初始假设
1. 评论提交成功后触发 comments/refetch，返回的评论数据结构与当前渲染逻辑不兼容，导致渲染阶段异常。
2. 提交评论后某个 query 状态被重置为 loading，但 refetch 因异常未完成，页面持续停留在骨架屏。
3. 新评论的 author 字段触发了 `commentAuthorName` / `commentAuthorAvatar` 中的空值或类型问题，导致构建阶段抛错。
4. `syncFromCache()` 在评论提交后的某次缓存同步中抛错，导致页面状态被中断。
5. issue 详情页的其他并行查询（issue / agents / members）在评论后被连带刷新，其中一个失败并使页面落入 loading/error 路径。

## 调试计划
- 先只添加最小插桩，不改业务逻辑。
- 记录 submitComment 前后、comments query 状态、syncFromCache、comment 渲染关键字段。
- 根据运行日志判断是数据形状问题还是 query 状态机问题。
