// 文件功能：Mastodon 用户账户数据模型
//
// 核心职责：
// - 表示 Mastodon 用户的完整资料信息
// - 包含用户基本信息、统计数据、自定义字段等
// - 支持账户迁移、验证标记等高级功能
// - 提供显示名称、头像等 UI 相关的便捷属性
//
// 技术要点：
// - Codable：自定义 JSON 解码，处理 cachedDisplayName 的计算
// - Equatable：比较多个属性以判断账户是否相同
// - Hashable：使用 ID 作为哈希值
// - Sendable：不可变设计，支持并发安全
// - 嵌套类型：Field（自定义字段）和 Source（账户设置）
//
// 数据结构：
// - Field：用户可以添加最多 4 个自定义字段（如网站、代词等）
// - Source：账户的隐私设置和默认值
// - moved：如果用户迁移账户，指向新账户
//
// 依赖关系：
// - 依赖：HTMLString, ServerDate, Emoji, Visibility
// - 被依赖：Status, Notification, Relationship 等所有涉及用户的模型

import Foundation

/// Mastodon 用户账户数据模型
///
/// 表示 Mastodon 中的一个用户账户，包含：
/// - 基本信息：用户名、显示名称、简介
/// - 统计数据：关注数、粉丝数、帖子数
/// - 媒体资源：头像、横幅图片
/// - 自定义字段：用户定义的额外信息
/// - 账户状态：是否锁定、是否机器人、是否可发现
///
/// 使用示例：
/// ```swift
/// let account: Account = try await client.get(endpoint: Accounts.account(id: "12345"))
/// print(account.displayName ?? account.username)  // 显示名称
/// print(account.followersCount)  // 粉丝数
/// ```
///
/// - Note: Account 是 final class，因为它包含大量数据，使用引用类型更高效
public final class Account: Codable, Identifiable, Hashable, Sendable, Equatable {
  /// 相等性比较
  ///
  /// 比较两个 Account 是否相等，需要检查多个属性：
  /// - 基本信息：ID、用户名、显示名称
  /// - 简介内容
  /// - 统计数据：帖子数、关注数、粉丝数
  /// - 自定义字段
  /// - 账户状态：锁定、机器人、可发现
  /// - 媒体资源：头像、横幅
  ///
  /// 为什么要比较这么多属性？
  /// - 账户信息可能会更新（修改简介、头像等）
  /// - 统计数据会实时变化
  /// - 需要检测这些变化以更新 UI
  public static func == (lhs: Account, rhs: Account) -> Bool {
    lhs.id == rhs.id && lhs.username == rhs.username && lhs.note.asRawText == rhs.note.asRawText
      && lhs.statusesCount == rhs.statusesCount && lhs.followersCount == rhs.followersCount
      && lhs.followingCount == rhs.followingCount && lhs.acct == rhs.acct
      && lhs.displayName == rhs.displayName && lhs.fields == rhs.fields
      && lhs.lastStatusAt == rhs.lastStatusAt && lhs.discoverable == rhs.discoverable
      && lhs.bot == rhs.bot && lhs.locked == rhs.locked && lhs.avatar == rhs.avatar
      && lhs.header == rhs.header
  }

  /// 哈希值计算
  ///
  /// 只使用 ID 计算哈希，因为 ID 是唯一且不变的标识符
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  /// 用户自定义字段
  ///
  /// Mastodon 允许用户添加最多 4 个自定义字段，用于展示额外信息。
  ///
  /// 常见用途：
  /// - 个人网站链接
  /// - 代词（he/him, she/her, they/them）
  /// - 其他社交媒体账号
  /// - 位置信息
  ///
  /// 验证功能：
  /// - 如果字段值是链接，且在网站上添加了反向链接
  /// - Mastodon 会验证并显示绿色勾选标记
  /// - verifiedAt 记录验证时间
  ///
  /// 使用示例：
  /// ```swift
  /// for field in account.fields {
  ///     print("\(field.name): \(field.value.asRawText)")
  ///     if field.verifiedAt != nil {
  ///         print("✓ 已验证")
  ///     }
  /// }
  /// ```
  public struct Field: Codable, Equatable, Identifiable, Sendable {
    /// 字段的唯一标识符
    ///
    /// 由值和名称组合生成，用于 SwiftUI 列表渲染
    public var id: String {
      value.asRawText + name
    }

    /// 字段名称（如 "Website", "Pronouns"）
    public let name: String
    
    /// 字段值（HTML 格式，可能包含链接）
    public let value: HTMLString
    
    /// 验证时间
    /// 如果字段值是链接且已验证，这里记录验证时间
    /// 未验证的字段此值为 nil
    public let verifiedAt: String?
  }

  /// 账户设置源数据
  ///
  /// 包含账户的隐私设置和默认值，只有在获取自己的账户信息时才会返回。
  ///
  /// 用途：
  /// - 获取用户的默认发帖可见性
  /// - 获取默认的敏感内容设置
  /// - 获取默认语言
  /// - 获取原始简介文本（用于编辑）
  ///
  /// - Note: 查看其他用户的账户时，source 为 nil
  public struct Source: Codable, Equatable, Sendable {
    /// 默认发帖可见性
    public let privacy: Visibility?
    
    /// 默认是否标记为敏感内容
    public let sensitive: Bool
    
    /// 默认发帖语言
    public let language: String?
    
    /// 简介的原始文本（未渲染的 Markdown/HTML）
    public let note: String
    
    /// 自定义字段的原始数据
    public let fields: [Field]
  }

  // MARK: - 基本信息
  
  /// 账户的唯一标识符
  public let id: String
  
  /// 用户名（不包含实例域名）
  /// 例如：对于 @alice@mastodon.social，username 是 "alice"
  public let username: String
  
  /// 显示名称（用户设置的昵称）
  /// 可以包含 Emoji 和特殊字符
  /// 如果用户未设置，可能为 nil 或空字符串
  public let displayName: String?
  
  /// 缓存的显示名称
  ///
  /// 性能优化：在初始化时计算一次，避免重复计算。
  ///
  /// 逻辑：
  /// - 如果有 displayName 且非空，使用 displayName
  /// - 否则使用 @username 格式
  ///
  /// 为什么需要缓存？
  /// - 显示名称在 UI 中频繁使用
  /// - 避免每次都判断 displayName 是否为空
  /// - 提高列表滚动性能
  public let cachedDisplayName: HTMLString
  
  /// 头像 URL
  public let avatar: URL
  
  /// 横幅图片 URL（个人资料页顶部的大图）
  public let header: URL
  
  /// 完整账户名（包含实例域名）
  /// 格式：username@instance.com
  /// 例如：alice@mastodon.social
  public let acct: String
  
  /// 个人简介（HTML 格式）
  /// 可以包含链接、标签、提及等
  public let note: HTMLString
  
  /// 账户创建时间
  public let createdAt: ServerDate
  
  // MARK: - 统计数据
  
  /// 粉丝数量
  /// 某些实例可能隐藏此数据，返回 nil
  public let followersCount: Int?
  
  /// 关注数量
  /// 某些实例可能隐藏此数据，返回 nil
  public let followingCount: Int?
  
  /// 帖子数量
  /// 某些实例可能隐藏此数据，返回 nil
  public let statusesCount: Int?
  
  /// 最后发帖时间（日期字符串）
  /// 格式：YYYY-MM-DD
  public let lastStatusAt: String?
  
  // MARK: - 自定义内容
  
  /// 用户自定义字段数组（最多 4 个）
  public let fields: [Field]
  
  /// 自定义表情符号
  /// 用户可以在显示名称和简介中使用自定义表情
  public let emojis: [Emoji]
  
  // MARK: - 账户状态
  
  /// 是否锁定账户
  /// 锁定账户需要手动批准关注请求
  public let locked: Bool
  
  /// 是否为机器人账户
  /// 机器人账户会显示特殊标记
  public let bot: Bool
  
  /// 是否可被发现
  /// 控制账户是否出现在目录和推荐中
  public let discoverable: Bool?
  
  /// 账户迁移
  /// 如果用户迁移到新账户，这里指向新账户
  /// 旧账户会显示"已迁移"标记
  public let moved: Account?
  
  // MARK: - 其他信息
  
  /// 账户的 Web URL
  /// 可以在浏览器中打开的个人资料链接
  public let url: URL?
  
  /// 账户设置源数据
  /// 只有查看自己的账户时才有值
  public let source: Source?
  
  // MARK: - 计算属性
  
  /// 是否有自定义头像
  ///
  /// Mastodon 的默认头像文件名是 "missing.png"
  /// 通过检查文件名判断用户是否上传了自定义头像
  ///
  /// 用途：
  /// - 决定是否显示默认头像占位符
  /// - 优化图片加载策略
  public var haveAvatar: Bool {
    avatar.lastPathComponent != "missing.png"
  }

  /// 是否有自定义横幅
  ///
  /// 逻辑同 haveAvatar
  public var haveHeader: Bool {
    header.lastPathComponent != "missing.png"
  }

  /// 完整账户名（包含实例域名）
  ///
  /// 格式：username@instance.com@host
  /// 例如：alice@mastodon.social@mastodon.social
  ///
  /// 用途：
  /// - 唯一标识跨实例的用户
  /// - 用于搜索和提及
  public var fullAccountName: String {
    "\(acct)@\(url?.host() ?? "")"
  }

  public init(
    id: String, username: String, displayName: String?, avatar: URL, header: URL, acct: String,
    note: HTMLString, createdAt: ServerDate, followersCount: Int, followingCount: Int,
    statusesCount: Int, lastStatusAt: String? = nil, fields: [Account.Field], locked: Bool,
    emojis: [Emoji], url: URL? = nil, source: Account.Source? = nil, bot: Bool,
    discoverable: Bool? = nil, moved: Account? = nil
  ) {
    self.id = id
    self.username = username
    self.displayName = displayName
    self.avatar = avatar
    self.header = header
    self.acct = acct
    self.note = note
    self.createdAt = createdAt
    self.followersCount = followersCount
    self.followingCount = followingCount
    self.statusesCount = statusesCount
    self.lastStatusAt = lastStatusAt
    self.fields = fields
    self.locked = locked
    self.emojis = emojis
    self.url = url
    self.source = source
    self.bot = bot
    self.discoverable = discoverable
    self.moved = moved

    if let displayName, !displayName.isEmpty {
      cachedDisplayName = .init(stringValue: displayName)
    } else {
      cachedDisplayName = .init(stringValue: "@\(username)")
    }
  }

  public enum CodingKeys: CodingKey {
    case id
    case username
    case displayName
    case avatar
    case header
    case acct
    case note
    case createdAt
    case followersCount
    case followingCount
    case statusesCount
    case lastStatusAt
    case fields
    case locked
    case emojis
    case url
    case source
    case bot
    case discoverable
    case moved
  }

  /// 自定义 Codable 解码
  ///
  /// 为什么需要自定义解码？
  /// - cachedDisplayName 不是 API 返回的字段
  /// - 需要在解码时根据 displayName 计算 cachedDisplayName
  /// - 这是一种性能优化，避免运行时重复计算
  ///
  /// 解码逻辑：
  /// 1. 解码所有 API 返回的字段
  /// 2. 根据 displayName 是否为空计算 cachedDisplayName
  /// 3. 如果有 displayName 且非空，使用 displayName
  /// 4. 否则使用 @username 格式
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    username = try container.decode(String.self, forKey: .username)
    displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
    avatar = try container.decode(URL.self, forKey: .avatar)
    header = try container.decode(URL.self, forKey: .header)
    acct = try container.decode(String.self, forKey: .acct)
    note = try container.decode(HTMLString.self, forKey: .note)
    createdAt = try container.decode(ServerDate.self, forKey: .createdAt)
    followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount)
    followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount)
    statusesCount = try container.decodeIfPresent(Int.self, forKey: .statusesCount)
    lastStatusAt = try container.decodeIfPresent(String.self, forKey: .lastStatusAt)
    fields = try container.decode([Account.Field].self, forKey: .fields)
    locked = try container.decode(Bool.self, forKey: .locked)
    emojis = try container.decode([Emoji].self, forKey: .emojis)
    url = try container.decodeIfPresent(URL.self, forKey: .url)
    source = try container.decodeIfPresent(Account.Source.self, forKey: .source)
    bot = try container.decode(Bool.self, forKey: .bot)
    discoverable = try container.decodeIfPresent(Bool.self, forKey: .discoverable)
    moved = try container.decodeIfPresent(Account.self, forKey: .moved)

    // 计算缓存的显示名称
    if let displayName, !displayName.isEmpty {
      cachedDisplayName = .init(stringValue: displayName)
    } else {
      cachedDisplayName = .init(stringValue: "@\(username)")
    }
  }

  /// 创建占位符账户
  ///
  /// 用于 SwiftUI 预览、测试和加载状态。
  ///
  /// 使用场景：
  /// ```swift
  /// #Preview {
  ///     AccountRowView(account: .placeholder())
  /// }
  /// ```
  public static func placeholder() -> Account {
    .init(
      id: UUID().uuidString,
      username: "Username",
      displayName: "John Mastodon",
      avatar: URL(
        string:
          "https://files.mastodon.social/media_attachments/files/003/134/405/original/04060b07ddf7bb0b.png"
      )!,
      header: URL(
        string:
          "https://files.mastodon.social/media_attachments/files/003/134/405/original/04060b07ddf7bb0b.png"
      )!,
      acct: "johnm@example.com",
      note: .init(stringValue: "Some content"),
      createdAt: ServerDate(),
      followersCount: 10,
      followingCount: 10,
      statusesCount: 10,
      lastStatusAt: nil,
      fields: [],
      locked: false,
      emojis: [],
      url: nil,
      source: nil,
      bot: false,
      discoverable: true)
  }

  /// 创建占位符账户数组
  ///
  /// 返回 10 个占位符账户，用于列表预览。
  ///
  /// 使用场景：
  /// ```swift
  /// #Preview {
  ///     List(Account.placeholders()) { account in
  ///         AccountRowView(account: account)
  ///     }
  /// }
  /// ```
  public static func placeholders() -> [Account] {
    [
      .placeholder(), .placeholder(), .placeholder(), .placeholder(), .placeholder(),
      .placeholder(), .placeholder(), .placeholder(), .placeholder(), .placeholder(),
    ]
  }
}

/// 熟悉的账户
///
/// Mastodon API 返回的"你可能认识的人"数据结构。
/// 用于推荐功能，显示与某个账户有共同关注者的其他账户。
///
/// 使用场景：
/// - 查看某个账户的详情时，显示"你们共同关注的人"
/// - 推荐关注功能
///
/// API 端点：
/// - GET /api/v1/accounts/familiar_followers
public struct FamiliarAccounts: Decodable {
  /// 目标账户的 ID
  public let id: String
  
  /// 与目标账户有共同关注关系的账户列表
  public let accounts: [Account]
}

/// FamiliarAccounts 符合 Sendable 协议
///
/// 所有属性都是不可变的，可以安全地在并发上下文中使用
extension FamiliarAccounts: Sendable {}
