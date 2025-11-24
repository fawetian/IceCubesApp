// 文件功能：Mastodon 状态（帖子）数据模型，包含帖子内容、交互数据、媒体附件等完整信息。
// 相关技术点：
// - AnyStatus 协议：抽象状态接口，支持多态。
// - Visibility 枚举：帖子可见性级别。
// - Status 类：完整的帖子数据模型。
// - ReblogStatus：转发帖子的嵌套结构。
// - 计算属性：媒体状态转换、隐藏状态判断。
// - 占位符模式：测试和预览数据。
// - Equatable & Hashable：对象比较支持。
// - Codable：JSON 序列化支持。
//
// 技术点详解：
// 1. HTMLString：支持 HTML 格式的字符串类型。
// 2. ServerDate：服务器时间戳类型。
// 3. MediaAttachment：媒体附件数组。
// 4. filtered：内容过滤器，支持隐藏/警告。
// 5. spoilerText：敏感内容警告文本。
// 6. reblog：转发原帖的嵌套结构。
// 7. AnyStatus：协议抽象，支持不同状态类型。
// 8. asMediaStatus：转换为媒体状态数组。
// 导入基础库，用于基本数据类型
import Foundation

/// 帖子可见性枚举
///
/// 定义 Mastodon 帖子的四种隐私级别，从公开到私密递增。
///
/// - pub: 公开 - 所有人可见，出现在公共时间线
/// - unlisted: 不列出 - 所有人可见，但不出现在公共时间线
/// - priv: 仅关注者 - 只有关注者可见
/// - direct: 私信 - 只有被提及的用户可见
///
/// - Note: 回复的可见性不能高于原帖的可见性
public enum Visibility: String, Codable, CaseIterable, Hashable, Equatable, Sendable {
  case pub = "public"       // 公开
  case unlisted             // 不列出
  case priv = "private"     // 仅关注者
  case direct               // 私信
}

/// 状态协议
///
/// 定义了 Status 和 ReblogStatus 的共同接口。
/// 使用协议抽象是为了统一处理普通帖子和转发帖子。
///
/// 为什么需要这个协议？
/// - Status 包含 reblog 属性（转发的原帖）
/// - ReblogStatus 不包含 reblog（避免无限嵌套）
/// - 两者共享相同的属性和行为
/// - 通过协议可以统一处理两种类型
public protocol AnyStatus {
  var id: String { get }
  var content: HTMLString { get }
  var account: Account { get }
  var createdAt: ServerDate { get }
  var editedAt: ServerDate? { get }
  var mediaAttachments: [MediaAttachment] { get }
  var mentions: [Mention] { get }
  var repliesCount: Int { get }
  var reblogsCount: Int { get }
  var quotesCount: Int? { get }
  var favouritesCount: Int { get }
  var card: Card? { get }
  var favourited: Bool? { get }
  var reblogged: Bool? { get }
  var pinned: Bool? { get }
  var bookmarked: Bool? { get }
  var emojis: [Emoji] { get }
  var url: String? { get }
  var application: Application? { get }
  var inReplyToId: String? { get }
  var inReplyToAccountId: String? { get }
  var visibility: Visibility { get }
  var poll: Poll? { get }
  var spoilerText: HTMLString { get }
  var filtered: [Filtered]? { get }
  var sensitive: Bool { get }
  var language: String? { get }
  var tags: [Tag] { get }
  var isHidden: Bool { get }
  var quote: Quote? { get }
  var quoteApproval: QuoteApproval? { get }
}

/// Mastodon 状态（帖子）数据模型
///
/// 表示 Mastodon 中的一条帖子，包含内容、作者、交互数据、媒体附件等完整信息。
///
/// 核心特性：
/// - 不可变设计：所有属性都是 let，确保线程安全
/// - 支持转发：通过 reblog 属性嵌套原帖
/// - 支持引用：通过 quote 属性引用其他帖子
/// - 内容过滤：支持服务器端和客户端过滤规则
/// - 媒体附件：支持图片、视频、音频等多种媒体类型
///
/// 使用示例：
/// ```swift
/// let status: Status = try await client.get(endpoint: Statuses.status(id: "12345"))
/// print(status.content.asRawText)  // 获取纯文本内容
/// print(status.account.displayName)  // 获取作者名称
/// ```
///
/// - Note: Status 是 final class 而非 struct，因为它可能包含大量数据，使用引用类型更高效
public final class Status: AnyStatus, Codable, Identifiable, Equatable, Hashable {
  /// 相等性比较
  ///
  /// 两个 Status 相等的条件：
  /// 1. ID 相同（同一条帖子）
  /// 2. 编辑时间相同（同一个版本）
  ///
  /// 为什么要比较 editedAt？
  /// - Mastodon 支持编辑帖子
  /// - 编辑后 ID 不变，但内容可能改变
  /// - 通过 editedAt 区分不同版本
  public static func == (lhs: Status, rhs: Status) -> Bool {
    lhs.id == rhs.id && lhs.editedAt?.asDate == rhs.editedAt?.asDate
  }

  /// 哈希值计算
  ///
  /// 只使用 ID 计算哈希，因为：
  /// - ID 是唯一标识符
  /// - editedAt 可能变化，不适合用于哈希
  /// - 保持哈希稳定性，避免集合中的问题
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // MARK: - 基本信息
  
  /// 帖子的唯一标识符
  public let id: String
  
  /// 帖子内容（HTML 格式）
  /// 包含文本、链接、标签、提及等，支持富文本渲染
  public let content: HTMLString
  
  /// 发帖账户
  public let account: Account
  
  /// 创建时间
  public let createdAt: ServerDate
  
  /// 最后编辑时间（如果帖子被编辑过）
  public let editedAt: ServerDate?
  
  // MARK: - 转发和引用
  
  /// 转发的原帖
  /// 如果这是一条转发，reblog 包含原始帖子的内容
  /// 如果不是转发，reblog 为 nil
  public let reblog: ReblogStatus?
  
  /// 引用的帖子
  /// Mastodon 的引用功能，类似 Twitter 的 Quote Tweet
  public let quote: Quote?
  
  /// 引用审批状态
  /// 某些实例要求被引用者批准引用
  public let quoteApproval: QuoteApproval?
  
  // MARK: - 媒体和附件
  
  /// 媒体附件数组
  /// 可以包含图片、视频、音频等，最多 4 个
  public let mediaAttachments: [MediaAttachment]
  
  /// 链接卡片
  /// 当帖子包含链接时，显示链接预览卡片
  public let card: Card?
  
  // MARK: - 提及和标签
  
  /// 被提及的用户列表
  /// 格式：@username@instance.com
  public let mentions: [Mention]
  
  /// 标签列表
  /// 格式：#hashtag
  public let tags: [Tag]
  
  /// 自定义表情符号
  /// Mastodon 实例可以定义自定义表情
  public let emojis: [Emoji]
  
  // MARK: - 交互统计
  
  /// 回复数量
  public let repliesCount: Int
  
  /// 转发数量
  public let reblogsCount: Int
  
  /// 引用数量
  public let quotesCount: Int?
  
  /// 点赞数量
  public let favouritesCount: Int
  
  // MARK: - 用户交互状态
  
  /// 当前用户是否已点赞
  public let favourited: Bool?
  
  /// 当前用户是否已转发
  public let reblogged: Bool?
  
  /// 是否已置顶到个人资料
  public let pinned: Bool?
  
  /// 是否已收藏
  public let bookmarked: Bool?
  
  // MARK: - 回复关系
  
  /// 回复的帖子 ID
  /// 如果这是一条回复，指向被回复的帖子
  public let inReplyToId: String?
  
  /// 回复的账户 ID
  /// 如果这是一条回复，指向被回复的账户
  public let inReplyToAccountId: String?
  
  // MARK: - 隐私和内容设置
  
  /// 可见性级别
  public let visibility: Visibility
  
  /// 敏感内容警告文本
  /// 如果设置了 CW（Content Warning），这里包含警告文本
  public let spoilerText: HTMLString
  
  /// 是否标记为敏感内容
  /// 敏感内容默认隐藏，需要用户点击才能查看
  public let sensitive: Bool
  
  /// 内容过滤规则
  /// 服务器端或客户端的过滤规则，可以隐藏或警告特定内容
  public let filtered: [Filtered]?
  
  // MARK: - 其他信息
  
  /// 帖子的 Web URL
  /// 可以在浏览器中打开的链接
  public let url: String?
  
  /// 发帖使用的应用
  /// 例如："Ice Cubes", "Mastodon for iOS" 等
  public let application: Application?
  
  /// 帖子语言代码
  /// ISO 639-1 语言代码，如 "en", "zh", "ja"
  public let language: String?
  
  /// 投票
  /// 如果帖子包含投票，这里是投票数据
  public let poll: Poll?
  
  // MARK: - 计算属性
  
  /// 是否被过滤隐藏
  ///
  /// 根据过滤规则判断帖子是否应该被隐藏。
  /// 如果过滤动作是 .hide，返回 true。
  public var isHidden: Bool {
    filtered?.first?.filter.filterAction == .hide
  }
  
  /// 转换为媒体状态数组
  ///
  /// 将帖子的媒体附件转换为 MediaStatus 数组，用于媒体查看器。
  /// 每个 MediaStatus 包含帖子信息和对应的媒体附件。
  ///
  /// 使用场景：
  /// - 点击图片打开媒体查看器
  /// - 在媒体查看器中浏览多张图片
  /// - 显示媒体的上下文信息（作者、时间等）
  public var asMediaStatus: [MediaStatus] {
    mediaAttachments.map { .init(status: self, attachment: $0) }
  }

  public init(
    id: String, content: HTMLString, account: Account, createdAt: ServerDate, editedAt: ServerDate?,
    reblog: ReblogStatus?, mediaAttachments: [MediaAttachment], mentions: [Mention],
    repliesCount: Int, reblogsCount: Int, favouritesCount: Int, card: Card?, favourited: Bool?,
    reblogged: Bool?, pinned: Bool?, bookmarked: Bool?, emojis: [Emoji], url: String?,
    application: Application?, inReplyToId: String?, inReplyToAccountId: String?,
    visibility: Visibility, poll: Poll?, spoilerText: HTMLString, filtered: [Filtered]?,
    sensitive: Bool, language: String?, tags: [Tag] = [], quote: Quote?, quotesCount: Int?,
    quoteApproval: QuoteApproval?
  ) {
    self.id = id
    self.content = content
    self.account = account
    self.createdAt = createdAt
    self.editedAt = editedAt
    self.reblog = reblog
    self.mediaAttachments = mediaAttachments
    self.mentions = mentions
    self.repliesCount = repliesCount
    self.reblogsCount = reblogsCount
    self.favouritesCount = favouritesCount
    self.card = card
    self.favourited = favourited
    self.reblogged = reblogged
    self.pinned = pinned
    self.bookmarked = bookmarked
    self.emojis = emojis
    self.url = url
    self.application = application
    self.inReplyToId = inReplyToId
    self.inReplyToAccountId = inReplyToAccountId
    self.visibility = visibility
    self.poll = poll
    self.spoilerText = spoilerText
    self.filtered = filtered
    self.sensitive = sensitive
    self.language = language
    self.tags = tags
    self.quote = quote
    self.quotesCount = quotesCount
    self.quoteApproval = quoteApproval
  }

  /// 创建占位符状态
  ///
  /// 用于 SwiftUI 预览、测试和加载状态的占位数据。
  ///
  /// - Parameters:
  ///   - forSettings: 是否用于设置页面（影响内容格式）
  ///   - language: 指定语言代码
  /// - Returns: 包含示例数据的 Status 对象
  ///
  /// 使用场景：
  /// ```swift
  /// #Preview {
  ///     StatusRowView(status: .placeholder())
  /// }
  /// ```
  public static func placeholder(forSettings: Bool = false, language: String? = nil) -> Status {
    .init(
      id: UUID().uuidString,
      content: .init(
        stringValue:
          "Here's to the [#crazy](#) ones. The misfits.\nThe [@rebels](#). The troublemakers.",
        parseMarkdown: forSettings),

      account: .placeholder(),
      createdAt: ServerDate(),
      editedAt: nil,
      reblog: nil,
      mediaAttachments: [],
      mentions: [],
      repliesCount: 34,
      reblogsCount: 8,
      favouritesCount: 150,
      card: nil,
      favourited: false,
      reblogged: false,
      pinned: false,
      bookmarked: false,
      emojis: [],
      url: "https://example.com",
      application: nil,
      inReplyToId: nil,
      inReplyToAccountId: nil,
      visibility: .pub,
      poll: nil,
      spoilerText: .init(stringValue: ""),
      filtered: [],
      sensitive: false,
      language: language,
      tags: [],
      quote: nil,
      quotesCount: 2,
      quoteApproval: nil)
  }

  /// 创建占位符状态数组
  ///
  /// 返回 10 个占位符状态，用于列表预览和加载状态。
  ///
  /// 使用场景：
  /// ```swift
  /// #Preview {
  ///     List(Status.placeholders()) { status in
  ///         StatusRowView(status: status)
  ///     }
  /// }
  /// ```
  public static func placeholders() -> [Status] {
    [
      .placeholder(), .placeholder(), .placeholder(), .placeholder(), .placeholder(),
      .placeholder(), .placeholder(), .placeholder(), .placeholder(), .placeholder(),
    ]
  }

  /// 将转发状态转换为普通状态
  ///
  /// 如果这是一条转发（reblog 不为 nil），将转发的内容提取为独立的 Status 对象。
  /// 这样可以统一处理转发和普通帖子。
  ///
  /// 为什么需要这个方法？
  /// - 转发帖子的实际内容在 reblog 属性中
  /// - 某些场景需要直接访问原帖内容
  /// - 转换后可以使用相同的 UI 组件显示
  ///
  /// - Returns: 如果是转发返回原帖的 Status，否则返回 nil
  public var reblogAsAsStatus: Status? {
    if let reblog {
      return .init(
        id: reblog.id,
        content: reblog.content,
        account: reblog.account,
        createdAt: reblog.createdAt,
        editedAt: reblog.editedAt,
        reblog: nil,
        mediaAttachments: reblog.mediaAttachments,
        mentions: reblog.mentions,
        repliesCount: reblog.repliesCount,
        reblogsCount: reblog.reblogsCount,
        favouritesCount: reblog.favouritesCount,
        card: reblog.card,
        favourited: reblog.favourited,
        reblogged: reblog.reblogged,
        pinned: reblog.pinned,
        bookmarked: reblog.bookmarked,
        emojis: reblog.emojis,
        url: reblog.url,
        application: reblog.application,
        inReplyToId: reblog.inReplyToId,
        inReplyToAccountId: reblog.inReplyToAccountId,
        visibility: reblog.visibility,
        poll: reblog.poll,
        spoilerText: reblog.spoilerText,
        filtered: reblog.filtered,
        sensitive: reblog.sensitive,
        language: reblog.language,
        tags: reblog.tags,
        quote: reblog.quote,
        quotesCount: reblog.quotesCount,
        quoteApproval: reblog.quoteApproval)
    }
    return nil
  }
}

/// 转发状态数据模型
///
/// 表示被转发的原始帖子。与 Status 类似，但不包含 reblog 属性以避免无限嵌套。
///
/// 为什么需要单独的 ReblogStatus？
/// - Status 包含 reblog 属性（可以转发其他帖子）
/// - ReblogStatus 不包含 reblog（转发的帖子不能再被转发）
/// - 这种设计避免了无限嵌套的数据结构
/// - 符合 Mastodon API 的实际行为（不支持转发的转发）
///
/// 数据流：
/// ```
/// 用户 A 发布原帖 → Status (reblog: nil)
/// 用户 B 转发 A 的帖子 → Status (reblog: ReblogStatus)
/// 用户 C 看到 B 的转发 → 显示 B 的信息 + A 的原帖内容
/// ```
///
/// - Note: ReblogStatus 和 Status 共享 AnyStatus 协议，可以统一处理
public final class ReblogStatus: AnyStatus, Codable, Identifiable, Equatable, Hashable {
  /// 相等性比较
  ///
  /// 只比较 ID，因为 ReblogStatus 不支持编辑
  public static func == (lhs: ReblogStatus, rhs: ReblogStatus) -> Bool {
    lhs.id == rhs.id
  }

  /// 哈希值计算
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public let id: String
  public let content: HTMLString
  public let account: Account
  public let createdAt: ServerDate
  public let editedAt: ServerDate?
  public let mediaAttachments: [MediaAttachment]
  public let mentions: [Mention]
  public let repliesCount: Int
  public let reblogsCount: Int
  public let quotesCount: Int?
  public let favouritesCount: Int
  public let card: Card?
  public let favourited: Bool?
  public let reblogged: Bool?
  public let pinned: Bool?
  public let bookmarked: Bool?
  public let emojis: [Emoji]
  public let url: String?
  public let application: Application?
  public let inReplyToId: String?
  public let inReplyToAccountId: String?
  public let visibility: Visibility
  public let poll: Poll?
  public let spoilerText: HTMLString
  public let filtered: [Filtered]?
  public let sensitive: Bool
  public let language: String?
  public let tags: [Tag]
  public let quote: Quote?
  public let quoteApproval: QuoteApproval?

  /// 是否被过滤隐藏
  ///
  /// 与 Status 的 isHidden 逻辑相同
  public var isHidden: Bool {
    filtered?.first?.filter.filterAction == .hide
  }

  /// 初始化转发状态
  ///
  /// - Note: 参数与 Status 相同，但不包含 reblog 属性
  public init(
    id: String, content: HTMLString, account: Account, createdAt: ServerDate, editedAt: ServerDate?,
    mediaAttachments: [MediaAttachment], mentions: [Mention], repliesCount: Int, reblogsCount: Int,
    favouritesCount: Int, card: Card?, favourited: Bool?, reblogged: Bool?, pinned: Bool?,
    bookmarked: Bool?, emojis: [Emoji], url: String?, application: Application? = nil,
    inReplyToId: String?, inReplyToAccountId: String?, visibility: Visibility, poll: Poll?,
    spoilerText: HTMLString, filtered: [Filtered]?, sensitive: Bool, language: String?,
    tags: [Tag] = [], quote: Quote?, quotesCount: Int?, quoteApproval: QuoteApproval?
  ) {
    self.id = id
    self.content = content
    self.account = account
    self.createdAt = createdAt
    self.editedAt = editedAt
    self.mediaAttachments = mediaAttachments
    self.mentions = mentions
    self.repliesCount = repliesCount
    self.reblogsCount = reblogsCount
    self.favouritesCount = favouritesCount
    self.card = card
    self.favourited = favourited
    self.reblogged = reblogged
    self.pinned = pinned
    self.bookmarked = bookmarked
    self.emojis = emojis
    self.url = url
    self.application = application
    self.inReplyToId = inReplyToId
    self.inReplyToAccountId = inReplyToAccountId
    self.visibility = visibility
    self.poll = poll
    self.spoilerText = spoilerText
    self.filtered = filtered
    self.sensitive = sensitive
    self.language = language
    self.tags = tags
    self.quote = quote
    self.quotesCount = quotesCount
    self.quoteApproval = quoteApproval
  }
}

// MARK: - Sendable 一致性

/// Status 符合 Sendable 协议
///
/// 原因：
/// - 所有属性都是 let（不可变）
/// - 所有属性类型都是 Sendable
/// - 可以安全地在并发上下文中传递
///
/// 这使得 Status 可以：
/// - 在 Actor 之间传递
/// - 在 Task 中使用
/// - 在 @MainActor 和后台线程之间传递
extension Status: Sendable {}

/// ReblogStatus 符合 Sendable 协议
///
/// 原因同 Status
extension ReblogStatus: Sendable {}
