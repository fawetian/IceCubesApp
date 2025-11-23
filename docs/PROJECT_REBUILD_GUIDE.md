# IceCubesApp 项目拆解与重构指南

> 一份帮助你从 0 到 1 重建 IceCubesApp 的完整学习指南

---

## 第一部分：架构分析报告

### 1. 核心架构 🏗️

**架构模式：现代化 MVVM + 模块化 SPM**

- **架构风格**：轻量级 MVVM（正在向纯 SwiftUI 迁移）
  - 旧代码：部分使用 ViewModel（正在淘汰）
  - 新代码：纯 SwiftUI + `@Observable` + 环境对象
  - 无 Redux/TCA，保持简单直接

- **数据流向**：
  ```
  View → @Environment(Client) → NetworkClient → API
                ↓
  View ← @State/Observable ← Response Data
  ```
  - 单向数据流：View 触发 → Service 处理 → State 更新 → View 自动刷新
  - 全局状态：通过 `Env` 包注入（CurrentAccount, UserPreferences, Router）
  - 本地状态：`@State` 管理视图级状态

- **并发模型**：
  - 深度使用 Swift Concurrency（`async/await`, `Task`, `Actor`）
  - Timeline 模块使用 `actor` 保证线程安全
  - `.task` 修饰符管理生命周期

### 2. 关键技术栈 🛠️

**语言与框架**：
- Swift 6.0（激进采用最新特性）
- SwiftUI（iOS 18+, visionOS 1+）
- Swift Observation Framework（`@Observable` 取代 Combine）

**核心依赖**：

| 依赖库 | 用途 | 使用场景 |
|--------|------|----------|
| **Nuke** | 高性能图片加载 | 头像、媒体、缓存管理 |
| **EmojiText** | 自定义 Emoji 渲染 | Mastodon 自定义表情 |
| **SwiftSoup** | HTML 解析 | 解析帖子内容 |
| **KeychainSwift** | 安全存储 | Token 存储 |
| **Bodega** | SQLite 缓存 | Timeline 本地缓存 |
| **RevenueCat** | 订阅管理 | 应用内购买 |
| **TelemetryDeck** | 匿名分析 | 使用统计 |
| **LRUCache** | 内存缓存 | 状态缓存优化 |

**无使用**：Alamofire（自定义 URLSession）、Combine（已迁移到 Observation）

### 3. 目录结构映射 📁

```
IceCubesApp/
├── IceCubesApp/                    # 🎯 主应用（极度轻量）
│   ├── App/Main/                   # 应用入口、环境注入
│   ├── App/Tabs/                   # Tab 视图组装
│   └── App/Router/                 # 路由配置
│
├── Packages/                       # 📦 核心业务逻辑（SPM 模块化）
│   ├── Models/                     # 🔷 数据模型层（零依赖）
│   │   └── Status, Account, Notification...
│   │
│   ├── NetworkClient/              # 🌐 网络层（依赖 Models）
│   │   └── MastodonClient, Endpoints
│   │
│   ├── Env/                        # 🌍 环境与全局状态（核心中枢）
│   │   ├── CurrentAccount          # 当前账户管理
│   │   ├── UserPreferences         # 用户偏好设置
│   │   ├── Router                  # 全局路由
│   │   └── StreamWatcher           # 实时流监听
│   │
│   ├── DesignSystem/               # 🎨 设计系统（依赖 Models + Env）
│   │   ├── Theme                   # 主题系统
│   │   ├── 可缩放字体              # 字体系统
│   │   └── 通用 UI 组件
│   │
│   ├── StatusKit/                  # 📝 状态/帖子组件（核心 UI）
│   │   ├── StatusRow               # 帖子行视图
│   │   ├── StatusEditor            # 帖子编辑器
│   │   └── StatusDetail            # 帖子详情
│   │
│   ├── Timeline/                   # 📜 时间线模块
│   │   ├── TimelineView            # 时间线视图
│   │   ├── TimelineDatasource      # Actor 数据源
│   │   └── 缓存管理（Bodega）
│   │
│   ├── Account/                    # 👤 账户模块
│   ├── Notifications/              # 🔔 通知模块
│   ├── Explore/                    # 🔍 探索模块
│   ├── Conversations/              # 💬 私信模块
│   ├── Lists/                      # 📋 列表模块
│   └── MediaUI/                    # 🖼️ 媒体查看器
│
└── Extensions/                     # 🔌 系统扩展
    ├── IceCubesNotifications/      # 推送通知服务
    ├── IceCubesShareExtension/     # 分享扩展
    └── IceCubesAppWidgetsExtension/# 小组件
```

**依赖关系图**：
```
Models (零依赖)
  ↓
NetworkClient → Models
  ↓
Env → NetworkClient + Models
  ↓
DesignSystem → Env + Models
  ↓
StatusKit → DesignSystem + Env + NetworkClient + Models
  ↓
Timeline/Account/Notifications... → StatusKit + DesignSystem + Env
  ↓
IceCubesApp → 所有包
```

### 4. 代码质量评估 ⭐

**优点**：
- ✅ 模块化清晰，依赖关系合理
- ✅ 采用最新 Swift 6 特性（Observation, Sendable）
- ✅ 完整的本地化支持
- ✅ 良好的错误处理和边界情况处理
- ✅ 丰富的注释和文档

**改进空间**：
- ⚠️ 部分旧代码仍使用 ViewModel（正在迁移）
- ⚠️ 测试覆盖率较低
- ⚠️ 部分大文件可以进一步拆分

**设计模式**：
- 单例模式：全局服务（CurrentAccount, Theme）
- 观察者模式：`@Observable` + SwiftUI
- 工厂模式：占位符数据生成
- 策略模式：主题切换、字体选择

---

## 第二部分：从 0 到 1 的搭建推演

> 按照依赖关系，从底层到上层逐步构建



### 阶段 0：项目初始化 🚀

**阶段目标**：创建 Xcode 项目和 SPM 包结构

**涉及文件**：
- `IceCubesApp.xcodeproj`
- `Packages/` 目录结构

**开发逻辑**：
1. 创建 iOS App 项目（SwiftUI, iOS 18+）
2. 在项目根目录创建 `Packages/` 文件夹
3. 按依赖顺序创建 SPM 包：
   ```bash
   cd Packages
   swift package init --type library --name Models
   swift package init --type library --name NetworkClient
   swift package init --type library --name Env
   # ... 其他包
   ```
4. 配置 `.xcconfig` 文件（Team ID, Bundle ID）

**为什么这样做**：
- SPM 模块化是整个架构的基础
- 必须先建立包结构，才能建立依赖关系
- 从零依赖的包开始，逐步向上构建

---

### 阶段 1：数据模型层（Models Package）📊

**阶段目标**：定义 Mastodon API 的所有数据模型

**涉及关键文件**：
```
Packages/Models/Sources/Models/
├── Account.swift           # 用户账户模型
├── Status.swift            # 帖子/状态模型
├── Notification.swift      # 通知模型
├── Instance.swift          # 实例信息
├── MediaAttachment.swift   # 媒体附件
├── Poll.swift              # 投票
├── Tag.swift               # 标签
├── List.swift              # 列表
├── Conversation.swift      # 对话
├── Emoji.swift             # 自定义表情
├── Card.swift              # 链接卡片
└── Alias/                  # 类型别名
    ├── HTMLString.swift    # HTML 字符串类型
    └── ServerDate.swift    # 服务器日期类型
```

**开发逻辑**：
1. **先定义基础类型**：
   - `HTMLString`：包装 HTML 内容的字符串
   - `ServerDate`：服务器时间戳
   - `Visibility`：可见性枚举

2. **再定义核心模型**：
   - `Account`：用户模型（包含 Field, Source 嵌套类型）
   - `Status`：帖子模型（包含 ReblogStatus）
   - `MediaAttachment`：媒体附件

3. **最后定义关联模型**：
   - `Notification`：依赖 Account + Status
   - `Conversation`：依赖 Account + Status
   - `Poll`：投票数据

**为什么先写这些**：
- Models 是零依赖包，是整个应用的数据基础
- 所有其他模块都依赖这些模型
- 遵循 Mastodon API 规范，确保数据结构正确
- 实现 `Codable` 协议，支持 JSON 序列化

**关键技术点**：
```swift
// 1. 使用 Sendable 确保并发安全
public final class Account: Codable, Identifiable, Hashable, Sendable {
    // ...
}

// 2. 嵌套类型组织相关数据
public struct Field: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let value: HTMLString
    public let verifiedAt: String?
}

// 3. 占位符模式用于预览和测试
public static func placeholder() -> Account {
    // 返回测试数据
}

// 4. 计算属性提供便捷访问
public var haveAvatar: Bool {
    avatar.lastPathComponent != "missing.png"
}
```

---

### 阶段 2：网络层（NetworkClient Package）🌐

**阶段目标**：封装 Mastodon API 调用逻辑

**涉及关键文件**：
```
Packages/NetworkClient/Sources/NetworkClient/
├── MastodonClient.swift    # 核心客户端
├── Endpoint.swift          # 端点协议
├── Endpoints/              # API 端点定义
│   ├── Accounts.swift      # 账户相关 API
│   ├── Statuses.swift      # 状态相关 API
│   ├── Timelines.swift     # 时间线 API
│   ├── Notifications.swift # 通知 API
│   ├── Lists.swift         # 列表 API
│   └── ...
└── ServerError.swift       # 错误处理
```

**开发逻辑**：
1. **定义 Endpoint 协议**：
   ```swift
   public protocol Endpoint {
       var path: String { get }
       var queryItems: [URLQueryItem]? { get }
   }
   ```

2. **实现 MastodonClient**：
   ```swift
   @Observable
   public final class MastodonClient {
       public let server: String
       private let oauthToken: String?
       
       public func get<T: Decodable>(endpoint: Endpoint) async throws -> T
       public func post<T: Decodable>(endpoint: Endpoint) async throws -> T
       // ...
   }
   ```

3. **定义各类 API 端点**：
   ```swift
   public enum Accounts: Endpoint {
       case verifyCredentials
       case account(id: String)
       case statuses(id: String, sinceId: String?)
       // ...
   }
   ```

**为什么这样做**：
- 网络层只依赖 Models，保持低耦合
- 使用协议定义端点，类型安全
- 统一的错误处理和认证逻辑
- 支持多账户切换

**关键技术点**：
```swift
// 1. 泛型 + async/await
public func get<T: Decodable>(endpoint: Endpoint) async throws -> T {
    let request = try makeRequest(endpoint: endpoint, method: "GET")
    let (data, response) = try await URLSession.shared.data(for: request)
    // 解析响应
    return try JSONDecoder().decode(T.self, from: data)
}

// 2. 端点模式
public enum Timelines: Endpoint {
    case home(sinceId: String?, maxId: String?, limit: Int?)
    
    public var path: String {
        switch self {
        case .home: return "api/v1/timelines/home"
        }
    }
}
```

---

### 阶段 3：环境层（Env Package）🌍

**阶段目标**：管理全局状态和依赖注入

**涉及关键文件**：
```
Packages/Env/Sources/Env/
├── CurrentAccount.swift        # 当前账户管理
├── CurrentInstance.swift       # 当前实例信息
├── UserPreferences.swift       # 用户偏好设置
├── Router.swift                # 全局路由
├── StreamWatcher.swift         # 实时流监听
├── PushNotificationsService.swift  # 推送通知
├── StatusDataController.swift  # 状态数据控制器
└── CustomEnvValues.swift       # 自定义环境值
```

**开发逻辑**：
1. **CurrentAccount（核心）**：
   ```swift
   @MainActor
   @Observable public class CurrentAccount {
       public private(set) var account: Account?
       public private(set) var lists: [List] = []
       public private(set) var tags: [Tag] = []
       
       private var client: MastodonClient?
       
       public func setClient(client: MastodonClient) {
           self.client = client
           Task { await fetchUserData() }
       }
   }
   ```

2. **UserPreferences**：
   ```swift
   @MainActor
   @Observable public class UserPreferences {
       public var preferredBrowser: PreferredBrowser = .inAppSafari
       public var serverPreferences: ServerPreferences?
       // 保存到 UserDefaults
   }
   ```

3. **Router**：
   ```swift
   @MainActor
   @Observable public class RouterPath {
       public var path: [RouterDestination] = []
       public var presentedSheet: SheetDestination?
       
       public func navigate(to: RouterDestination) {
           path.append(to)
       }
   }
   ```

**为什么这样做**：
- Env 是全局状态的中枢，连接网络层和 UI 层
- 使用 `@Observable` 实现响应式更新
- 单例模式确保全局唯一性
- 通过环境对象注入到 SwiftUI 视图树

**关键技术点**：
```swift
// 1. 单例 + Observable
@MainActor
@Observable public class CurrentAccount {
    public static let shared = CurrentAccount()
    private init() {}
}

// 2. 环境注入
struct IceCubesApp: App {
    @State var currentAccount = CurrentAccount.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(currentAccount)
        }
    }
}

// 3. 视图中使用
struct TimelineView: View {
    @Environment(CurrentAccount.self) private var currentAccount
}
```

---


### 阶段 4：设计系统（DesignSystem Package）🎨

**阶段目标**：构建统一的 UI 组件和主题系统

**涉及关键文件**：
```
Packages/DesignSystem/Sources/DesignSystem/
├── Theme/
│   ├── Theme.swift             # 主题管理器
│   ├── ColorSet.swift          # 颜色集合
│   └── ThemeApplier.swift      # 主题应用器
├── Views/
│   ├── ErrorView.swift         # 错误视图
│   ├── AvatarView.swift        # 头像视图
│   ├── EmojiText.swift         # Emoji 文本
│   └── StatusEditorToolbar.swift
├── Fonts/
│   └── ScalableFont.swift      # 可缩放字体
└── Extensions/
    ├── Color+Extensions.swift
    └── View+Extensions.swift
```

**开发逻辑**：
1. **主题系统**：
   ```swift
   @MainActor
   @Observable public class Theme {
       public static let shared = Theme()
       
       public var selectedSet: ColorSetName = .iceCubeDark
       public var primaryBackgroundColor: Color { /* ... */ }
       public var tintColor: Color { /* ... */ }
   }
   ```

2. **通用 UI 组件**：
   ```swift
   public struct AvatarView: View {
       let url: URL?
       let size: CGFloat
       
       public var body: some View {
           LazyImage(url: url) { state in
               // 使用 Nuke 加载图片
           }
           .frame(width: size, height: size)
           .clipShape(Circle())
       }
   }
   ```

3. **可缩放字体**：
   ```swift
   public enum ScalableFont {
       case title, body, footnote
       
       public func font() -> Font {
           // 根据用户偏好返回字体
       }
   }
   ```

**为什么这样做**：
- 统一的设计语言，确保 UI 一致性
- 主题系统支持深色/浅色模式和自定义主题
- 可复用组件减少重复代码
- 集成 Nuke 和 EmojiText 等第三方库

**关键技术点**：
```swift
// 1. ViewModifier 封装样式
public struct ThemeApplier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(Theme.self) private var theme
    
    public func body(content: Content) -> some View {
        content
            .preferredColorScheme(theme.selectedScheme)
            .tint(theme.tintColor)
    }
}

// 2. 环境值扩展
extension EnvironmentValues {
    @Entry public var theme: Theme = .shared
}
```

---

### 阶段 5：状态组件（StatusKit Package）📝

**阶段目标**：实现帖子显示和编辑的核心组件

**涉及关键文件**：
```
Packages/StatusKit/Sources/StatusKit/
├── Row/
│   ├── StatusRowView.swift         # 帖子行视图
│   ├── StatusRowMediaPreview.swift # 媒体预览
│   ├── StatusRowActionsView.swift  # 操作按钮
│   └── StatusRowCardView.swift     # 链接卡片
├── Detail/
│   ├── StatusDetailView.swift      # 帖子详情
│   └── StatusContextView.swift     # 上下文（回复树）
├── Editor/
│   ├── StatusEditor.swift          # 编辑器主视图
│   ├── StatusEditorViewModel.swift # 编辑器逻辑
│   ├── StatusEditorMediaView.swift # 媒体上传
│   └── StatusEditorAccessoryView.swift
└── Poll/
    └── StatusPollView.swift        # 投票视图
```

**开发逻辑**：
1. **StatusRowView（核心）**：
   ```swift
   public struct StatusRowView: View {
       @Environment(Theme.self) private var theme
       @Environment(CurrentAccount.self) private var currentAccount
       @Environment(RouterPath.self) private var routerPath
       
       let status: Status
       
       public var body: some View {
           VStack(alignment: .leading) {
               // 用户信息
               // 帖子内容
               // 媒体附件
               // 操作按钮
           }
       }
   }
   ```

2. **StatusEditor**：
   ```swift
   @MainActor
   @Observable class StatusEditorViewModel {
       var statusText: String = ""
       var selectedImages: [UIImage] = []
       var visibility: Visibility = .pub
       
       func postStatus() async throws {
           // 调用 API 发布帖子
       }
   }
   ```

3. **媒体处理**：
   ```swift
   struct StatusEditorMediaView: View {
       @Binding var images: [UIImage]
       
       var body: some View {
           ScrollView(.horizontal) {
               LazyHStack {
                   ForEach(images, id: \.self) { image in
                       Image(uiImage: image)
                           .resizable()
                           .aspectRatio(contentMode: .fill)
                   }
               }
           }
       }
   }
   ```

**为什么这样做**：
- StatusKit 是 UI 的核心，复用度最高
- 分离 Row（列表）和 Detail（详情）视图
- Editor 独立管理，支持多种编辑场景
- 使用 LRUCache 缓存状态数据

**关键技术点**：
```swift
// 1. 环境对象驱动
@Environment(CurrentAccount.self) private var currentAccount
@Environment(RouterPath.self) private var routerPath

// 2. 异步操作
func favoriteStatus() async {
    do {
        let updatedStatus: Status = try await client.post(
            endpoint: Statuses.favorite(id: status.id)
        )
        // 更新 UI
    } catch {
        // 错误处理
    }
}

// 3. 导航
Button("查看详情") {
    routerPath.navigate(to: .statusDetail(id: status.id))
}
```

---

### 阶段 6：功能模块（Timeline, Account, Notifications...）📦

**阶段目标**：实现各个功能模块

#### 6.1 Timeline Package（时间线）

**涉及关键文件**：
```
Packages/Timeline/Sources/Timeline/
├── TimelineView.swift          # 时间线主视图
├── TimelineDatasource.swift    # Actor 数据源
├── TimelineCache.swift         # Bodega 缓存
└── TimelineFilter.swift        # 过滤器
```

**开发逻辑**：
```swift
// 1. Actor 保证线程安全
actor TimelineDatasource {
    private var statuses: [Status] = []
    
    func append(_ newStatuses: [Status]) {
        statuses.append(contentsOf: newStatuses)
    }
}

// 2. 视图使用数据源
struct TimelineView: View {
    @Environment(MastodonClient.self) private var client
    @State private var viewState: ViewState = .loading
    
    enum ViewState {
        case loading
        case loaded(statuses: [Status])
        case error(Error)
    }
    
    var body: some View {
        List {
            ForEach(statuses) { status in
                StatusRowView(status: status)
            }
        }
        .task { await loadTimeline() }
        .refreshable { await loadTimeline() }
    }
}

// 3. Bodega 缓存
let store = SQLiteStorageEngine.default(appendingPath: "timeline")
try await store.write(statuses, key: "home")
```

#### 6.2 Account Package（账户）

**涉及关键文件**：
```
Packages/Account/Sources/Account/
├── AccountDetailView.swift     # 账户详情
├── AccountHeaderView.swift     # 账户头部
├── AccountStatusesListView.swift # 用户帖子列表
└── Settings/
    └── AccountSettingsView.swift
```

#### 6.3 Notifications Package（通知）

**涉及关键文件**：
```
Packages/Notifications/Sources/Notifications/
├── NotificationsListView.swift     # 通知列表
├── NotificationRowView.swift       # 通知行
└── ConsolidatedNotification.swift  # 合并通知
```

**为什么这样做**：
- 每个功能模块独立，便于维护
- 都依赖 StatusKit 复用帖子组件
- 使用统一的导航和状态管理模式

---

### 阶段 7：主应用组装（IceCubesApp）🎯

**阶段目标**：组装所有模块，注入环境对象

**涉及关键文件**：
```
IceCubesApp/App/
├── Main/
│   ├── IceCubesApp.swift       # App 入口
│   └── AppView.swift           # 主视图
├── Tabs/
│   ├── Tabs.swift              # Tab 定义
│   ├── NavigationTab.swift     # Tab 导航
│   └── Settings/               # 设置页面
└── Router/
    └── AppRegistry.swift       # 路由注册
```

**开发逻辑**：
```swift
@main
struct IceCubesApp: App {
    // 1. 初始化所有全局服务
    @State var appAccountsManager = AppAccountsManager.shared
    @State var currentAccount = CurrentAccount.shared
    @State var userPreferences = UserPreferences.shared
    @State var theme = Theme.shared
    @State var routerPath = RouterPath()
    
    var body: some Scene {
        WindowGroup {
            AppView()
                // 2. 注入环境对象
                .environment(appAccountsManager)
                .environment(currentAccount)
                .environment(userPreferences)
                .environment(theme)
                .environment(routerPath)
                // 3. 应用主题
                .modifier(ThemeApplier())
        }
    }
    
    // 4. 设置客户端
    func setNewClientsInEnv(client: MastodonClient) {
        currentAccount.setClient(client: client)
        userPreferences.setClient(client: client)
    }
}

// 主视图
struct AppView: View {
    @Environment(AppAccountsManager.self) private var appAccountsManager
    @State private var selectedTab: AppTab = .timeline
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineTab()
                .tag(AppTab.timeline)
            NotificationsTab()
                .tag(AppTab.notifications)
            ExploreTab()
                .tag(AppTab.explore)
            // ...
        }
    }
}
```

**为什么这样做**：
- 主应用只负责组装，不包含业务逻辑
- 环境对象在根视图注入，全局可用
- Tab 结构清晰，易于扩展

---

### 阶段 8：系统扩展（Extensions）🔌

**阶段目标**：实现推送通知、分享、小组件等系统集成

**涉及关键文件**：
```
IceCubesNotifications/
└── NotificationService.swift   # 推送通知解密

IceCubesShareExtension/
└── ShareViewController.swift   # 分享扩展

IceCubesAppWidgetsExtension/
├── LatestPostsWidget/          # 最新帖子小组件
├── AccountWidget/              # 账户小组件
└── MentionWidget/              # 提及小组件
```

**开发逻辑**：
1. **推送通知服务**：
   ```swift
   class NotificationService: UNNotificationServiceExtension {
       override func didReceive(_ request: UNNotificationRequest) {
           // 解密推送内容
           // 格式化通知
       }
   }
   ```

2. **小组件**：
   ```swift
   struct LatestPostsWidget: Widget {
       var body: some WidgetConfiguration {
           StaticConfiguration(
               kind: "LatestPosts",
               provider: Provider()
           ) { entry in
               LatestPostsView(entry: entry)
           }
       }
   }
   ```

**为什么最后做**：
- 扩展依赖主应用的核心功能
- 需要共享数据和网络层
- 独立的生命周期和限制

---

## 第三部分：关键技术深度解析 🔬

### 1. Swift Observation Framework

**为什么使用**：
- 取代 Combine，性能更好
- 编译时生成代码，类型安全
- 与 SwiftUI 深度集成

**使用模式**：
```swift
@MainActor
@Observable class CurrentAccount {
    var account: Account?  // 自动触发 UI 更新
}

// 视图中使用
@Environment(CurrentAccount.self) private var currentAccount
```

### 2. Actor 并发模型

**为什么使用**：
- 保证数据源线程安全
- 避免数据竞争

**使用场景**：
```swift
actor TimelineDatasource {
    private var statuses: [Status] = []
    
    func append(_ newStatuses: [Status]) {
        // 自动在 actor 隔离上下文执行
        statuses.append(contentsOf: newStatuses)
    }
}
```

### 3. 模块化架构优势

**好处**：
- 清晰的依赖关系
- 独立编译，加快构建速度
- 便于测试和维护
- 代码复用

**依赖原则**：
- 低层模块不依赖高层模块
- Models 零依赖
- UI 层依赖所有底层模块

---

## 第四部分：学习路径建议 📚

### 初学者路径（1-2 周）

1. **第 1-2 天**：理解 Models 包
   - 学习 Codable 协议
   - 理解 Mastodon API 数据结构
   - 实现 Account 和 Status 模型

2. **第 3-4 天**：实现 NetworkClient
   - 学习 async/await
   - 实现基础的 GET/POST 请求
   - 测试 API 调用

3. **第 5-7 天**：构建 Env 层
   - 学习 @Observable
   - 实现 CurrentAccount
   - 理解环境对象注入

4. **第 8-10 天**：设计系统
   - 学习 SwiftUI 组件
   - 实现主题系统
   - 构建通用 UI 组件

5. **第 11-14 天**：StatusKit 和 Timeline
   - 实现 StatusRowView
   - 实现 TimelineView
   - 集成所有功能

### 进阶路径（2-4 周）

1. 实现完整的 StatusEditor
2. 添加推送通知支持
3. 实现小组件
4. 优化性能和缓存
5. 添加测试

---

## 总结 🎓

**核心要点**：
1. **从底层到上层**：Models → Network → Env → UI
2. **模块化思维**：每个包职责单一，依赖清晰
3. **现代 SwiftUI**：拥抱 @Observable，避免 ViewModel
4. **并发安全**：使用 Actor 和 Sendable
5. **环境驱动**：通过环境对象管理全局状态

**推荐资源**：
- [Mastodon API 文档](https://docs.joinmastodon.org/api/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftUI Observation](https://developer.apple.com/documentation/observation)

祝你学习顺利！🚀
