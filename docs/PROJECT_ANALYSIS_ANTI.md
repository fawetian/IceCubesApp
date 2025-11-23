# 项目拆解与重构指南

## 第一部分：架构分析报告

### 1. 核心架构 🏗️
项目采用 **模块化 MVVM (Modular MVVM)** 架构，结合 **Swift 5.9 Observation** 框架进行状态管理。

*   **架构模式**: MVVM (Model-View-ViewModel)。
    *   **View**: SwiftUI 视图，负责 UI 展示。
    *   **ViewModel**: 负责业务逻辑和状态持有 (如 `TimelineViewModel`, `StatusRowViewModel`)。
    *   **Model**: 数据模型 (在 `Models` 包中)。
*   **数据流向**:
    *   **单向数据流**: View 触发 Action -> ViewModel 调用 Service/Client -> 更新 State -> View 自动刷新 (基于 `@Observable`)。
    *   **全局状态**: 通过 `Env` 包中的单例 (如 `CurrentAccount`, `UserPreferences`) 注入到环境中，实现跨模块状态共享。
*   **并发模型**: 深度使用 Swift Concurrency (`async/await`, `Task`, `Actor`)。特别是在 `Timeline` 模块中使用了 `actor` (`TimelineDatasource`) 来保证数据处理的线程安全。

### 2. 关键技术栈 🛠️
*   **语言版本**: Swift 6 (激进地采用了最新语言特性)。
*   **UI 框架**: SwiftUI (iOS 18+, visionOS 1+)。
*   **状态管理**: Swift Observation Framework (`@Observable` 宏)，取代了传统的 `Combine` `@Published`。
*   **网络层**: 自定义封装的 `URLSession` (在 `NetworkClient` 包中)，未使用 Alamofire。
*   **关键依赖**:
    *   **Nuke**: 高性能图片加载与缓存。
    *   **EmojiText**: 自定义 Emoji 渲染 (支持 Mastodon 自定义表情)。
    *   **RevenueCat**: 应用内订阅管理。
    *   **KeychainSwift**: 安全存储 Token。
    *   **SwiftLint/SwiftFormat**: 代码规范工具。

### 3. 目录结构映射 Cc
项目采用 **Swift Package Manager (SPM)** 进行模块化管理，主工程 `IceCubesApp` 极度轻量化，核心逻辑都在 `Packages` 目录下。

*   **IceCubesApp/**: App 入口，负责组装各个模块，注入全局环境 (`Env`)。
*   **Packages/**:
    *   **Env**: 🌍 环境与全局状态 (账号、设置、路由)。核心中枢。
    *   **NetworkClient**: 📡 网络请求层，处理 OAuth、API 调用。
    *   **Models**: 📦 基础数据模型 (Status, Account, Instance)。
    *   **DesignSystem**: 🎨 UI 组件库 (颜色、字体、通用视图)，确保设计一致性。
    *   **StatusKit**: 📝 微博(Status) 相关的核心 UI 和逻辑 (展示、点赞、投票)。
    *   **Timeline**: ⏱️ 时间线功能，处理列表数据流。
    *   **Account / AppAccount**: 👤 用户账号管理与切换。
    *   **Notifications**: 🔔 通知中心。

### 4. 代码质量评估 💎
*   **模块化设计**: ⭐⭐⭐⭐⭐ 极佳。通过 SPM 强制解耦，依赖关系清晰，编译速度快，易于测试和复用。
*   **现代性**: ⭐⭐⭐⭐⭐ 极佳。全面拥抱 Swift 6 和 SwiftUI 最新特性 (Observation, Actors)，是学习现代 iOS 开发的教科书级范例。
*   **可读性**: ⭐⭐⭐⭐ 优秀。命名规范，逻辑清晰。
*   **复杂度**: 中等偏高。虽然模块清晰，但大量使用了并发编程和高级 Swift 特性，对初学者有一定门槛。

---
*注：此报告基于对源码的静态分析生成。*

### 第二部分：项目复现与重构指南 🚀

想通过复现此项目学习 SwiftUI，建议按照以下 **6 个阶段** 循序渐进：

#### 阶段一：地基搭建 (Foundation & Modularization)
**目标**: 搭建 SPM 模块化架构，跑通 "Hello World"。
1.  **创建 Workspace**: 新建 Xcode Workspace。
2.  **创建主工程**: `IceCubesApp` (App 壳工程)。
3.  **创建 Packages 目录**: 在根目录创建 `Packages` 文件夹。
4.  **创建核心模块**: 使用 SPM 创建以下本地包：
    *   `Env`: 存放环境对象。
    *   `Models`: 存放数据模型。
    *   `DesignSystem`: 存放 UI 组件。
5.  **依赖链接**: 在 `IceCubesApp` 中链接这些本地包。

#### 阶段二：网络层与数据模型 (Networking & Models)
**目标**: 能从 Mastodon API 获取数据。
1.  **定义 Models**: 在 `Models` 包中定义 `Status`, `Account` 等核心结构体 (Codable)。
2.  **构建 NetworkClient**:
    *   封装 `URLSession`。
    *   实现 `Endpoint` 枚举 (Router 模式)。
    *   实现 `async/await` 请求方法。
    *   *学习点*: 泛型、`Codable`、`async/await` 封装。

#### 阶段三：环境与状态管理 (Environment & State)
**目标**: 实现全局状态注入。
1.  **实现 Env**:
    *   创建 `CurrentAccount` (单例 + `@Observable`)。
    *   创建 `UserPreferences`。
2.  **注入环境**: 在 `IceCubesApp` 入口使用 `.environment(CurrentAccount.shared)` 注入。
3.  *学习点*: Swift 5.9 Observation 框架、依赖注入。

#### 阶段四：设计系统与基础 UI (Design System)
**目标**: 统一 App 视觉风格。
1.  **配置 DesignSystem**: 定义 `Color`, `Font`, `Theme`。
2.  **封装组件**: `AvatarView`, `StatusRowView` (静态版)。
3.  *学习点*: ViewModifier, ViewBuilder, 跨模块 UI 复用。

#### 阶段五：核心功能 - 时间线 (Timeline Feature)
**目标**: 展示微博列表。
1.  **创建 Timeline 包**:
    *   `TimelineViewModel`: 负责获取数据。
    *   `TimelineView`: 使用 `List` 或 `LazyVStack` 展示。
2.  **并发优化**: 尝试使用 `actor` 管理数据源 (`TimelineDatasource`)，体验线程安全的数据处理。
3.  *学习点*: `@MainActor`, `Task`, `List` 性能优化。

#### 阶段六：交互与完善 (Interaction & Polish)
**目标**: 点赞、转发、详情页。
1.  **StatusKit**: 实现点赞、转发逻辑 (调用 NetworkClient)。
2.  **导航**: 实现 `RouterPath` 进行页面跳转。
3.  **细节**: 添加下拉刷新、加载更多、骨架屏。

---
### 💡 专家建议
*   **不要一开始就照搬所有代码**。IceCubesApp 代码量巨大且使用了许多高级特性。
*   **先做减法**。只关注 `Timeline` -> `StatusRow` -> `Network` 这条主线。
*   **拥抱变化**。项目使用了 Swift 6 和 Observation，这是未来的趋势，非常值得深入学习。
