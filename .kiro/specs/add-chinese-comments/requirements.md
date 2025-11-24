# 需求文档：为 IceCubesApp 添加中文注释

## 介绍

IceCubesApp 是一个开源的 Mastodon 客户端，采用 SwiftUI + 模块化架构。项目包含 14 个 SPM 包和数百个 Swift 文件，目前大部分代码缺少中文注释，不利于中文开发者理解和学习。

本需求旨在为项目核心代码添加规范化的中文注释，帮助开发者快速理解代码结构和业务逻辑。

## 术语表

- **SPM (Swift Package Manager)**：Swift 包管理器，用于模块化管理
- **Observable**：Swift Observation 框架的宏，用于状态管理
- **Endpoint**：API 端点，定义网络请求的路径和参数
- **Actor**：Swift 并发模型中的线程安全类型
- **Mastodon**：去中心化社交网络平台
- **Status**：Mastodon 中的帖子/状态
- **Timeline**：时间线，显示帖子流

## 需求

### 需求 1：Models 包注释

**用户故事**：作为开发者，我想理解 Models 包中的数据模型，以便了解 Mastodon API 的数据结构。

#### 验收标准

1. WHEN 查看 Models 包的核心文件 THEN 系统应在文件顶部提供中文功能说明
2. WHEN 查看数据模型的属性 THEN 系统应为每个重要属性添加中文注释
3. WHEN 查看复杂的计算属性或方法 THEN 系统应提供中文逻辑说明
4. WHEN 查看嵌套类型 THEN 系统应说明其用途和关系
5. WHEN 查看协议定义 THEN 系统应说明协议的作用和实现要求

### 需求 2：NetworkClient 包注释

**用户故事**：作为开发者，我想理解网络层的实现，以便了解如何与 Mastodon API 交互。

#### 验收标准

1. WHEN 查看 MastodonClient THEN 系统应说明客户端的职责和使用方式
2. WHEN 查看 Endpoint 定义 THEN 系统应说明每个端点的用途和参数
3. WHEN 查看网络请求方法 THEN 系统应说明请求流程和错误处理
4. WHEN 查看认证逻辑 THEN 系统应说明 OAuth 流程
5. WHEN 查看响应解析 THEN 系统应说明数据转换过程

### 需求 3：Env 包注释

**用户故事**：作为开发者，我想理解全局状态管理，以便了解应用的核心数据流。

#### 验收标准

1. WHEN 查看 CurrentAccount THEN 系统应说明当前账户管理的职责
2. WHEN 查看 UserPreferences THEN 系统应说明用户偏好设置的存储和同步
3. WHEN 查看 Router THEN 系统应说明路由系统的工作原理
4. WHEN 查看 StreamWatcher THEN 系统应说明实时流监听的实现
5. WHEN 查看环境对象的单例模式 THEN 系统应说明为什么使用单例

### 需求 4：DesignSystem 包注释

**用户故事**：作为开发者，我想理解设计系统，以便了解主题和 UI 组件的使用。

#### 验收标准

1. WHEN 查看 Theme THEN 系统应说明主题系统的架构和切换机制
2. WHEN 查看通用 UI 组件 THEN 系统应说明组件的用途和使用示例
3. WHEN 查看可缩放字体 THEN 系统应说明字体系统的实现原理
4. WHEN 查看颜色定义 THEN 系统应说明颜色的语义化命名
5. WHEN 查看 ViewModifier THEN 系统应说明修饰符的作用和应用场景

### 需求 5：StatusKit 包注释

**用户故事**：作为开发者，我想理解帖子组件的实现，以便了解核心 UI 的构建方式。

#### 验收标准

1. WHEN 查看 StatusRowView THEN 系统应说明帖子行的布局和交互
2. WHEN 查看 StatusEditor THEN 系统应说明编辑器的功能和状态管理
3. WHEN 查看媒体处理 THEN 系统应说明图片上传和显示的流程
4. WHEN 查看操作按钮 THEN 系统应说明点赞、转发等交互的实现
5. WHEN 查看缓存策略 THEN 系统应说明 LRUCache 的使用场景

### 需求 6：Timeline 包注释

**用户故事**：作为开发者，我想理解时间线的实现，以便了解列表加载和缓存机制。

#### 验收标准

1. WHEN 查看 TimelineView THEN 系统应说明时间线的数据加载流程
2. WHEN 查看 TimelineDatasource THEN 系统应说明 Actor 的线程安全实现
3. WHEN 查看缓存逻辑 THEN 系统应说明 Bodega 的使用和数据持久化
4. WHEN 查看下拉刷新 THEN 系统应说明刷新机制和状态管理
5. WHEN 查看无限滚动 THEN 系统应说明分页加载的实现

### 需求 7：主应用入口注释

**用户故事**：作为开发者，我想理解应用的启动流程，以便了解环境对象的注入和初始化。

#### 验收标准

1. WHEN 查看 IceCubesApp.swift THEN 系统应说明应用的生命周期管理
2. WHEN 查看环境对象注入 THEN 系统应说明依赖注入的架构
3. WHEN 查看 AppDelegate THEN 系统应说明推送通知和后台任务的处理
4. WHEN 查看 SceneDelegate THEN 系统应说明多窗口管理
5. WHEN 查看启动配置 THEN 系统应说明第三方 SDK 的初始化

## 注释规范

### 文件顶部注释格式
```swift
// 文件功能：[一句话描述文件的主要功能]
// 
// 核心职责：
// - [职责 1]
// - [职责 2]
// - [职责 3]
//
// 技术要点：
// - [技术点 1]：[简要说明]
// - [技术点 2]：[简要说明]
//
// 依赖关系：
// - 依赖：[依赖的包或类]
// - 被依赖：[哪些模块使用本文件]
```

### 类/结构体注释格式
```swift
/// [类的用途和职责]
///
/// 使用示例：
/// ```swift
/// let example = MyClass()
/// example.doSomething()
/// ```
///
/// - Note: [重要说明]
/// - Warning: [警告信息]
public class MyClass {
```

### 方法注释格式
```swift
/// [方法的功能描述]
///
/// - Parameters:
///   - param1: [参数说明]
///   - param2: [参数说明]
/// - Returns: [返回值说明]
/// - Throws: [可能抛出的错误]
///
/// 实现逻辑：
/// 1. [步骤 1]
/// 2. [步骤 2]
/// 3. [步骤 3]
public func myMethod(param1: String, param2: Int) async throws -> Result {
```

### 属性注释格式
```swift
/// [属性的用途]
/// - Note: [使用注意事项]
public var myProperty: String

// 复杂计算属性需要说明逻辑
/// 计算用户的完整显示名称
/// 
/// 逻辑：
/// - 如果有 displayName 且非空，返回 displayName
/// - 否则返回 @username 格式
public var fullName: String {
    // 实现
}
```

## 优先级

1. **P0（最高优先级）**：
   - Models 包核心模型（Status, Account）
   - NetworkClient 核心类（MastodonClient, Endpoint）
   - Env 包核心服务（CurrentAccount, Router）

2. **P1（高优先级）**：
   - DesignSystem 包（Theme, 通用组件）
   - StatusKit 包（StatusRowView, StatusEditor）
   - Timeline 包（TimelineView, Datasource）

3. **P2（中优先级）**：
   - Account, Notifications, Explore 等功能包
   - 主应用入口和配置

4. **P3（低优先级）**：
   - 扩展和工具类
   - 测试文件

## 非功能需求

1. **一致性**：所有注释遵循统一的格式和风格
2. **准确性**：注释内容与代码实现保持一致
3. **简洁性**：避免冗长的注释，重点说明关键逻辑
4. **可维护性**：注释易于更新，不会过时
5. **教育性**：注释应帮助读者理解 SwiftUI 和现代 Swift 的最佳实践
