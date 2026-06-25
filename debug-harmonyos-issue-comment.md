# [OPEN] harmonyos-issue-comment

## 问题描述
鸿蒙应用在 issue 下发表评论时报错，界面显示 HTTP 400，同时日志出现 WebSocket error 200 undefined。

## 已知现象
- issue 评论输入后点击 Comment 出现 HTTP 400
- 日志显示 websocket service stop / finalized，随后重连
- 当前尚未确认是评论接口参数错误、鉴权问题，还是页面状态映射错误

## 初始假设
1. 评论提交接口的请求体字段名或结构与服务端期望不一致，导致返回 400。
2. issueId / workspaceId / actorId 等关键参数在页面路由或 store 映射中为空或错误。
3. HarmonyOS 端文本输入状态未正确同步，提交时发送了空字符串或被错误裁剪后的内容。
4. 评论提交共用了聊天消息发送逻辑，错误命中了错误的 API endpoint。
5. WebSocket error 200 只是伴随现象，真正失败点在 HTTP 评论请求本身。

## 调试计划
- 先阅读规范与相关代码，不修改业务逻辑。
- 找到 issue 评论提交入口、请求构造、API client 映射。
- 下一步仅添加最小化插桩，收集提交参数与响应证据。
