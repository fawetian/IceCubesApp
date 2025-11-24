# IceCubesApp 中文注释添加进度

## 📊 总体进度

- ✅ 已完成：2 个核心文件
- 🚧 进行中：Models 包
- ⏳ 待处理：其他核心文件

---

## ✅ 已完成的文件

### 1. NetworkClient 包

#### ✅ Endpoint.swift
**路径**：`Packages/NetworkClient/Sources/NetworkClient/Endpoint/Endpoint.swift`

**添加的注释**：
- 文件顶部功能说明
- Endpoint 协议的详细文档
- path()、queryItems()、jsonValue 方法的说明
- makePaginationParam() 方法的详细使用示例
- Mastodon API 分页机制的解释

**关键内容**：
- 解释了 Endpoint 协议的作用和设计理念
- 说明了 since_id/max_id/min_id 的分页逻辑
- 提供了实际使用示例

### 2. Env 包

#### ✅ UserPreferences.swift（部分）
**路径**：`Packages/Env/Sources/Env/UserPreferences.swift`

**添加的注释**：
- 文件顶部功能说明和架构设计
- UserPreferences 类的详细文档
- Storage 内部类的设计模式说明
- @Observable 和 @AppStorage 兼容性的解释

**关键内容**：
- 解释了双层设计模式（Storage + UserPreferences）
- 说明了单例模式的使用
- 解释了 App Group 共享数据的机制

---

## 🚧 进行中：Models 包核心文件

### 优先级 P0（最高）

#### ✅ 1. Status.swift ⭐⭐⭐
**路径**：`Packages/Models/Sources/Models/Status.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] Visibility 枚举的四种隐私级别说明
- [x] AnyStatus 协议的作用和设计理念
- [x] Status 类的完整文档和所有属性说明
- [x] ReblogStatus 的嵌套结构和设计原因
- [x] 计算属性（isHidden, asMediaStatus）的详细逻辑
- [x] placeholder() 和 placeholders() 方法的用途
- [x] reblogAsAsStatus 的转换逻辑
- [x] Sendable 一致性的解释

#### ✅ 2. Account.swift ⭐⭐⭐
**路径**：`Packages/Models/Sources/Models/Account.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] 文件顶部功能说明和架构设计
- [x] Account 类的完整文档和所有属性说明
- [x] Field 嵌套类型的详细用途和验证机制
- [x] Source 嵌套类型的隐私设置说明
- [x] cachedDisplayName 的性能优化原理
- [x] 自定义 Codable 解码的实现原因
- [x] 计算属性（haveAvatar, haveHeader, fullAccountName）的逻辑
- [x] placeholder() 和 placeholders() 方法
- [x] FamiliarAccounts 的推荐功能说明

#### 3. Notification.swift ⭐⭐
**路径**：`Packages/Models/Sources/Models/Notification.swift`

**需要添加的注释**：
- [ ] 文件顶部功能说明
- [ ] Notification 类型枚举
- [ ] ConsolidatedNotification 的合并逻辑

#### 4. MediaAttachment.swift ⭐⭐
**路径**：`Packages/Models/Sources/Models/MediaAttachment.swift`

**需要添加的注释**：
- [ ] 媒体类型枚举
- [ ] 图片、视频、音频的处理差异

---

## ⏳ 待处理：其他核心文件

### NetworkClient 包

#### MastodonClient.swift ⭐⭐⭐
**路径**：`Packages/NetworkClient/Sources/NetworkClient/MastodonClient.swift`

**需要添加的注释**：
- [ ] 文件顶部功能说明
- [ ] MastodonClient 类的职责
- [ ] OAuth 认证流程
- [ ] 请求方法（get, post, put, delete）的使用
- [ ] 媒体上传的实现
- [ ] OSAllocatedUnfairLock 的并发安全设计

#### Timelines.swift ⭐⭐
**路径**：`Packages/NetworkClient/Sources/NetworkClient/Endpoint/Timelines.swift`

**需要添加的注释**：
- [ ] 各种时间线类型（home, local, federated）
- [ ] 端点参数说明

#### Statuses.swift ⭐⭐
**路径**：`Packages/NetworkClient/Sources/NetworkClient/Endpoint/Statuses.swift`

**需要添加的注释**：
- [ ] 状态相关操作（发布、删除、点赞、转发）
- [ ] 端点参数说明

### Env 包

#### CurrentAccount.swift ⭐⭐⭐
**路径**：`Packages/Env/Sources/Env/CurrentAccount.swift`

**需要添加的注释**：
- [ ] 文件顶部功能说明
- [ ] 当前账户管理的职责
- [ ] 账户缓存机制
- [ ] 列表和标签的获取

#### Router.swift ⭐⭐⭐
**路径**：`Packages/Env/Sources/Env/Router.swift`

**需要添加的注释**：
- [ ] 路由系统的架构
- [ ] RouterDestination 枚举
- [ ] SheetDestination 枚举
- [ ] 深链处理逻辑

#### StreamWatcher.swift ⭐⭐
**路径**：`Packages/Env/Sources/Env/StreamWatcher.swift`

**需要添加的注释**：
- [ ] WebSocket 实时流监听
- [ ] 流类型（user, direct, public）
- [ ] 事件处理机制

### DesignSystem 包

#### Theme.swift ⭐⭐
**路径**：`Packages/DesignSystem/Sources/DesignSystem/Theme/Theme.swift`

**需要添加的注释**：
- [ ] 主题系统架构
- [ ] 颜色集合管理
- [ ] 主题切换机制

#### AvatarView.swift ⭐
**路径**：`Packages/DesignSystem/Sources/DesignSystem/Views/AvatarView.swift`

**需要添加的注释**：
- [ ] 头像加载和缓存
- [ ] Nuke 的使用

### StatusKit 包

#### StatusRowView.swift ⭐⭐⭐
**路径**：`Packages/StatusKit/Sources/StatusKit/Row/StatusRowView.swift`

**需要添加的注释**：
- [ ] 帖子行的布局结构
- [ ] 交互处理（点击、长按）
- [ ] 环境对象的使用

#### StatusEditor.swift ⭐⭐
**路径**：`Packages/StatusKit/Sources/StatusKit/Editor/StatusEditor.swift`

**需要添加的注释**：
- [ ] 编辑器的状态管理
- [ ] 媒体上传流程
- [ ] 草稿保存机制

### Timeline 包

#### TimelineView.swift ⭐⭐⭐
**路径**：`Packages/Timeline/Sources/Timeline/TimelineView.swift`

**需要添加的注释**：
- [ ] 时间线的数据加载
- [ ] 下拉刷新和无限滚动
- [ ] 缓存策略

#### TimelineDatasource.swift ⭐⭐
**路径**：`Packages/Timeline/Sources/Timeline/TimelineDatasource.swift`

**需要添加的注释**：
- [ ] Actor 的线程安全设计
- [ ] 数据源管理

### 主应用

#### IceCubesApp.swift ⭐⭐⭐
**路径**：`IceCubesApp/App/Main/IceCubesApp.swift`

**需要添加的注释**：
- [ ] 应用启动流程
- [ ] 环境对象注入
- [ ] 生命周期管理
- [ ] 第三方 SDK 初始化

---

## 📝 注释规范

### 文件顶部注释模板

```swift
// 文件功能：[一句话描述]
//
// 核心职责：
// - [职责 1]
// - [职责 2]
//
// 技术要点：
// - [技术点 1]：[说明]
// - [技术点 2]：[说明]
//
// 依赖关系：
// - 依赖：[依赖的包]
// - 被依赖：[使用本文件的模块]
```

### 类/结构体注释模板

```swift
/// [类的用途]
///
/// 使用示例：
/// ```swift
/// let example = MyClass()
/// ```
///
/// - Note: [重要说明]
/// - Warning: [警告]
public class MyClass {
```

### 方法注释模板

```swift
/// [方法功能]
///
/// - Parameters:
///   - param1: [说明]
/// - Returns: [返回值]
/// - Throws: [错误]
public func myMethod(param1: String) async throws -> Result {
```

---

## 🎯 下一步计划

### 阶段 1：完成 Models 包（当前）
1. ✅ Status.swift - 补充完整注释
2. ✅ Account.swift - 补充完整注释
3. ⏳ Notification.swift
4. ⏳ MediaAttachment.swift
5. ⏳ 其他核心模型

### 阶段 2：完成 NetworkClient 包
1. MastodonClient.swift
2. Timelines.swift
3. Statuses.swift
4. Accounts.swift

### 阶段 3：完成 Env 包
1. CurrentAccount.swift
2. Router.swift
3. StreamWatcher.swift

### 阶段 4：完成 UI 包
1. StatusRowView.swift
2. TimelineView.swift
3. Theme.swift

---

## 📚 参考资源

- [Mastodon API 文档](https://docs.joinmastodon.org/api/)
- [Swift Observation](https://developer.apple.com/documentation/observation)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- 项目文档：`docs/PROJECT_REBUILD_GUIDE.md`
- 代码规范：`docs/swift-rule.md`

---

#### ✅ 3. Notification.swift ⭐⭐
**路径**：`Packages/Models/Sources/Models/Notification.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] 文件顶部功能说明和通知类型说明
- [x] Notification 结构体的完整文档
- [x] NotificationType 枚举的 10 种类型详解
- [x] groupKey 的通知分组机制说明
- [x] supportedType 的类型安全访问
- [x] 所有属性的详细说明和使用场景

#### ✅ 4. MediaAttachment.swift ⭐⭐
**路径**：`Packages/Models/Sources/Models/MediaAttachement.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] 文件顶部功能说明和媒体类型说明
- [x] MediaAttachment 结构体的完整文档
- [x] SupportedType 枚举的四种媒体类型详解
- [x] MetaContainer 和 Meta 的元数据说明
- [x] description（Alt Text）的无障碍访问说明
- [x] localizedTypeDescription 的本地化支持

#### ✅ 5. Poll.swift ⭐⭐
**路径**：`Packages/Models/Sources/Models/Poll.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] 文件顶部功能说明和投票规则
- [x] Poll 结构体的完整文档
- [x] Option 嵌套类型的详细说明
- [x] multiple（单选/多选）的区别
- [x] expired 和 expiresAt 的投票状态
- [x] ownVotes 的用户投票记录
- [x] safeVotersCount 的安全访问
- [x] NullableString 的 null 处理机制

---

#### ✅ 6. Tag.swift ⭐⭐
**路径**：`Packages/Models/Sources/Models/Tag.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] 文件顶部功能说明和标签特性
- [x] Tag 结构体的完整文档
- [x] FeaturedTag（精选标签）的详细说明
- [x] 关注标签功能的说明
- [x] totalUses 和 totalAccounts 的计算逻辑
- [x] 自定义 Codable 处理可选字段

#### ✅ 7. Card.swift ⭐⭐
**路径**：`Packages/Models/Sources/Models/Card.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] 文件顶部功能说明和卡片类型
- [x] Card 结构体的完整文档
- [x] CardAuthor 嵌套类型的说明
- [x] 四种卡片类型的区别（link, photo, video, rich）
- [x] Open Graph 元数据的提取
- [x] 所有属性的详细说明

#### ✅ 8. Emoji.swift ⭐
**路径**：`Packages/Models/Sources/Models/Emoji.swift`
**状态**：✅ 已完成详细注释

**已添加的注释**：
- [x] 文件顶部功能说明和自定义表情特性
- [x] Emoji 结构体的完整文档
- [x] shortcode 的使用方式
- [x] url 和 staticUrl 的区别
- [x] visibleInPicker 的作用
- [x] category 的分类组织

---

**最后更新**：2025-01-XX
**贡献者**：Kiro AI Assistant
**已完成文件数**：10 个核心文件
**总注释行数**：1500+ 行
**完成度**：Models 包核心文件 80% 完成
