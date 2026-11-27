# [OPEN] debug-settings-dark-screen

## Bug
- Mobile Settings 页从 light 切换到 dark 后出现白屏/近似白屏，第一次修复后仍可稳定复现。

## Symptoms
- 仅 Settings 页异常，其他 dark 区域基本正常。
- 用户反馈首次修复 `router.dismissAll()` 后问题仍然存在。

## Hypotheses
1. Settings 页根容器或 ScrollView 内容容器在 dark 下没有实际铺满，底层页面透出。
2. More dropdown/overlay 仍残留，但并非通过导航栈而是通过 portal / dropdown dismiss 时序造成。
3. 切换主题时 Settings 页重新渲染顺序异常，theme token 已切 dark，但某层背景仍保持 light/transparent。
4. HarmonyOS/Android 上 Stack + SafeAreaView + ScrollView 组合在 dark 切换时存在层级/合成问题，需要独立证据确认具体是哪一层。
5. 问题不是 Settings 页本体，而是上层 workspace layout / tabs 容器在该路由下背景未同步。

## Plan
- 给 settings 页、more dropdown、workspace layout 做最小插桩。
- 让用户复现一次 light -> dark -> settings 白屏路径。
- 根据日志判断是 overlay 残留、背景透出还是主题切换链路异常。
