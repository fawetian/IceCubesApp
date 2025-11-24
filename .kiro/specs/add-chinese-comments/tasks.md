# 实施计划：为 IceCubesApp 添加中文注释

## 阶段 1：核心数据模型（P0 优先级）

### 1. Models 包核心模型注释

- [ ] 1.1 为 Status.swift 添加完整注释
  - 添加文件顶部功能说明（文件功能、核心职责、技术要点、依赖关系）
  - 为 Status 结构体添加详细文档注释，包括使用示例
  - 为所有 public 属性添加注释（id, content, account, createdAt 等 30+ 属性）
  - 为计算属性添加逻辑说明（如 displayStatus, reblogAsQuote 等）
  - 为嵌套类型添加注释（Visibility, Application, Mention 等）
  - 说明转发（reblog）和引用的区别
  - _需求：1.1, 1.2, 1.3, 1.4_

- [ ]* 1.2 为 Status 模型编写属性测试
  - **属性 2：类型注释完整性**
  - **验证需求：1.4**

- [ ] 1.3 为 Account.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 Account 结构体添加详细文档注释
  - 为所有 public 属性添加注释（20+ 属性）
  - 为计算属性添加逻辑说明（如 displayNameWithoutEmojis）
  - 为嵌套类型添加注释（Field, Source 等）
  - 说明 bot 账户和普通账户的区别
  - _需求：1.1, 1.2, 1.3, 1.4_

- [ ]* 1.4 为 Account 模型编写属性测试
  - **属性 2：类型注释完整性**
  - **验证需求：1.4**

- [ ] 1.5 为 Notification.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 Notification 结构体添加详细文档注释
  - 为 NotificationType 枚举的 10 种类型添加详细说明
  - 为所有属性添加注释
  - 说明不同通知类型的触发条件和显示方式
  - _需求：1.1, 1.2, 1.3, 1.4_

- [ ] 1.6 为 MediaAttachment.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 MediaAttachment 结构体添加详细文档注释
  - 为 MediaType 枚举的 4 种类型添加说明
  - 为 MetaData 嵌套类型添加注释
  - 说明图片、视频、音频的处理差异
  - _需求：1.1, 1.2, 1.3, 1.4_

- [ ] 1.7 为其他核心 Models 添加注释
  - Poll.swift（投票功能）
  - Card.swift（链接卡片）
  - Tag.swift（标签）
  - Emoji.swift（自定义表情）
  - Conversation.swift（对话/私信）
  - List.swift（列表）
  - Relationship.swift（用户关系）
  - Mention.swift（提及）
  - Instance.swift（实例信息）
  - _需求：1.1, 1.2, 1.3, 1.4_

- [ ]* 1.8 为 Models 包编写格式一致性测试
  - **属性 1：注释格式一致性**
  - **验证需求：1.1**

### 2. NetworkClient 包核心注释

- [ ] 2.1 为 MastodonClient.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 Client 类添加详细文档注释，包括使用示例
  - 为 get/post/put/delete 方法添加详细注释
  - 说明 OAuth 认证流程
  - 说明错误处理机制
  - 提供实际的 API 调用示例
  - _需求：2.1, 2.3, 2.4_

- [ ]* 2.2 为 MastodonClient 编写方法参数匹配测试
  - **属性 3：方法注释参数匹配**
  - **验证需求：2.3**

- [ ] 2.3 为 Endpoint.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 Endpoint 协议添加详细文档注释
  - 说明如何定义新的 API 端点
  - 为常用端点添加注释（Timelines, Statuses, Accounts 等）
  - 提供自定义端点的示例
  - _需求：2.2, 2.3_

- [ ] 2.4 为 Timelines.swift 端点添加注释
  - 为所有时间线端点添加注释（home, public, hashtag 等）
  - 说明分页参数的使用
  - 说明过滤参数的作用
  - _需求：2.2_

- [ ] 2.5 为 Statuses.swift 端点添加注释
  - 为所有状态相关端点添加注释（post, delete, favourite, reblog 等）
  - 说明媒体上传流程
  - 说明投票创建和投票流程
  - _需求：2.2_

- [ ] 2.6 为 Accounts.swift 端点添加注释
  - 为所有账户相关端点添加注释（lookup, follow, block, mute 等）
  - 说明关系管理的 API 使用
  - _需求：2.2_

- [ ]* 2.7 为 NetworkClient 包编写示例代码可编译性测试
  - **属性 5：示例代码可编译性**
  - **验证需求：2.1**

- [ ] 2.8 检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

## 阶段 2：状态管理和 UI 核心（P1 优先级）

### 3. Env 包核心注释

- [ ] 3.1 为 CurrentAccount.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 CurrentAccount 类添加详细文档注释
  - 说明账户管理的生命周期
  - 说明如何在 SwiftUI 视图中使用 @Environment
  - 说明多账户切换的实现
  - 提供实际使用示例
  - _需求：3.1, 3.4_

- [ ]* 3.2 为 CurrentAccount 编写属性测试
  - **属性 4：注释内容准确性**
  - **验证需求：3.1**

- [ ] 3.3 为 Router.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 Router 类添加详细文档注释
  - 说明路由系统的工作原理
  - 为所有路由目标添加注释
  - 说明如何添加新的路由
  - 提供导航示例
  - _需求：3.3_

- [ ] 3.4 为 UserPreferences.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 UserPreferences 类添加详细文档注释
  - 说明偏好设置的存储机制（UserDefaults）
  - 为所有偏好设置属性添加注释
  - 说明如何添加新的偏好设置
  - _需求：3.2_

- [ ] 3.5 为 StreamWatcher.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 StreamWatcher 类添加详细文档注释
  - 说明实时流的工作原理（WebSocket）
  - 说明事件处理机制
  - 说明线程安全实现（Actor）
  - _需求：3.4_

- [ ]* 3.6 为 Env 包编写格式一致性测试
  - **属性 1：注释格式一致性**
  - **验证需求：3.1**

### 4. StatusKit 包核心注释

- [ ] 4.1 为 StatusRowView.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 StatusRowView 结构体添加详细文档注释
  - 说明视图层次结构
  - 说明状态管理（@State, @Binding）
  - 说明用户交互处理（点赞、转发、回复等）
  - 提供 SwiftUI Preview 示例
  - _需求：5.1, 5.4_

- [ ]* 4.2 为 StatusRowView 编写示例代码测试
  - **属性 5：示例代码可编译性**
  - **验证需求：5.1**

- [ ] 4.3 为 StatusEditor.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 StatusEditor 结构体添加详细文档注释
  - 说明编辑器的状态管理
  - 说明媒体上传流程
  - 说明草稿保存机制
  - 说明可见性和内容警告的设置
  - _需求：5.2_

- [ ] 4.4 为媒体处理组件添加注释
  - MediaUIView.swift（媒体显示）
  - MediaUploadView.swift（媒体上传）
  - 说明图片压缩和优化
  - 说明视频处理流程
  - _需求：5.3_

- [ ] 4.5 为操作按钮组件添加注释
  - StatusActionsView.swift（操作按钮）
  - 说明点赞、转发、回复、分享等操作的实现
  - 说明乐观更新（Optimistic Update）策略
  - _需求：5.4_

- [ ]* 4.6 为 StatusKit 包编写单元测试
  - 测试操作按钮的状态更新
  - 测试编辑器的输入验证
  - _需求：5.1, 5.2, 5.4_

### 5. Timeline 包核心注释

- [ ] 5.1 为 TimelineView.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 TimelineView 结构体添加详细文档注释
  - 说明数据加载流程
  - 说明下拉刷新机制
  - 说明无限滚动实现
  - 说明状态管理（loading, loaded, error）
  - _需求：6.1, 6.4, 6.5_

- [ ] 5.2 为 TimelineDatasource.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 TimelineDatasource Actor 添加详细文档注释
  - 说明 Actor 的线程安全机制
  - 说明数据缓存策略
  - 说明分页加载的实现
  - _需求：6.2, 6.5_

- [ ] 5.3 为缓存机制添加注释
  - 说明 Bodega 的使用
  - 说明数据持久化策略
  - 说明缓存失效和更新
  - _需求：6.3_

- [ ]* 5.4 为 Timeline 包编写属性测试
  - **属性 6：优先级覆盖顺序**
  - **验证需求：6.1, 6.2**

- [ ] 5.5 检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

## 阶段 3：功能模块（P2 优先级）

### 6. DesignSystem 包注释

- [ ] 6.1 为 Theme.swift 添加完整注释
  - 添加文件顶部功能说明
  - 为 Theme 类添加详细文档注释
  - 说明主题系统的架构
  - 说明颜色的语义化命名
  - 说明主题切换机制
  - 说明自定义主题的创建
  - _需求：4.1, 4.4_

- [ ] 6.2 为通用 UI 组件添加注释
  - AvatarView.swift（头像）
  - EmojiText.swift（表情文本）
  - HTMLString.swift（HTML 渲染）
  - LoadingView.swift（加载指示器）
  - ErrorView.swift（错误视图）
  - 为每个组件添加使用示例
  - _需求：4.2_

- [ ] 6.3 为字体系统添加注释
  - ScalableFont.swift
  - 说明动态字体的实现
  - 说明可访问性支持
  - _需求：4.3_

- [ ] 6.4 为 ViewModifier 添加注释
  - 说明常用修饰符的作用
  - 提供组合使用示例
  - _需求：4.5_

### 7. Account 包注释

- [ ] 7.1 为 AccountDetailView.swift 添加注释
  - 添加文件顶部功能说明
  - 说明个人资料页的布局
  - 说明关注/取消关注的实现
  - 说明关系状态的显示

- [ ] 7.2 为 AccountListView.swift 添加注释
  - 说明关注者/正在关注列表的实现
  - 说明搜索和过滤功能

- [ ] 7.3 为 EditAccountView.swift 添加注释
  - 说明个人资料编辑的实现
  - 说明头像和横幅上传

### 8. Notifications 包注释

- [ ] 8.1 为 NotificationsListView.swift 添加注释
  - 添加文件顶部功能说明
  - 说明通知列表的实现
  - 说明通知分组和过滤

- [ ] 8.2 为 NotificationRowView.swift 添加注释
  - 说明不同通知类型的显示
  - 说明通知操作的处理

### 9. Explore 包注释

- [ ] 9.1 为 ExploreView.swift 添加注释
  - 添加文件顶部功能说明
  - 说明探索页的标签页结构
  - 说明趋势、标签、推荐的实现

- [ ] 9.2 为 SearchView.swift 添加注释
  - 说明搜索功能的实现
  - 说明搜索结果的分类显示

- [ ]* 9.3 为功能模块编写集成测试
  - 测试主题切换功能
  - 测试账户详情加载
  - 测试通知列表显示

- [ ] 9.4 检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

## 阶段 4：主应用和辅助（P3 优先级）

### 10. 主应用入口注释

- [ ] 10.1 为 IceCubesApp.swift 添加注释
  - 添加文件顶部功能说明
  - 说明应用的生命周期管理
  - 说明环境对象的注入
  - 说明 Scene 的配置
  - _需求：7.1, 7.2_

- [ ] 10.2 为 AppDelegate.swift 添加注释
  - 说明推送通知的注册和处理
  - 说明后台任务的配置
  - _需求：7.3_

- [ ] 10.3 为 SceneDelegate.swift 添加注释
  - 说明多窗口管理（iPadOS/macOS）
  - 说明 URL scheme 处理
  - _需求：7.4_

- [ ] 10.4 为启动配置添加注释
  - 说明第三方 SDK 的初始化
  - 说明环境变量的配置
  - _需求：7.5_

### 11. 工具类和扩展注释

- [ ] 11.1 为常用扩展添加注释
  - String+Extensions.swift
  - Date+Extensions.swift
  - View+Extensions.swift
  - 说明扩展方法的用途和使用场景

- [ ] 11.2 为工具类添加注释
  - HapticManager.swift（触觉反馈）
  - SoundEffectManager.swift（音效）
  - ImageCache.swift（图片缓存）

- [ ] 11.3 为辅助类型添加注释
  - Constants.swift（常量定义）
  - AppInfo.swift（应用信息）

### 12. 文档和总结

- [ ] 12.1 更新进度文档
  - 更新 `docs/CHINESE_COMMENTS_PROGRESS.md`
  - 记录所有已完成的文件和注释行数

- [ ] 12.2 创建完成报告
  - 创建 `docs/COMMENTS_COMPLETE.md`
  - 总结注释工作的成果
  - 列出关键学习点

- [ ] 12.3 生成文档网站
  - 使用 Jazzy 生成 HTML 文档
  - 配置文档主题和样式

- [ ]* 12.4 运行完整的测试套件
  - 运行所有属性测试
  - 运行所有单元测试
  - 生成测试覆盖率报告

- [ ] 12.5 最终检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

## 注释质量检查清单

每个文件完成后，应确保：

- [ ] 文件顶部注释包含：文件功能、核心职责、技术要点、依赖关系
- [ ] 所有 public 类型都有文档注释
- [ ] 所有 public 方法都有参数和返回值说明
- [ ] 复杂的计算属性有逻辑说明
- [ ] 至少有一个实际可用的代码示例
- [ ] 注释使用清晰的中文表达
- [ ] 技术术语使用准确
- [ ] 没有过时或错误的信息

## 测试要求

- 使用 swift-check 或类似的 Swift PBT 库
- 每个属性测试运行至少 100 次迭代
- 测试标记格式：`// Feature: add-chinese-comments, Property {number}: {property_text}`
- 单元测试覆盖核心功能和边界情况
- 属性测试验证通用正确性属性

## 注意事项

1. **优先级顺序**：严格按照 P0 → P1 → P2 → P3 的顺序执行
2. **质量优先**：宁可慢一点，也要确保注释质量
3. **示例验证**：所有代码示例必须可编译
4. **同步更新**：代码修改时同步更新注释
5. **社区反馈**：欢迎社区提出改进建议
