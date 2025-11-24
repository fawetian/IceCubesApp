// 文件功能：Mastodon 账户相关 API 端点定义
//
// 核心职责：
// - 定义所有账户相关的 API 端点
// - 支持账户查询和查找
// - 支持账户关系管理（关注、屏蔽、静音）
// - 支持账户信息更新
// - 支持账户内容查询（帖子、关注者、关注列表）
// - 提供账户数据的结构定义
//
// 技术要点：
// - Accounts：枚举类型，每个 case 代表一个账户操作
// - UpdateCredentialsData：账户信息更新数据
// - MuteData：静音设置数据
// - RelationshipNoteData：关系备注数据
// - 符合 Endpoint 协议：提供 path()、queryItems()、jsonValue
//
// 账户操作类型：
// - 查询：accounts, lookup, verifyCredentials
// - 内容：statuses, favorites, bookmarks, featuredTags
// - 关系：follow, unfollow, relationships, familiarFollowers
// - 社交：followers, following, suggestions
// - 管理：block, mute, relationshipNote
// - 设置：updateCredentials, preferences
//
// 依赖关系：
// - 依赖：Foundation, Models
// - 被依赖：AccountDetailView, ProfileView, MastodonClient

import Foundation
import Models

/// Mastodon 账户 API 端点
///
/// 定义了所有与账户相关的操作。
///
/// 主要功能：
/// - **查询账户**：获取账户信息、查找账户、验证凭据
/// - **账户内容**：获取账户的帖子、点赞、书签
/// - **关系管理**：关注、取消关注、查询关系
/// - **社交功能**：查看关注者、正在关注、推荐账户
/// - **隐私控制**：屏蔽、静音、设置备注
/// - **账户设置**：更新个人资料、偏好设置
///
/// 使用示例：
/// ```swift
/// // 获取账户信息
/// let account: Account = try await client.get(
///     endpoint: Accounts.accounts(id: "123456")
/// )
///
/// // 查找账户
/// let foundAccount: Account = try await client.get(
///     endpoint: Accounts.lookup(name: "user@mastodon.social")
/// )
///
/// // 关注账户
/// let relationship: Relationship = try await client.post(
///     endpoint: Accounts.follow(
///         id: "123456",
///         notify: true,
///         reblogs: true
///     )
/// )
///
/// // 更新个人资料
/// let updatedAccount: Account = try await client.patch(
///     endpoint: Accounts.updateCredentials(
///         json: UpdateCredentialsData(
///             displayName: "新名称",
///             note: "新简介",
///             source: .init(privacy: .public, sensitive: false),
///             bot: false,
///             locked: false,
///             discoverable: true,
///             fieldsAttributes: []
///         )
///     )
/// )
/// ```
///
/// - Note: 大多数操作需要认证
/// - SeeAlso: `UpdateCredentialsData` 用于更新账户信息
public enum Accounts: Endpoint {
  /// 获取账户信息
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 返回：完整的 Account 对象
  ///
  /// API 路径：`/api/v1/accounts/:id`
  /// HTTP 方法：GET
  case accounts(id: String)
  
  /// 通过用户名查找账户
  ///
  /// - Parameter name: 完整的账户名（username@instance 或 username）
  ///
  /// 使用场景：
  /// - 搜索用户
  /// - 通过 URL 解析账户
  /// - 跨实例查找
  ///
  /// 示例：
  /// - "user@mastodon.social"
  /// - "user"（本实例用户）
  ///
  /// API 路径：`/api/v1/accounts/lookup`
  /// HTTP 方法：GET
  case lookup(name: String)
  
  /// 获取点赞的帖子列表
  ///
  /// - Parameter sinceId: 分页参数（可选）
  ///
  /// 返回：Status 数组（当前用户点赞的帖子）
  ///
  /// API 路径：`/api/v1/favourites`
  /// HTTP 方法：GET
  case favorites(sinceId: String?)
  
  /// 获取书签列表
  ///
  /// - Parameter sinceId: 分页参数（可选）
  ///
  /// 返回：Status 数组（当前用户的书签）
  ///
  /// API 路径：`/api/v1/bookmarks`
  /// HTTP 方法：GET
  case bookmarks(sinceId: String?)
  
  /// 获取关注的标签列表
  ///
  /// 返回：Tag 数组（当前用户关注的标签）
  ///
  /// API 路径：`/api/v1/followed_tags`
  /// HTTP 方法：GET
  case followedTags
  
  /// 获取账户的精选标签
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 返回：FeaturedTag 数组
  ///
  /// 精选标签：
  /// - 显示在个人资料页
  /// - 展示用户的兴趣领域
  /// - 可以设置多个
  ///
  /// API 路径：`/api/v1/accounts/:id/featured_tags`
  /// HTTP 方法：GET
  case featuredTags(id: String)
  
  /// 验证当前用户的凭据
  ///
  /// 返回：当前用户的 Account 对象
  ///
  /// 使用场景：
  /// - 应用启动时验证登录状态
  /// - 刷新用户信息
  /// - 检查令牌是否有效
  ///
  /// API 路径：`/api/v1/accounts/verify_credentials`
  /// HTTP 方法：GET
  case verifyCredentials
  
  /// 更新账户媒体（头像或横幅）
  ///
  /// 使用 multipart/form-data 上传。
  ///
  /// API 路径：`/api/v1/accounts/update_credentials`
  /// HTTP 方法：PATCH
  case updateCredentialsMedia
  
  /// 更新账户信息
  ///
  /// - Parameter json: 更新数据
  ///
  /// 可更新的字段：
  /// - 显示名称
  /// - 简介
  /// - 头像和横幅
  /// - 个人资料字段
  /// - 隐私设置
  /// - 机器人标记
  /// - 锁定状态
  ///
  /// API 路径：`/api/v1/accounts/update_credentials`
  /// HTTP 方法：PATCH
  case updateCredentials(json: UpdateCredentialsData)
  
  /// 获取账户的帖子列表
  ///
  /// - Parameters:
  ///   - id: 账户 ID
  ///   - sinceId: 分页参数（可选）
  ///   - tag: 只显示包含此标签的帖子（可选）
  ///   - onlyMedia: 只显示包含媒体的帖子
  ///   - excludeReplies: 排除回复
  ///   - excludeReblogs: 排除转发
  ///   - pinned: 只显示置顶的帖子（可选）
  ///
  /// 返回：Status 数组
  ///
  /// 使用场景：
  /// - 显示用户的个人资料页
  /// - 查看用户的媒体帖子
  /// - 过滤特定类型的内容
  ///
  /// API 路径：`/api/v1/accounts/:id/statuses`
  /// HTTP 方法：GET
  case statuses(
    id: String,
    sinceId: String?,
    tag: String?,
    onlyMedia: Bool,
    excludeReplies: Bool,
    excludeReblogs: Bool,
    pinned: Bool?)
  
  /// 查询与多个账户的关系
  ///
  /// - Parameter ids: 账户 ID 数组
  ///
  /// 返回：Relationship 数组
  ///
  /// 使用场景：
  /// - 批量查询关系状态
  /// - 在列表中显示关系状态
  /// - 优化网络请求
  ///
  /// API 路径：`/api/v1/accounts/relationships`
  /// HTTP 方法：GET
  case relationships(ids: [String])
  
  /// 关注账户
  ///
  /// - Parameters:
  ///   - id: 账户 ID
  ///   - notify: 是否开启通知（用户发帖时通知你）
  ///   - reblogs: 是否显示转发
  ///
  /// 返回：Relationship 对象
  ///
  /// 关注设置：
  /// - notify: 特别关注，发帖时收到通知
  /// - reblogs: 控制是否在时间线显示转发
  ///
  /// API 路径：`/api/v1/accounts/:id/follow`
  /// HTTP 方法：POST
  case follow(id: String, notify: Bool, reblogs: Bool)
  
  /// 取消关注账户
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 返回：Relationship 对象
  ///
  /// API 路径：`/api/v1/accounts/:id/unfollow`
  /// HTTP 方法：POST
  case unfollow(id: String)
  
  /// 获取共同关注的账户
  ///
  /// - Parameter withAccount: 账户 ID
  ///
  /// 返回：FamiliarFollowers 对象
  ///
  /// 功能：
  /// - 显示你和指定账户共同关注的人
  /// - 帮助发现相关账户
  /// - 建立社交联系
  ///
  /// API 路径：`/api/v1/accounts/familiar_followers`
  /// HTTP 方法：GET
  case familiarFollowers(withAccount: String)
  
  /// 获取推荐账户列表
  ///
  /// 返回：Account 数组
  ///
  /// 推荐来源：
  /// - 实例管理员推荐
  /// - 热门账户
  /// - 相似兴趣的账户
  ///
  /// API 路径：`/api/v1/suggestions`
  /// HTTP 方法：GET
  case suggestions
  
  /// 获取关注者列表
  ///
  /// - Parameters:
  ///   - id: 账户 ID
  ///   - maxId: 分页参数（可选）
  ///
  /// 返回：Account 数组（关注此账户的用户）
  ///
  /// API 路径：`/api/v1/accounts/:id/followers`
  /// HTTP 方法：GET
  case followers(id: String, maxId: String?)
  
  /// 获取正在关注列表
  ///
  /// - Parameters:
  ///   - id: 账户 ID
  ///   - maxId: 分页参数（可选）
  ///
  /// 返回：Account 数组（此账户关注的用户）
  ///
  /// API 路径：`/api/v1/accounts/:id/following`
  /// HTTP 方法：GET
  case following(id: String, maxId: String?)
  
  /// 获取账户所在的列表
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 返回：List 数组（包含此账户的列表）
  ///
  /// 使用场景：
  /// - 查看账户被添加到哪些列表
  /// - 管理列表成员
  ///
  /// API 路径：`/api/v1/accounts/:id/lists`
  /// HTTP 方法：GET
  case lists(id: String)
  
  /// 获取用户偏好设置
  ///
  /// 返回：Preferences 对象
  ///
  /// 偏好设置包括：
  /// - 默认可见性
  /// - 默认语言
  /// - 是否标记媒体为敏感
  /// - 其他默认设置
  ///
  /// API 路径：`/api/v1/preferences`
  /// HTTP 方法：GET
  case preferences
  
  /// 屏蔽账户
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 返回：Relationship 对象
  ///
  /// 屏蔽效果：
  /// - 看不到对方的帖子
  /// - 对方无法关注你
  /// - 对方无法看到你的帖子
  /// - 对方无法给你发私信
  ///
  /// API 路径：`/api/v1/accounts/:id/block`
  /// HTTP 方法：POST
  case block(id: String)
  
  /// 取消屏蔽账户
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 返回：Relationship 对象
  ///
  /// API 路径：`/api/v1/accounts/:id/unblock`
  /// HTTP 方法：POST
  case unblock(id: String)
  
  /// 静音账户
  ///
  /// - Parameters:
  ///   - id: 账户 ID
  ///   - json: 静音设置（持续时间）
  ///
  /// 返回：Relationship 对象
  ///
  /// 静音效果：
  /// - 不会在时间线看到对方的帖子
  /// - 仍然保持关注关系
  /// - 对方不知道被静音
  /// - 可以设置持续时间
  ///
  /// API 路径：`/api/v1/accounts/:id/mute`
  /// HTTP 方法：POST
  case mute(id: String, json: MuteData)
  
  /// 取消静音账户
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 返回：Relationship 对象
  ///
  /// API 路径：`/api/v1/accounts/:id/unmute`
  /// HTTP 方法：POST
  case unmute(id: String)
  
  /// 设置账户备注
  ///
  /// - Parameters:
  ///   - id: 账户 ID
  ///   - json: 备注数据
  ///
  /// 返回：Relationship 对象
  ///
  /// 备注功能：
  /// - 只有你自己能看到
  /// - 帮助记住用户身份
  /// - 可以是任何文本
  ///
  /// API 路径：`/api/v1/accounts/:id/note`
  /// HTTP 方法：POST
  case relationshipNote(id: String, json: RelationshipNoteData)
  
  /// 获取屏蔽列表
  ///
  /// 返回：Account 数组（你屏蔽的所有账户）
  ///
  /// API 路径：`/api/v1/blocks`
  /// HTTP 方法：GET
  case blockList
  
  /// 获取静音列表
  ///
  /// 返回：Account 数组（你静音的所有账户）
  ///
  /// API 路径：`/api/v1/mutes`
  /// HTTP 方法：GET
  case muteList

  public func path() -> String {
    switch self {
    case let .accounts(id):
      "accounts/\(id)"
    case .lookup:
      "accounts/lookup"
    case .favorites:
      "favourites"
    case .bookmarks:
      "bookmarks"
    case .followedTags:
      "followed_tags"
    case let .featuredTags(id):
      "accounts/\(id)/featured_tags"
    case .verifyCredentials:
      "accounts/verify_credentials"
    case .updateCredentials, .updateCredentialsMedia:
      "accounts/update_credentials"
    case let .statuses(id, _, _, _, _, _, _):
      "accounts/\(id)/statuses"
    case .relationships:
      "accounts/relationships"
    case let .follow(id, _, _):
      "accounts/\(id)/follow"
    case let .unfollow(id):
      "accounts/\(id)/unfollow"
    case .familiarFollowers:
      "accounts/familiar_followers"
    case .suggestions:
      "suggestions"
    case let .following(id, _):
      "accounts/\(id)/following"
    case let .followers(id, _):
      "accounts/\(id)/followers"
    case let .lists(id):
      "accounts/\(id)/lists"
    case .preferences:
      "preferences"
    case let .block(id):
      "accounts/\(id)/block"
    case let .unblock(id):
      "accounts/\(id)/unblock"
    case let .mute(id, _):
      "accounts/\(id)/mute"
    case let .unmute(id):
      "accounts/\(id)/unmute"
    case let .relationshipNote(id, _):
      "accounts/\(id)/note"
    case .blockList:
      "blocks"
    case .muteList:
      "mutes"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .lookup(name):
      return [
        .init(name: "acct", value: name)
      ]
    case let .statuses(_, sinceId, tag, onlyMedia, excludeReplies, excludeReblogs, pinned):
      var params: [URLQueryItem] = []
      if let tag {
        params.append(.init(name: "tagged", value: tag))
      }
      if let sinceId {
        params.append(.init(name: "max_id", value: sinceId))
      }

      params.append(.init(name: "only_media", value: onlyMedia ? "true" : "false"))
      params.append(.init(name: "exclude_replies", value: excludeReplies ? "true" : "false"))
      params.append(.init(name: "exclude_reblogs", value: excludeReblogs ? "true" : "false"))

      if let pinned {
        params.append(.init(name: "pinned", value: pinned ? "true" : "false"))
      }
      return params
    case let .relationships(ids):
      return ids.map {
        URLQueryItem(name: "id[]", value: $0)
      }
    case let .follow(_, notify, reblogs):
      return [
        .init(name: "notify", value: notify ? "true" : "false"),
        .init(name: "reblogs", value: reblogs ? "true" : "false"),
      ]
    case let .familiarFollowers(withAccount):
      return [.init(name: "id[]", value: withAccount)]
    case let .followers(_, maxId):
      return makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil)
    case let .following(_, maxId):
      return makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil)
    case let .favorites(sinceId):
      guard let sinceId else { return nil }
      return [.init(name: "max_id", value: sinceId)]
    case let .bookmarks(sinceId):
      guard let sinceId else { return nil }
      return [.init(name: "max_id", value: sinceId)]
    default:
      return nil
    }
  }

  public var jsonValue: Encodable? {
    switch self {
    case let .mute(_, json):
      json
    case let .relationshipNote(_, json):
      json
    case let .updateCredentials(json):
      json
    default:
      nil
    }
  }
}

/// 静音设置数据
///
/// 用于设置静音的持续时间。
public struct MuteData: Encodable, Sendable {
  /// 静音持续时间（秒）
  ///
  /// 常用值：
  /// - 0: 永久静音
  /// - 300: 5 分钟
  /// - 1800: 30 分钟
  /// - 3600: 1 小时
  /// - 21600: 6 小时
  /// - 86400: 1 天
  /// - 604800: 7 天
  ///
  /// 使用示例：
  /// ```swift
  /// // 静音 24 小时
  /// let muteData = MuteData(duration: 86400)
  ///
  /// // 永久静音
  /// let permanentMute = MuteData(duration: 0)
  /// ```
  public let duration: Int

  public init(duration: Int) {
    self.duration = duration
  }
}

/// 关系备注数据
///
/// 用于为账户设置私人备注。
public struct RelationshipNoteData: Encodable, Sendable {
  /// 备注内容
  ///
  /// 备注特性：
  /// - 只有你自己能看到
  /// - 帮助记住用户身份或特点
  /// - 可以是任何文本
  /// - 最多 2000 个字符
  ///
  /// 使用示例：
  /// ```swift
  /// let note = RelationshipNoteData(note: "同事 - 产品经理")
  /// ```
  public let comment: String

  public init(note comment: String) {
    self.comment = comment
  }
}

/// 账户信息更新数据
///
/// 用于更新当前用户的个人资料。
///
/// 使用示例：
/// ```swift
/// let updateData = UpdateCredentialsData(
///     displayName: "新名称",
///     note: "这是我的新简介",
///     source: .init(
///         privacy: .public,
///         sensitive: false
///     ),
///     bot: false,
///     locked: false,
///     discoverable: true,
///     fieldsAttributes: [
///         .init(name: "网站", value: "https://example.com"),
///         .init(name: "位置", value: "北京")
///     ]
/// )
///
/// let updatedAccount: Account = try await client.patch(
///     endpoint: Accounts.updateCredentials(json: updateData)
/// )
/// ```
public struct UpdateCredentialsData: Encodable, Sendable {
  /// 来源数据（隐私设置）
  ///
  /// 定义新帖子的默认设置。
  public struct SourceData: Encodable, Sendable {
    /// 默认可见性
    ///
    /// 新帖子的默认可见性级别：
    /// - .public: 公开
    /// - .unlisted: 不列出
    /// - .private: 仅关注者
    /// - .direct: 私信
    public let privacy: Visibility
    
    /// 默认标记媒体为敏感
    ///
    /// - true: 新帖子的媒体默认标记为敏感
    /// - false: 媒体不默认标记为敏感
    public let sensitive: Bool

    public init(privacy: Visibility, sensitive: Bool) {
      self.privacy = privacy
      self.sensitive = sensitive
    }
  }

  /// 个人资料字段数据
  ///
  /// 用于在个人资料中显示自定义字段。
  public struct FieldData: Encodable, Sendable {
    /// 字段名称
    ///
    /// 示例：
    /// - "网站"
    /// - "位置"
    /// - "职业"
    /// - "代词"
    public let name: String
    
    /// 字段值
    ///
    /// 可以包含链接，会自动验证。
    ///
    /// 示例：
    /// - "https://example.com"
    /// - "北京"
    /// - "iOS 开发者"
    /// - "they/them"
    public let value: String

    public init(name: String, value: String) {
      self.name = name
      self.value = value
    }
  }

  /// 显示名称
  ///
  /// 在个人资料和帖子中显示的名称。
  ///
  /// 限制：
  /// - 最多 30 个字符
  /// - 可以包含 emoji
  /// - 可以为空（使用用户名）
  public let displayName: String
  
  /// 个人简介
  ///
  /// 在个人资料中显示的简介。
  ///
  /// 限制：
  /// - 最多 500 个字符
  /// - 支持 Markdown 或 HTML
  /// - 可以包含链接和标签
  public let note: String
  
  /// 来源设置（隐私默认值）
  ///
  /// 定义新帖子的默认可见性和敏感媒体设置。
  public let source: SourceData
  
  /// 是否为机器人账户
  ///
  /// - true: 标记为机器人（会显示机器人图标）
  /// - false: 普通账户
  ///
  /// 机器人账户：
  /// - 自动化账户
  /// - RSS 订阅机器人
  /// - 新闻推送账户
  public let bot: Bool
  
  /// 是否锁定账户
  ///
  /// - true: 锁定账户（需要批准关注请求）
  /// - false: 开放账户（自动接受关注）
  ///
  /// 锁定账户特点：
  /// - 关注请求需要手动批准
  /// - 更好的隐私控制
  /// - 适合私人账户
  public let locked: Bool
  
  /// 是否可被发现
  ///
  /// - true: 账户可以出现在推荐和搜索中
  /// - false: 账户不会被推荐
  ///
  /// 影响：
  /// - 是否出现在推荐列表
  /// - 是否出现在目录中
  /// - 搜索可见性
  public let discoverable: Bool
  
  /// 个人资料字段
  ///
  /// 最多 4 个自定义字段。
  ///
  /// 字段用途：
  /// - 显示额外信息
  /// - 链接验证（绿色勾号）
  /// - 社交媒体链接
  /// - 联系方式
  ///
  /// 示例：
  /// ```
  /// 网站: https://example.com ✓
  /// 位置: 北京
  /// GitHub: https://github.com/username ✓
  /// ```
  public let fieldsAttributes: [String: FieldData]

  public init(
    displayName: String,
    note: String,
    source: UpdateCredentialsData.SourceData,
    bot: Bool,
    locked: Bool,
    discoverable: Bool,
    fieldsAttributes: [FieldData]
  ) {
    self.displayName = displayName
    self.note = note
    self.source = source
    self.bot = bot
    self.locked = locked
    self.discoverable = discoverable

    // 将字段数组转换为字典（API 要求的格式）
    var fieldAttributes: [String: FieldData] = [:]
    for (index, field) in fieldsAttributes.enumerated() {
      fieldAttributes[String(index)] = field
    }
    self.fieldsAttributes = fieldAttributes
  }
}
