// 文件功能：当前实例管理核心类
//
// 核心职责：
// - 管理当前 Mastodon 实例的信息
// - 检测实例支持的功能特性
// - 根据实例版本判断 API 可用性
// - 提供实例配置和限制信息
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架，支持 SwiftUI 响应式更新
// - @MainActor：确保所有操作在主线程执行，保证 UI 安全
// - 版本检测：根据 Mastodon 版本号判断功能支持
// - 单例模式：全局共享的实例状态
// - API 版本兼容：处理不同版本的 API 差异
//
// 功能检测：
// - 过滤器支持（v4.0+）
// - 帖子编辑支持（v3.5+）
// - Alt 文本编辑支持（v4.1+）
// - 通知过滤支持（v4.3+）
// - 链接时间线支持（v4.3+）
// - 分组通知支持（v4.3+）
// - 引用帖子支持（API v7+）
//
// 依赖关系：
// - 依赖：Foundation, Models, NetworkClient
// - 被依赖：需要检测实例功能的视图和服务

import Combine
import Foundation
import Models
import NetworkClient
import Observation

/// 当前实例管理器
///
/// 管理当前 Mastodon 实例的信息和功能检测。
///
/// 主要功能：
/// - **实例信息**：存储和管理实例的详细信息
/// - **版本检测**：解析实例版本号
/// - **功能检测**：根据版本判断功能是否可用
/// - **API 兼容**：处理不同版本的 API 差异
/// - **配置限制**：提供实例的配置和限制信息
///
/// 使用方式：
/// ```swift
/// // 在 SwiftUI 视图中使用
/// struct SettingsView: View {
///     @Environment(CurrentInstance.self) private var currentInstance
///
///     var body: some View {
///         if currentInstance.isFiltersSupported {
///             FilterSettingsView()
///         } else {
///             Text("此实例不支持过滤器功能")
///         }
///     }
/// }
///
/// // 设置客户端并获取实例信息
/// CurrentInstance.shared.setClient(client: mastodonClient)
/// await CurrentInstance.shared.fetchCurrentInstance()
///
/// // 检测功能支持
/// if CurrentInstance.shared.isEditSupported {
///     // 显示编辑按钮
/// }
/// ```
///
/// 版本检测逻辑：
/// - 解析实例版本字符串（如 "4.1.2"）
/// - 提取主版本号和次版本号
/// - 与功能要求的最低版本比较
///
/// 支持的功能检测：
/// - **过滤器**：v4.0+ 支持内容过滤
/// - **编辑帖子**：v3.5+ 支持编辑已发布的帖子
/// - **编辑 Alt 文本**：v4.1+ 支持编辑媒体的 Alt 文本
/// - **通知过滤**：v4.3+ 支持通知类型过滤
/// - **链接时间线**：v4.3+ 支持链接趋势时间线
/// - **分组通知**：v4.3+ 支持通知分组显示
/// - **引用帖子**：API v7+ 支持引用功能
///
/// - Note: 使用单例模式，通过 `CurrentInstance.shared` 访问
/// - Important: 需要先设置客户端并获取实例信息才能使用功能检测
/// - SeeAlso: `Instance` 包含实例的完整信息
@MainActor
@Observable public class CurrentInstance {
  /// 当前实例信息
  ///
  /// 包含实例的完整信息，如名称、描述、配置、规则等。
  ///
  /// 状态：
  /// - nil: 未获取或获取失败
  /// - Instance: 包含完整的实例信息
  ///
  /// 使用场景：
  /// - 显示实例信息
  /// - 检查配置限制
  /// - 功能检测
  public private(set) var instance: Instance?

  /// Mastodon 客户端
  ///
  /// 用于获取实例信息的网络客户端。
  private var client: MastodonClient?

  /// 单例实例
  ///
  /// 全局共享的实例管理器。
  public static let shared = CurrentInstance()

  /// 实例版本号
  ///
  /// 从实例版本字符串中提取的浮点数版本号。
  ///
  /// 解析逻辑：
  /// - 版本字符串长度 > 2：取前 3 个字符（如 "4.1" 从 "4.1.2"）
  /// - 版本字符串长度 <= 2：取第 1 个字符（如 "4" 从 "4"）
  /// - 解析失败或无版本：返回 0
  ///
  /// 示例：
  /// - "4.1.2" → 4.1
  /// - "3.5.0" → 3.5
  /// - "4" → 4.0
  ///
  /// - Note: 这是一个私有计算属性，用于内部功能检测
  private var version: Float {
    if let stringVersion = instance?.version {
      if stringVersion.utf8.count > 2 {
        return Float(stringVersion.prefix(3)) ?? 0
      } else {
        return Float(stringVersion.prefix(1)) ?? 0
      }
    }
    return 0
  }

  /// 是否支持过滤器功能
  ///
  /// Mastodon v4.0+ 支持内容过滤器。
  ///
  /// 功能说明：
  /// - 过滤特定关键词的帖子
  /// - 过滤特定用户的内容
  /// - 自定义过滤规则
  ///
  /// 使用场景：
  /// - 显示/隐藏过滤器设置
  /// - 启用/禁用过滤功能
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.isFiltersSupported {
  ///     NavigationLink("内容过滤器", destination: FiltersView())
  /// }
  /// ```
  public var isFiltersSupported: Bool {
    version >= 4
  }

  /// 是否支持编辑帖子
  ///
  /// Mastodon v3.5+ 支持编辑已发布的帖子。
  ///
  /// 功能说明：
  /// - 编辑帖子文本
  /// - 修改媒体附件
  /// - 查看编辑历史
  ///
  /// 使用场景：
  /// - 显示/隐藏编辑按钮
  /// - 启用/禁用编辑功能
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.isEditSupported {
  ///     Button("编辑", action: editStatus)
  /// }
  /// ```
  public var isEditSupported: Bool {
    version >= 3.5
  }

  /// 是否支持编辑 Alt 文本
  ///
  /// Mastodon v4.1+ 支持编辑媒体的 Alt 文本。
  ///
  /// 功能说明：
  /// - 为图片添加描述文本
  /// - 提高无障碍访问性
  /// - 帮助视障用户理解图片内容
  ///
  /// 使用场景：
  /// - 显示/隐藏 Alt 文本编辑器
  /// - 启用/禁用 Alt 文本功能
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.isEditAltTextSupported {
  ///     TextField("图片描述", text: $altText)
  /// }
  /// ```
  public var isEditAltTextSupported: Bool {
    version >= 4.1
  }

  /// 是否支持通知过滤
  ///
  /// Mastodon v4.3+ 支持通知类型过滤。
  ///
  /// 功能说明：
  /// - 按类型过滤通知（关注、点赞、转发等）
  /// - 自定义通知显示
  /// - 减少通知干扰
  ///
  /// 使用场景：
  /// - 显示/隐藏通知过滤器
  /// - 启用/禁用过滤功能
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.isNotificationsFilterSupported {
  ///     NotificationFilterPicker(selection: $filter)
  /// }
  /// ```
  public var isNotificationsFilterSupported: Bool {
    version >= 4.3
  }

  /// 是否支持链接时间线
  ///
  /// Mastodon v4.3+ 支持链接趋势时间线。
  ///
  /// 功能说明：
  /// - 查看热门链接
  /// - 发现趋势内容
  /// - 浏览分享的文章
  ///
  /// 使用场景：
  /// - 显示/隐藏链接时间线标签
  /// - 启用/禁用链接功能
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.isLinkTimelineSupported {
  ///     NavigationLink("热门链接", destination: TrendingLinksView())
  /// }
  /// ```
  public var isLinkTimelineSupported: Bool {
    version >= 4.3
  }

  /// 是否支持分组通知
  ///
  /// Mastodon v4.3+ 支持通知分组显示。
  ///
  /// 功能说明：
  /// - 将相同类型的通知分组
  /// - 减少通知列表长度
  /// - 提高通知可读性
  ///
  /// 使用场景：
  /// - 启用/禁用分组显示
  /// - 选择通知显示模式
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.isGroupedNotificationsSupported {
  ///     Toggle("分组显示通知", isOn: $useGroupedNotifications)
  /// }
  /// ```
  public var isGroupedNotificationsSupported: Bool {
    version >= 4.3
  }

  /// 是否支持引用帖子
  ///
  /// Mastodon API v7+ 支持引用帖子功能。
  ///
  /// 功能说明：
  /// - 引用其他人的帖子
  /// - 添加自己的评论
  /// - 类似 Twitter 的引用转发
  ///
  /// 使用场景：
  /// - 显示/隐藏引用按钮
  /// - 启用/禁用引用功能
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.isQuoteSupported {
  ///     Button("引用", action: quoteStatus)
  /// }
  /// ```
  ///
  /// - Note: 这个功能依赖 API 版本而不是实例版本
  public var isQuoteSupported: Bool {
    instance?.apiVersions?.mastodon ?? 0 >= 7
  }

  /// 是否可以查看帖子的引用
  ///
  /// Mastodon API v7+ 支持查看帖子的引用列表。
  ///
  /// 功能说明：
  /// - 查看谁引用了这条帖子
  /// - 浏览引用内容
  /// - 追踪帖子传播
  ///
  /// 使用场景：
  /// - 显示/隐藏引用列表
  /// - 启用/禁用引用查看
  ///
  /// 示例：
  /// ```swift
  /// if currentInstance.canViewStatusQuotes {
  ///     NavigationLink("查看引用", destination: QuotesView(statusId: id))
  /// }
  /// ```
  ///
  /// - Note: 这个功能依赖 API 版本而不是实例版本
  public var canViewStatusQuotes: Bool {
    instance?.apiVersions?.mastodon ?? 0 >= 7
  }

  /// 私有初始化方法
  ///
  /// 确保单例模式，防止外部创建实例。
  private init() {}

  /// 设置客户端
  ///
  /// 配置用于获取实例信息的 Mastodon 客户端。
  ///
  /// - Parameter client: Mastodon 客户端
  ///
  /// 使用场景：
  /// - 用户登录后
  /// - 切换账户时
  /// - 应用启动时
  ///
  /// 示例：
  /// ```swift
  /// let client = MastodonClient(server: "mastodon.social", oauthToken: token)
  /// CurrentInstance.shared.setClient(client: client)
  /// await CurrentInstance.shared.fetchCurrentInstance()
  /// ```
  public func setClient(client: MastodonClient) {
    self.client = client
  }

  /// 获取当前实例信息
  ///
  /// 从服务器获取实例的详细信息。
  ///
  /// 获取的信息包括：
  /// - 实例名称和描述
  /// - 版本号
  /// - 配置限制（字符数、媒体大小等）
  /// - 社区规则
  /// - 统计数据
  /// - API 版本信息
  ///
  /// 使用场景：
  /// - 应用启动时
  /// - 切换账户后
  /// - 需要刷新实例信息时
  ///
  /// 错误处理：
  /// - 如果获取失败，instance 保持为 nil
  /// - 功能检测会返回 false（因为版本为 0）
  ///
  /// 示例：
  /// ```swift
  /// CurrentInstance.shared.setClient(client: client)
  /// await CurrentInstance.shared.fetchCurrentInstance()
  ///
  /// if let instance = CurrentInstance.shared.instance {
  ///     print("实例名称：\(instance.title)")
  ///     print("版本：\(instance.version)")
  /// }
  /// ```
  ///
  /// - Note: 这是一个异步方法，可能需要几秒钟完成
  /// - Important: 需要先调用 setClient 设置客户端
  public func fetchCurrentInstance() async {
    guard let client else { return }
    instance = try? await client.get(endpoint: Instances.instance, forceVersion: .v2)
  }
}
