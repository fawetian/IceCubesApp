// 文件功能：Mastodon 帖子（Status）相关 API 端点定义
//
// 核心职责：
// - 定义所有帖子相关的 API 端点
// - 支持帖子的创建、编辑、删除
// - 支持帖子的交互（点赞、转发、书签等）
// - 支持帖子的查询（上下文、历史、翻译等）
// - 提供帖子数据的结构定义
//
// 技术要点：
// - Statuses：枚举类型，每个 case 代表一个帖子操作
// - StatusData：帖子数据结构，用于创建和编辑帖子
// - PollData：投票数据结构
// - MediaAttribute：媒体属性（描述、焦点等）
// - 符合 Endpoint 协议：提供 path()、queryItems()、jsonValue
//
// 帖子操作类型：
// - 创建和编辑：postStatus, editStatus
// - 查询：status, context, history
// - 交互：favorite, reblog, bookmark, pin
// - 社交：rebloggedBy, favoritedBy, quotesBy
// - 其他：translate, report
//
// 依赖关系：
// - 依赖：Foundation, Models
// - 被依赖：StatusEditor, StatusRowView, MastodonClient

import Foundation
import Models

/// Mastodon 帖子 API 端点
///
/// 定义了所有与帖子相关的操作。
///
/// 主要功能：
/// - **创建和编辑**：发布新帖子、编辑已有帖子
/// - **查询**：获取帖子详情、上下文、编辑历史
/// - **交互**：点赞、转发、书签、置顶
/// - **社交**：查看谁点赞/转发/引用了帖子
/// - **其他**：翻译帖子、举报帖子
///
/// 使用示例：
/// ```swift
/// // 发布新帖子
/// let newStatus: Status = try await client.post(
///     endpoint: Statuses.postStatus(
///         json: StatusData(
///             status: "Hello Mastodon!",
///             visibility: .public
///         )
///     )
/// )
///
/// // 点赞帖子
/// let favoritedStatus: Status = try await client.post(
///     endpoint: Statuses.favorite(id: "123456")
/// )
///
/// // 转发帖子
/// let rebloggedStatus: Status = try await client.post(
///     endpoint: Statuses.reblog(id: "123456")
/// )
///
/// // 获取帖子上下文（回复链）
/// let context: StatusContext = try await client.get(
///     endpoint: Statuses.context(id: "123456")
/// )
///
/// // 翻译帖子
/// let translation: Translation = try await client.post(
///     endpoint: Statuses.translate(id: "123456", lang: "zh")
/// )
/// ```
///
/// - Note: 大多数操作需要认证
/// - SeeAlso: `StatusData` 用于创建和编辑帖子
public enum Statuses: Endpoint {
  /// 发布新帖子
  ///
  /// - Parameter json: 帖子数据（内容、可见性、媒体等）
  ///
  /// 使用场景：
  /// - 发布文字帖子
  /// - 发布带图片/视频的帖子
  /// - 发布投票
  /// - 回复其他帖子
  /// - 引用其他帖子
  ///
  /// API 路径：`/api/v1/statuses`
  /// HTTP 方法：POST
  case postStatus(json: StatusData)
  
  /// 编辑已有帖子
  ///
  /// - Parameters:
  ///   - id: 帖子 ID
  ///   - json: 更新后的帖子数据
  ///
  /// 编辑限制：
  /// - 只能编辑自己的帖子
  /// - 编辑会保留历史记录
  /// - 媒体附件可以更新描述
  ///
  /// API 路径：`/api/v1/statuses/:id`
  /// HTTP 方法：PUT
  case editStatus(id: String, json: StatusData)
  
  /// 获取帖子详情
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：完整的帖子对象
  ///
  /// API 路径：`/api/v1/statuses/:id`
  /// HTTP 方法：GET
  case status(id: String)
  
  /// 获取帖子上下文（回复链）
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：StatusContext 对象，包含：
  /// - ancestors: 祖先帖子（这条帖子回复的帖子链）
  /// - descendants: 后代帖子（回复这条帖子的帖子链）
  ///
  /// 使用场景：
  /// - 显示完整的对话线程
  /// - 查看帖子的上下文
  ///
  /// API 路径：`/api/v1/statuses/:id/context`
  /// HTTP 方法：GET
  case context(id: String)
  
  /// 点赞帖子
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：更新后的帖子对象（favourited = true）
  ///
  /// API 路径：`/api/v1/statuses/:id/favourite`
  /// HTTP 方法：POST
  case favorite(id: String)
  
  /// 取消点赞
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：更新后的帖子对象（favourited = false）
  ///
  /// API 路径：`/api/v1/statuses/:id/unfavourite`
  /// HTTP 方法：POST
  case unfavorite(id: String)
  
  /// 转发帖子
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：转发后的帖子对象（reblog 字段包含原帖子）
  ///
  /// 转发特点：
  /// - 转发会出现在你的个人资料和关注者的时间线
  /// - 原作者会收到通知
  /// - 可以取消转发
  ///
  /// API 路径：`/api/v1/statuses/:id/reblog`
  /// HTTP 方法：POST
  case reblog(id: String)
  
  /// 取消转发
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：更新后的帖子对象（reblogged = false）
  ///
  /// API 路径：`/api/v1/statuses/:id/unreblog`
  /// HTTP 方法：POST
  case unreblog(id: String)
  
  /// 获取转发此帖子的用户列表
  ///
  /// - Parameters:
  ///   - id: 帖子 ID
  ///   - maxId: 分页参数（可选）
  ///
  /// 返回：Account 数组
  ///
  /// API 路径：`/api/v1/statuses/:id/reblogged_by`
  /// HTTP 方法：GET
  case rebloggedBy(id: String, maxId: String?)
  
  /// 获取点赞此帖子的用户列表
  ///
  /// - Parameters:
  ///   - id: 帖子 ID
  ///   - maxId: 分页参数（可选）
  ///
  /// 返回：Account 数组
  ///
  /// API 路径：`/api/v1/statuses/:id/favourited_by`
  /// HTTP 方法：GET
  case favoritedBy(id: String, maxId: String?)
  
  /// 获取引用此帖子的帖子列表
  ///
  /// - Parameters:
  ///   - id: 帖子 ID
  ///   - maxId: 分页参数（可选）
  ///
  /// 返回：Status 数组
  ///
  /// 引用功能：
  /// - 类似 Twitter 的引用转发
  /// - 可以在转发时添加自己的评论
  ///
  /// API 路径：`/api/v1/statuses/:id/quotes`
  /// HTTP 方法：GET
  case quotesBy(id: String, maxId: String?)
  
  /// 置顶帖子到个人资料
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：更新后的帖子对象（pinned = true）
  ///
  /// 置顶限制：
  /// - 只能置顶自己的帖子
  /// - 最多可以置顶 5 条帖子
  /// - 置顶的帖子会显示在个人资料顶部
  ///
  /// API 路径：`/api/v1/statuses/:id/pin`
  /// HTTP 方法：POST
  case pin(id: String)
  
  /// 取消置顶
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：更新后的帖子对象（pinned = false）
  ///
  /// API 路径：`/api/v1/statuses/:id/unpin`
  /// HTTP 方法：POST
  case unpin(id: String)
  
  /// 添加书签
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：更新后的帖子对象（bookmarked = true）
  ///
  /// 书签功能：
  /// - 私密保存帖子（只有自己能看到）
  /// - 可以在书签页面查看所有书签
  /// - 不会通知原作者
  ///
  /// API 路径：`/api/v1/statuses/:id/bookmark`
  /// HTTP 方法：POST
  case bookmark(id: String)
  
  /// 取消书签
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：更新后的帖子对象（bookmarked = false）
  ///
  /// API 路径：`/api/v1/statuses/:id/unbookmark`
  /// HTTP 方法：POST
  case unbookmark(id: String)
  
  /// 获取帖子的编辑历史
  ///
  /// - Parameter id: 帖子 ID
  ///
  /// 返回：StatusHistory 数组，包含所有编辑版本
  ///
  /// 历史记录包含：
  /// - 每次编辑的内容
  /// - 编辑时间
  /// - 媒体附件的变化
  ///
  /// API 路径：`/api/v1/statuses/:id/history`
  /// HTTP 方法：GET
  case history(id: String)
  
  /// 翻译帖子
  ///
  /// - Parameters:
  ///   - id: 帖子 ID
  ///   - lang: 目标语言代码（可选，默认使用用户的语言设置）
  ///
  /// 返回：Translation 对象
  ///
  /// 翻译功能：
  /// - 使用实例配置的翻译服务（如 DeepL、LibreTranslate）
  /// - 翻译内容和内容警告
  /// - 保留原文
  ///
  /// 语言代码示例：
  /// - "zh": 中文
  /// - "en": 英语
  /// - "ja": 日语
  /// - "ko": 韩语
  ///
  /// API 路径：`/api/v1/statuses/:id/translate`
  /// HTTP 方法：POST
  case translate(id: String, lang: String?)
  
  /// 举报帖子
  ///
  /// - Parameters:
  ///   - accountId: 被举报账户的 ID
  ///   - statusId: 被举报帖子的 ID
  ///   - comment: 举报说明
  ///
  /// 返回：Report 对象
  ///
  /// 举报流程：
  /// 1. 用户提交举报
  /// 2. 实例管理员收到举报
  /// 3. 管理员审核并采取行动
  ///
  /// API 路径：`/api/v1/reports`
  /// HTTP 方法：POST
  case report(accountId: String, statusId: String, comment: String)

  public func path() -> String {
    switch self {
    case .postStatus:
      "statuses"
    case .status(let id):
      "statuses/\(id)"
    case .editStatus(let id, _):
      "statuses/\(id)"
    case .context(let id):
      "statuses/\(id)/context"
    case .favorite(let id):
      "statuses/\(id)/favourite"
    case .unfavorite(let id):
      "statuses/\(id)/unfavourite"
    case .reblog(let id):
      "statuses/\(id)/reblog"
    case .unreblog(let id):
      "statuses/\(id)/unreblog"
    case .rebloggedBy(let id, _):
      "statuses/\(id)/reblogged_by"
    case .favoritedBy(let id, _):
      "statuses/\(id)/favourited_by"
    case .quotesBy(let id, _):
      "statuses/\(id)/quotes"
    case .pin(let id):
      "statuses/\(id)/pin"
    case .unpin(let id):
      "statuses/\(id)/unpin"
    case .bookmark(let id):
      "statuses/\(id)/bookmark"
    case .unbookmark(let id):
      "statuses/\(id)/unbookmark"
    case .history(let id):
      "statuses/\(id)/history"
    case .translate(let id, _):
      "statuses/\(id)/translate"
    case .report:
      "reports"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case .rebloggedBy(_, let maxId):
      return makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil)
    case .favoritedBy(_, let maxId):
      return makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil)
    case .quotesBy(_, let maxId):
      return makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil)
    case .translate(_, let lang):
      if let lang {
        return [.init(name: "lang", value: lang)]
      }
      return nil
    case .report(let accountId, let statusId, let comment):
      return [
        .init(name: "account_id", value: accountId),
        .init(name: "status_ids[]", value: statusId),
        .init(name: "comment", value: comment),
      ]
    default:
      return nil
    }
  }

  public var jsonValue: Encodable? {
    switch self {
    case .postStatus(let json):
      json
    case .editStatus(_, let json):
      json
    default:
      nil
    }
  }
}

/// 帖子数据结构
///
/// 用于创建和编辑帖子时提交的数据。
///
/// 使用示例：
/// ```swift
/// // 简单的文字帖子
/// let simplePost = StatusData(
///     status: "Hello Mastodon!",
///     visibility: .public
/// )
///
/// // 带图片的帖子
/// let photoPost = StatusData(
///     status: "看看我的照片！",
///     visibility: .public,
///     mediaIds: ["123456"]
/// )
///
/// // 回复帖子
/// let reply = StatusData(
///     status: "@user 我同意你的观点",
///     visibility: .public,
///     inReplyToId: "789012"
/// )
///
/// // 带投票的帖子
/// let pollPost = StatusData(
///     status: "你最喜欢哪个编程语言？",
///     visibility: .public,
///     poll: StatusData.PollData(
///         options: ["Swift", "Kotlin", "Rust"],
///         multiple: false,
///         expires_in: 86400  // 24 小时
///     )
/// )
///
/// // 带内容警告的帖子
/// let cwPost = StatusData(
///     status: "这是敏感内容...",
///     visibility: .public,
///     spoilerText: "内容警告：剧透"
/// )
/// ```
public struct StatusData: Encodable, Sendable {
  /// 帖子内容（纯文本或 HTML）
  ///
  /// 内容限制：
  /// - 最大长度由实例配置决定（通常是 500 字符）
  /// - 支持 Markdown 或 HTML（取决于实例设置）
  /// - 可以包含提及（@username）和标签（#hashtag）
  /// - 可以包含链接
  public let status: String
  
  /// 可见性级别
  ///
  /// 可选值：
  /// - .public: 公开（所有人可见，出现在公共时间线）
  /// - .unlisted: 不列出（所有人可见，但不出现在公共时间线）
  /// - .private: 仅关注者（只有关注者可见）
  /// - .direct: 私信（只有被提及的用户可见）
  public let visibility: Visibility
  
  /// 回复的帖子 ID（可选）
  ///
  /// 如果设置，这条帖子将作为回复显示。
  ///
  /// 回复特点：
  /// - 会显示在原帖子的回复列表中
  /// - 原作者会收到通知
  /// - 可见性不能高于原帖子
  public let inReplyToId: String?
  
  /// 内容警告文本（可选）
  ///
  /// 如果设置，帖子内容会被折叠，显示警告文本。
  ///
  /// 使用场景：
  /// - 剧透内容
  /// - 敏感话题
  /// - 长篇内容
  /// - 政治讨论
  ///
  /// 示例：
  /// - "剧透警告"
  /// - "政治讨论"
  /// - "长文"
  public let spoilerText: String?
  
  /// 媒体附件 ID 数组（可选）
  ///
  /// 媒体必须先通过 Media API 上传，获得 ID 后再关联到帖子。
  ///
  /// 限制：
  /// - 最多 4 个附件
  /// - 图片和视频不能混合
  /// - 每个附件的大小限制由实例配置决定
  ///
  /// 使用流程：
  /// 1. 上传媒体文件，获得 MediaAttachment 对象
  /// 2. 提取 MediaAttachment.id
  /// 3. 将 ID 添加到 mediaIds 数组
  /// 4. 发布帖子
  public let mediaIds: [String]?
  
  /// 投票数据（可选）
  ///
  /// 如果设置，帖子将包含一个投票。
  ///
  /// 限制：
  /// - 不能同时有媒体附件和投票
  /// - 投票选项数量限制（通常 2-4 个）
  public let poll: PollData?
  
  /// 帖子语言代码（可选）
  ///
  /// ISO 639-1 语言代码。
  ///
  /// 示例：
  /// - "zh": 中文
  /// - "en": 英语
  /// - "ja": 日语
  ///
  /// 用途：
  /// - 帮助用户过滤语言
  /// - 改进翻译功能
  public let language: String?
  
  /// 媒体属性（可选）
  ///
  /// 用于更新媒体附件的描述、缩略图和焦点。
  ///
  /// 使用场景：
  /// - 添加 Alt Text（无障碍访问）
  /// - 设置图片焦点（裁剪时保留重要部分）
  /// - 更新缩略图
  public let mediaAttributes: [MediaAttribute]?
  
  /// 引用的帖子 ID（可选）
  ///
  /// 如果设置，这条帖子将引用另一条帖子。
  ///
  /// 引用功能：
  /// - 类似 Twitter 的引用转发
  /// - 可以添加自己的评论
  /// - 原帖子会嵌入显示
  public let quotedStatusId: String?

  /// 投票数据结构
  ///
  /// 定义投票的选项、类型和过期时间。
  public struct PollData: Encodable, Sendable {
    /// 投票选项数组
    ///
    /// 限制：
    /// - 至少 2 个选项
    /// - 最多 4 个选项（通常）
    /// - 每个选项最多 50 个字符
    public let options: [String]
    
    /// 是否允许多选
    ///
    /// - true: 用户可以选择多个选项
    /// - false: 用户只能选择一个选项
    public let multiple: Bool
    
    /// 投票过期时间（秒）
    ///
    /// 常用值：
    /// - 300: 5 分钟
    /// - 1800: 30 分钟
    /// - 3600: 1 小时
    /// - 21600: 6 小时
    /// - 86400: 1 天
    /// - 259200: 3 天
    /// - 604800: 7 天
    public let expires_in: Int

    public init(options: [String], multiple: Bool, expires_in: Int) {
      self.options = options
      self.multiple = multiple
      self.expires_in = expires_in
    }
  }

  /// 媒体属性结构
  ///
  /// 用于更新媒体附件的元数据。
  public struct MediaAttribute: Encodable, Sendable {
    /// 媒体附件 ID
    public let id: String
    
    /// 媒体描述（Alt Text）
    ///
    /// 用于无障碍访问，描述图片内容。
    ///
    /// 最佳实践：
    /// - 简洁描述图片内容
    /// - 不要以"图片显示..."开头
    /// - 包含重要的文字信息
    /// - 最多 1500 个字符
    ///
    /// 示例：
    /// - "一只橙色的猫坐在窗台上"
    /// - "代码截图：Swift 函数定义"
    public let description: String?
    
    /// 缩略图（可选）
    ///
    /// 用于视频的封面图。
    public let thumbnail: String?
    
    /// 焦点坐标（可选）
    ///
    /// 格式："x,y"，范围 -1.0 到 1.0
    ///
    /// 用途：
    /// - 指定图片的重要区域
    /// - 裁剪时保留焦点区域
    ///
    /// 示例：
    /// - "0,0": 中心
    /// - "-1,1": 左上角
    /// - "1,-1": 右下角
    public let focus: String?

    public init(id: String, description: String?, thumbnail: String?, focus: String?) {
      self.id = id
      self.description = description
      self.thumbnail = thumbnail
      self.focus = focus
    }
  }

  public init(
    status: String,
    visibility: Visibility,
    inReplyToId: String? = nil,
    spoilerText: String? = nil,
    mediaIds: [String]? = nil,
    poll: PollData? = nil,
    language: String? = nil,
    mediaAttributes: [MediaAttribute]? = nil,
    quotedStatusId: String? = nil
  ) {
    self.status = status
    self.visibility = visibility
    self.inReplyToId = inReplyToId
    self.spoilerText = spoilerText
    self.mediaIds = mediaIds
    self.poll = poll
    self.language = language
    self.mediaAttributes = mediaAttributes
    self.quotedStatusId = quotedStatusId
  }
}
