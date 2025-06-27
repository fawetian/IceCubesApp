// 文件功能说明：
// 该文件定义了标签页意图和标签页枚举，支持通过 Siri 快捷指令直接打开应用的特定标签页，包括主页、通知、探索、设置等各种功能页面，提供快速导航能力。
// 技术点：
// 1. AppEnum 协议 —— 定义可在快捷指令中选择的枚举类型。
// 2. Sendable 协议 —— 确保枚举在并发环境中安全使用。
// 3. nonisolated 关键字 —— 允许在并发上下文中安全访问静态属性。
// 4. DisplayRepresentation —— 定义枚举值的用户界面显示。
// 5. caseDisplayRepresentations —— 为每个枚举情况提供显示名称。
// 6. 类型转换方法 —— 将快捷指令枚举转换为应用内部类型。
// 7. @Parameter 属性包装器 —— 定义标签页选择参数。
// 8. @MainActor 属性 —— 确保在主线程上执行。
// 9. AppIntentService —— 应用内部的意图处理服务。
// 10. 全面的标签页覆盖 —— 支持应用中的所有主要功能页面。
//
// 技术点详解：
// - AppEnum：让枚举类型可以在快捷指令中作为选择参数，需要提供所有情况的显示名称
// - Sendable：确保枚举可以在并发环境中安全传递，符合 Swift 并发要求
// - nonisolated：标记静态属性可以在任何并发上下文中访问，无需隔离
// - DisplayRepresentation：控制每个枚举值在快捷指令界面中的显示文本
// - 显示名称映射：为所有标签页提供用户友好的显示名称
// - 类型转换：将快捷指令专用的枚举值转换为应用内部使用的标签页类型
// - 参数定义：使用 @Parameter 让用户在快捷指令中选择要打开的标签页
// - 主线程执行：确保 UI 相关操作在主线程上执行
// - 意图处理：通过共享服务将导航意图传递给应用主界面
// - 全功能支持：涵盖时间线、通知、探索、设置等所有主要功能

// 引入 App Intents 框架
import AppIntents
// 引入 Foundation 框架
import Foundation

// 标签页枚举，定义应用中的所有可导航标签页
enum TabEnum: String, AppEnum, Sendable {
  // 主要时间线标签页
  case timeline  // 主页时间线
  case notifications  // 通知
  case mentions  // 提及
  case explore  // 探索和趋势
  case messages  // 私信
  case settings  // 设置

  // 特殊时间线标签页
  case trending  // 趋势时间线
  case federated  // 联邦时间线
  case local  // 本地时间线

  // 用户相关标签页
  case profile  // 个人资料
  case bookmarks  // 书签
  case favorites  // 收藏
  case followedTags  // 关注的标签

  // 功能标签页
  case post  // 新建帖子
  case lists  // 列表
  case links  // 趋势链接

  // 枚举类型的显示名称
  static var typeDisplayName: LocalizedStringResource { "Tab" }

  // 枚举类型的表示方式
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tab"

  // 为每个枚举值定义在快捷指令中的显示名称（非隔离静态属性）
  nonisolated static var caseDisplayRepresentations: [TabEnum: DisplayRepresentation] {
    [
      // 主要功能标签页
      .timeline: .init(title: "Home Timeline"),  // 主页时间线
      .trending: .init(title: "Trending Timeline"),  // 趋势时间线
      .federated: .init(title: "Federated Timeline"),  // 联邦时间线
      .local: .init(title: "Local Timeline"),  // 本地时间线
      .notifications: .init(title: "Notifications"),  // 通知
      .mentions: .init(title: "Mentions"),  // 提及
      .explore: .init(title: "Explore & Trending"),  // 探索和趋势
      .messages: .init(title: "Private Messages"),  // 私信
      .settings: .init(title: "Settings"),  // 设置

      // 用户相关标签页
      .profile: .init(title: "Profile"),  // 个人资料
      .bookmarks: .init(title: "Bookmarks"),  // 书签
      .favorites: .init(title: "Favorites"),  // 收藏
      .followedTags: .init(title: "Followed Tags"),  // 关注的标签

      // 功能标签页
      .lists: .init(title: "Lists"),  // 列表
      .links: .init(title: "Trending Links"),  // 趋势链接
      .post: .init(title: "New post"),  // 新建帖子
    ]
  }

  // 转换为应用内部的标签页类型
  var toAppTab: AppTab {
    switch self {
    case .timeline:
      .timeline
    case .notifications:
      .notifications
    case .mentions:
      .mentions
    case .explore:
      .explore
    case .messages:
      .messages
    case .settings:
      .settings
    case .trending:
      .trending
    case .federated:
      .federated
    case .local:
      .local
    case .profile:
      .profile
    case .bookmarks:
      .bookmarks
    case .favorites:
      .favorites
    case .post:
      .post
    case .followedTags:
      .followedTags
    case .lists:
      .lists
    case .links:
      .links
    }
  }
}

// 标签页导航意图结构体，支持通过快捷指令打开特定标签页
struct TabIntent: AppIntent {
  // 快捷指令的标题
  static let title: LocalizedStringResource = "Open on a tab"
  // 快捷指令的描述
  static let description: IntentDescription = "Open the app on a specific tab"
  // 执行时打开应用
  static let openAppWhenRun: Bool = true

  // 选定的标签页参数
  @Parameter(title: "Selected tab")
  var tab: TabEnum

  // 执行标签页导航操作，在主线程上运行
  @MainActor
  func perform() async throws -> some IntentResult {
    // 将意图数据传递给应用内部的意图处理服务
    AppIntentService.shared.handledIntent = .init(intent: self)
    // 返回执行结果（应用会在启动后导航到指定标签页）
    return .result()
  }
}
