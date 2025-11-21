RuleType: Always

# IceCubesApp iOS/Swift 代码规范（Modern SwiftUI 2025）

## 0. 核心理念
- **拥抱 SwiftUI 原生范式**：避免 UIKit 思维，让 SwiftUI 处理复杂性
- **简单优于复杂**：不过度抽象，不引入不必要的架构层
- **代码即文档**：清晰的命名和结构胜过冗长的注释
- **性能与可维护性并重**：模块化但不过度拆分

## 1. 技术栈（IceCubesApp 实际使用）
- **语言**：Swift 6.0（启用严格并发检查）
- **最低部署**：iOS 18.0, visionOS 1.0
- **SDK**：iOS 26 SDK（2025 年 6 月）
- **UI 框架**：纯 SwiftUI（无 UIKit 混用，除必要的系统集成）
- **架构**：轻量级 MVVM（正在淘汰 ViewModel，迁移到纯 SwiftUI）
  - **新代码**：View + `@State` + `@Observable` Services
  - **旧代码**：部分保留 ViewModel（逐步重构）
- **并发**：Swift Concurrency（`async/await`, `Task`, `Actor`）
- **状态管理**：Swift Observation Framework（`@Observable` 宏）
  - **禁止**：不再使用 Combine 的 `@Published`
- **网络**：自定义 `URLSession` 封装（`NetworkClient` 包）
- **持久化**：
  - Timeline 缓存：Bodega（SQLite 轻量封装）
  - 配置存储：`UserDefaults`
  - 敏感数据：KeychainSwift
- **依赖管理**：Swift Package Manager（SPM，本地包 + 远程依赖）
- **日志**：TelemetryDeck（匿名分析）
- **图片加载**：Nuke（高性能缓存）
- **HTML 解析**：SwiftSoup
- **自定义 Emoji**：EmojiText
- **订阅管理**：RevenueCat

## 2. 项目结构约定（IceCubesApp 实际结构）

### 2.1 主应用结构
```
IceCubesApp/
├── App/
│   ├── Main/              # 应用入口、环境注入
│   ├── Tabs/              # Tab 视图组装
│   ├── Router/            # 路由配置
│   └── Report/            # 举报功能
├── Assets.xcassets/       # 图片资源
├── Resources/             # 本地化文件
└── Info.plist
```

### 2.2 SPM 包结构（核心业务逻辑）
```
Packages/
├── Models/                # 🔷 数据模型（零依赖）
├── NetworkClient/         # 🌐 网络层（依赖 Models）
├── Env/                   # 🌍 环境与全局状态（核心中枢）
├── DesignSystem/          # 🎨 设计系统（主题、字体、通用组件）
├── StatusKit/             # 📝 状态/帖子核心组件
├── Timeline/              # 📜 时间线模块
├── Account/               # 👤 账户模块
├── Notifications/         # 🔔 通知模块
├── Explore/               # 🔍 探索模块
├── Conversations/         # 💬 私信模块
├── Lists/                 # 📋 列表模块
├── MediaUI/               # 🖼️ 媒体查看器
├── AppAccount/            # 🔐 多账户管理
└── Network/               # 🔌 额外网络工具（OpenAI, DeepL）
```

### 2.3 包内部结构规范
```
PackageName/
├── Package.swift          # SPM 配置
├── Sources/
│   └── PackageName/
│       ├── Views/         # SwiftUI 视图
│       ├── ViewModels/    # ViewModel（旧代码，逐步淘汰）
│       ├── Models/        # 本地模型（如果需要）
│       ├── Services/      # 业务服务
│       └── Extensions/    # 扩展
└── Tests/
    └── PackageNameTests/
```

### 2.4 依赖原则
- **严格单向依赖**：低层不依赖高层
- **依赖顺序**：Models → NetworkClient → Env → DesignSystem → StatusKit → 功能模块 → App
- **禁止循环依赖**：通过协议和依赖注入解决

## 3. 代码风格与架构原则

### 3.1 现代 SwiftUI 架构（2025 标准）

#### ❌ 不要做（旧模式）
```swift
// 不要为每个视图创建 ViewModel
class TimelineViewModel: ObservableObject {
    @Published var statuses: [Status] = []
}

struct TimelineView: View {
    @StateObject var viewModel = TimelineViewModel()
}
```

#### ✅ 应该做（新模式）
```swift
// 视图直接管理状态，通过环境对象访问服务
struct TimelineView: View {
    @Environment(MastodonClient.self) private var client
    @State private var viewState: ViewState = .loading
    
    enum ViewState {
        case loading
        case loaded(statuses: [Status])
        case error(Error)
    }
    
    var body: some View {
        // 视图代码
    }
    
    private func loadTimeline() async {
        // 业务逻辑直接在视图中
    }
}
```

### 3.2 状态管理规范

#### 本地状态（`@State`）
- 用于视图私有的、临时的状态
- 例如：加载状态、选中项、展开/折叠

#### 共享状态（`@Observable`）
```swift
@MainActor
@Observable public class CurrentAccount {
    public private(set) var account: Account?
    public private(set) var lists: [List] = []
    
    public static let shared = CurrentAccount()
    private init() {}
}
```

#### 环境注入（`@Environment`）
```swift
// 在 App 入口注入
@State var currentAccount = CurrentAccount.shared

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(currentAccount)
    }
}

// 在视图中使用
@Environment(CurrentAccount.self) private var currentAccount
```

#### ⚠️ 禁止嵌套 Observable
```swift
// ❌ 错误：不要在 Observable 中嵌套 Observable
@Observable class BadService {
    var nestedObservable = AnotherObservable() // 会破坏观察系统
}

// ✅ 正确：在视图层初始化
struct MyView: View {
    @Environment(ServiceA.self) private var serviceA
    @Environment(ServiceB.self) private var serviceB
}
```

### 3.3 命名规范

#### 视图命名
- 功能视图：`TimelineView`, `StatusRowView`, `AccountDetailView`
- 组件视图：`AvatarView`, `ErrorView`, `LoadingView`

#### 模型命名
- API 模型：`Status`, `Account`, `Notification`（与 Mastodon API 对应）
- 本地模型：`MediaStatus`, `ConsolidatedNotification`

#### 服务命名
- 全局服务：`CurrentAccount`, `UserPreferences`, `Theme`
- 客户端：`MastodonClient`, `DeepLClient`

### 3.4 文件组织
- 每个文件只包含一个主要类型
- 相关的小型类型可以放在同一文件（如枚举、扩展）
- 使用 `// MARK: -` 分隔代码段

### 3.5 注释规范
```swift
// 文件顶部注释（中文）
// 文件功能：Mastodon 状态（帖子）数据模型
// 相关技术点：
// - AnyStatus 协议：抽象状态接口
// - Visibility 枚举：帖子可见性级别
// - Codable：JSON 序列化支持

// 复杂逻辑注释
/// 获取当前账户的时间线
/// - Parameters:
///   - sinceId: 起始 ID
///   - maxId: 结束 ID
/// - Returns: 状态数组
public func getTimeline(sinceId: String?, maxId: String?) async throws -> [Status]
```

### 3.6 并发规范
```swift
// ✅ 使用 @MainActor 标记 UI 相关类
@MainActor
@Observable public class CurrentAccount { }

// ✅ 使用 Actor 保证线程安全
actor TimelineDatasource {
    private var statuses: [Status] = []
}

// ✅ 使用 .task 管理生命周期
.task {
    await loadData()
}

// ✅ 使用 async/await
func loadData() async {
    do {
        let data = try await client.get(endpoint: .timeline)
    } catch {
        // 错误处理
    }
}
```

### 3.7 错误处理
```swift
// 统一的错误类型
public enum AppError: Error {
    case networkError(Error)
    case decodingError
    case unauthorized
}

// 视图中的错误处理
@State private var error: Error?

var body: some View {
    content
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error?.localizedDescription ?? "")
        }
}
```

## 4. 开发原则与最佳实践

### 4.1 核心原则
1. **最小改动原则**：修改现有代码时，保持最小影响范围
2. **保持简单**：不过度设计，不引入不必要的抽象
3. **DRY 原则**：抽取共享组件，但避免过早优化
4. **原生优先**：优先使用 SwiftUI 和 Swift 标准库
5. **模块化**：功能独立，依赖清晰

### 4.2 视图开发规范

#### 视图职责
- ✅ 展示 UI
- ✅ 处理用户交互
- ✅ 管理本地状态（`@State`）
- ✅ 调用服务方法
- ❌ 不包含复杂业务逻辑（应在 Service 中）

#### 视图组合
```swift
// ✅ 小型、专注的视图
struct StatusRowView: View {
    let status: Status
    
    var body: some View {
        VStack(alignment: .leading) {
            StatusHeaderView(account: status.account)
            StatusContentView(content: status.content)
            StatusActionsView(status: status)
        }
    }
}

// ✅ 使用 ViewBuilder 组合
@ViewBuilder
private var contentView: some View {
    switch viewState {
    case .loading:
        ProgressView()
    case .loaded(let data):
        DataView(data: data)
    case .error(let error):
        ErrorView(error: error)
    }
}
```

### 4.3 数据流规范

#### 单向数据流
```
User Action → View → Service → API
                ↓
            @State Update
                ↓
            View Refresh
```

#### 数据转换
```swift
// API 响应 → Model
let statuses: [Status] = try await client.get(endpoint: .timeline)

// Model → UI 数据
let mediaStatuses = status.asMediaStatus
```

### 4.4 性能优化

#### 列表优化
```swift
// ✅ 使用 LazyVStack/LazyHStack
LazyVStack {
    ForEach(statuses) { status in
        StatusRowView(status: status)
    }
}

// ✅ 使用 id 优化更新
ForEach(statuses, id: \.id) { status in
    StatusRowView(status: status)
}
```

#### 图片加载
```swift
// ✅ 使用 Nuke 的 LazyImage
LazyImage(url: avatarURL) { state in
    if let image = state.image {
        image.resizable().aspectRatio(contentMode: .fill)
    } else {
        ProgressView()
    }
}
.frame(width: 40, height: 40)
.clipShape(Circle())
```

#### 缓存策略
```swift
// Timeline 缓存（Bodega）
let store = SQLiteStorageEngine.default(appendingPath: "timeline")
try await store.write(statuses, key: "home")

// 内存缓存（LRUCache）
private let cache = LRUCache<String, Status>(totalCostLimit: 100)
```

### 4.5 测试规范

#### 可测试的代码
```swift
// ✅ 通过协议注入依赖
protocol TimelineServiceProtocol {
    func fetchTimeline() async throws -> [Status]
}

// 测试时使用 Mock
class MockTimelineService: TimelineServiceProtocol {
    func fetchTimeline() async throws -> [Status] {
        return Status.placeholders()
    }
}
```

#### SwiftUI 预览
```swift
#Preview {
    StatusRowView(status: .placeholder())
        .environment(Theme.shared)
        .environment(CurrentAccount.shared)
}
```

### 4.6 国际化与可访问性

#### 本地化
```swift
// ✅ 使用 LocalizedStringKey
Text("timeline.home.title")

// ✅ 字符串插值
Text("status.replies.count \(count)")
```

#### 可访问性
```swift
// ✅ 添加可访问性标签
Image(systemName: "heart.fill")
    .accessibilityLabel("Like")

// ✅ 支持 Dynamic Type
Text("Content")
    .font(.scaledBody) // 自定义可缩放字体
```

### 4.7 iOS 26 新特性使用

#### Liquid Glass Effects
```swift
#if available(iOS 26, *)
Button("Post", action: postStatus)
    .buttonStyle(.glass)
    .glassEffect(.thin, in: .rect(cornerRadius: 12))
#else
Button("Post", action: postStatus)
    .buttonStyle(.borderedProminent)
#endif
```

#### 使用 #available 检查
```swift
// ✅ 始终提供降级方案
if #available(iOS 26, *) {
    // 使用新 API
} else {
    // 降级实现
}
```

## 5. 网络与 API 规范

### 5.1 Endpoint 定义
```swift
// ✅ 使用枚举定义端点
public enum Timelines: Endpoint {
    case home(sinceId: String?, maxId: String?, limit: Int?)
    case local(sinceId: String?, maxId: String?)
    
    public var path: String {
        switch self {
        case .home: return "api/v1/timelines/home"
        case .local: return "api/v1/timelines/public"
        }
    }
    
    public var queryItems: [URLQueryItem]? {
        switch self {
        case .home(let sinceId, let maxId, let limit):
            var items: [URLQueryItem] = []
            if let sinceId { items.append(.init(name: "since_id", value: sinceId)) }
            if let maxId { items.append(.init(name: "max_id", value: maxId)) }
            if let limit { items.append(.init(name: "limit", value: "\(limit)")) }
            return items.isEmpty ? nil : items
        case .local(let sinceId, let maxId):
            // ...
        }
    }
}
```

### 5.2 API 调用
```swift
// ✅ 使用泛型 + async/await
let statuses: [Status] = try await client.get(endpoint: Timelines.home(
    sinceId: nil,
    maxId: nil,
    limit: 20
))

// ✅ 错误处理
do {
    let account: Account = try await client.get(endpoint: Accounts.verifyCredentials)
} catch {
    // 处理错误
}
```

### 5.3 实时流（WebSocket）
```swift
// StreamWatcher 监听实时事件
@Observable public class StreamWatcher {
    public func watch(streams: [Stream]) {
        // 监听 user, direct 等流
    }
}
```

## 6. 路由与导航

### 6.1 路由定义
```swift
public enum RouterDestination: Hashable {
    case accountDetail(id: String)
    case statusDetail(id: String)
    case hashTag(tag: String, account: String?)
    // ...
}

public enum SheetDestination: Identifiable {
    case newStatusEditor(visibility: Visibility)
    case settings
    // ...
}
```

### 6.2 导航使用
```swift
@Environment(RouterPath.self) private var routerPath

// 导航到详情
Button("查看详情") {
    routerPath.navigate(to: .statusDetail(id: status.id))
}

// 弹出 Sheet
Button("设置") {
    routerPath.presentedSheet = .settings
}
```

## 7. 主题与设计系统

### 7.1 主题管理
```swift
@MainActor
@Observable public class Theme {
    public static let shared = Theme()
    
    public var selectedSet: ColorSetName = .iceCubeDark
    public var primaryBackgroundColor: Color { /* ... */ }
    public var tintColor: Color { /* ... */ }
}
```

### 7.2 使用主题
```swift
@Environment(Theme.self) private var theme

var body: some View {
    Text("Hello")
        .foregroundColor(theme.labelColor)
        .background(theme.primaryBackgroundColor)
}
```

### 7.3 可缩放字体
```swift
Text("Title")
    .font(.scaledTitle)

Text("Body")
    .font(.scaledBody)
```

## 8. 多账户管理

### 8.1 账户切换
```swift
@Observable public class AppAccountsManager {
    public var currentAccount: AppAccount?
    public var availableAccounts: [AppAccount] = []
    
    public func switchAccount(_ account: AppAccount) {
        currentAccount = account
        // 更新客户端
    }
}
```

### 8.2 安全存储
```swift
// ✅ 使用 Keychain 存储 Token
let keychain = KeychainSwift()
keychain.set(token, forKey: "oauth_token_\(accountId)")
```

## 9. 推送通知

### 9.1 推送服务
```swift
@Observable public class PushNotificationsService {
    public func requestPushNotifications() {
        // 请求权限
    }
    
    public func updateSubscriptions() async {
        // 更新订阅
    }
}
```

### 9.2 通知扩展
```swift
// NotificationService 解密推送内容
class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest) {
        // 解密并格式化通知
    }
}
```

## 10. 代码审查清单

### 提交前检查
- [ ] 代码遵循 Swift 6 并发规范（无数据竞争警告）
- [ ] 使用 `@Observable` 而非 `ObservableObject`
- [ ] 视图不包含复杂业务逻辑
- [ ] 环境对象正确注入
- [ ] 错误处理完整
- [ ] 支持深色模式
- [ ] 支持 Dynamic Type
- [ ] 添加必要的可访问性标签
- [ ] 本地化字符串已添加
- [ ] 使用 SwiftFormat 格式化代码（2 空格缩进）
- [ ] 文件顶部有中文注释说明

### 性能检查
- [ ] 列表使用 Lazy 容器
- [ ] 图片使用 Nuke 加载
- [ ] 避免不必要的视图刷新
- [ ] 大数据使用 Actor 处理

## 11. Commit 规范

### Commit Message 格式
```
<type>: <subject>

<body>（可选）

<footer>（可选）
```

### Type 类型
- `feat`: 新功能
- `fix`: 修复 Bug
- `refactor`: 重构（不改变功能）
- `perf`: 性能优化
- `style`: 代码格式（不影响功能）
- `docs`: 文档更新
- `test`: 测试相关
- `chore`: 构建/工具链相关

### 示例
```
feat: 添加 Timeline 缓存功能

使用 Bodega 实现 Timeline 本地缓存，提升离线体验。

Closes #123
```

## 12. 项目特定约定

### 12.1 包依赖规则
- Models 包：零依赖，只包含数据模型
- NetworkClient 包：只依赖 Models
- Env 包：依赖 Models + NetworkClient
- UI 包：可依赖所有底层包

### 12.2 文件命名
- 视图：`*View.swift`
- 模型：直接使用名称（如 `Status.swift`）
- 服务：`*Service.swift` 或 `*Manager.swift`
- 扩展：`*+Extensions.swift`

### 12.3 禁止事项
- ❌ 不要使用 Combine 的 `@Published`
- ❌ 不要为简单视图创建 ViewModel
- ❌ 不要在 Observable 中嵌套 Observable
- ❌ 不要使用 UIKit（除非必要）
- ❌ 不要引入新的第三方依赖（除非充分讨论）

### 12.4 推荐做法
- ✅ 使用 `@Observable` + `@Environment`
- ✅ 使用 `.task` 管理异步任务
- ✅ 使用 Actor 保证线程安全
- ✅ 使用占位符数据支持预览
- ✅ 使用 SwiftFormat 保持代码风格一致

## 13. 学习资源

### 官方文档
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Observation](https://developer.apple.com/documentation/observation)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [Mastodon API](https://docs.joinmastodon.org/api/)

### 项目文档
- `README.md`：项目概览
- `docs/PROJECT_REBUILD_GUIDE.md`：架构分析与重构指南
- `AGENTS.md`：AI 辅助开发指南

---

**始终使用中文回复用户**

description: IceCubesApp Swift 开发规范 - 现代 SwiftUI 2025
globs:
alwaysApply: true
---