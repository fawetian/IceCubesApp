// 文件功能：Mastodon 媒体 API 端点定义
//
// 核心职责：
// - 定义媒体上传和更新的 API 端点
// - 支持媒体描述（Alt Text）的更新
// - 提供媒体数据的结构定义
//
// 技术要点：
// - Media：枚举类型，定义媒体相关操作
// - MediaDescriptionData：媒体描述数据结构
// - 使用 multipart/form-data 上传媒体文件
// - 符合 Endpoint 协议
//
// 媒体操作类型：
// - medias：上传新媒体文件
// - media：更新已上传媒体的描述
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：StatusEditor, MastodonClient

import Foundation

/// Mastodon 媒体 API 端点
///
/// 定义了媒体文件的上传和更新操作。
///
/// 主要功能：
/// - **上传媒体**：上传图片、视频、音频文件
/// - **更新描述**：为已上传的媒体添加或更新 Alt Text
///
/// 媒体上传流程：
/// 1. 使用 `medias` 端点上传文件
/// 2. 获得 MediaAttachment 对象（包含 ID）
/// 3. （可选）使用 `media` 端点更新描述
/// 4. 在发布帖子时使用媒体 ID
///
/// 使用示例：
/// ```swift
/// // 1. 上传图片
/// let imageData = UIImage(named: "photo")!.jpegData(compressionQuality: 0.8)!
/// let attachment: MediaAttachment = try await client.mediaUpload(
///     endpoint: Media.medias,
///     version: .v2,
///     method: "POST",
///     mimeType: "image/jpeg",
///     filename: "photo.jpg",
///     data: imageData
/// )
///
/// // 2. 更新媒体描述（Alt Text）
/// let updatedAttachment: MediaAttachment = try await client.put(
///     endpoint: Media.media(
///         id: attachment.id,
///         json: MediaDescriptionData(
///             description: "一只橙色的猫坐在窗台上"
///         )
///     )
/// )
///
/// // 3. 使用媒体 ID 发布帖子
/// let status: Status = try await client.post(
///     endpoint: Statuses.postStatus(
///         json: StatusData(
///             status: "看看我的猫！",
///             visibility: .public,
///             mediaIds: [attachment.id]
///         )
///     )
/// )
/// ```
///
/// 支持的媒体类型：
/// - **图片**：JPEG, PNG, GIF, WebP
/// - **视频**：MP4, MOV, WebM
/// - **音频**：MP3, OGG, WAV, FLAC
///
/// 媒体限制（由实例配置决定）：
/// - 图片：通常最大 10MB
/// - 视频：通常最大 40MB
/// - 音频：通常最大 40MB
/// - 最多 4 个附件
///
/// - Note: 媒体上传使用 v2 API
/// - SeeAlso: `MediaDescriptionData` 用于更新媒体描述
public enum Media: Endpoint {
  /// 上传新媒体文件
  ///
  /// 使用 multipart/form-data 上传文件。
  ///
  /// 返回：MediaAttachment 对象（包含 ID 和 URL）
  ///
  /// 上传后的处理：
  /// - 服务器可能需要时间处理文件（特别是视频）
  /// - 可以通过 MediaAttachment.url 检查处理状态
  /// - 处理完成后才能在帖子中使用
  ///
  /// API 路径：`/api/v2/media`
  /// HTTP 方法：POST
  case medias
  
  /// 更新已上传媒体的描述
  ///
  /// - Parameters:
  ///   - id: 媒体附件 ID
  ///   - json: 媒体描述数据（可选）
  ///
  /// 返回：更新后的 MediaAttachment 对象
  ///
  /// 描述（Alt Text）的重要性：
  /// - 无障碍访问：帮助视障用户理解图片内容
  /// - SEO：改善搜索引擎优化
  /// - 上下文：当图片无法加载时提供信息
  ///
  /// 最佳实践：
  /// - 简洁描述图片内容
  /// - 不要以"图片显示..."开头
  /// - 包含重要的文字信息
  /// - 最多 1500 个字符
  ///
  /// API 路径：`/api/v1/media/:id`
  /// HTTP 方法：PUT
  case media(id: String, json: MediaDescriptionData?)

  public func path() -> String {
    switch self {
    case .medias:
      "media"
    case let .media(id, _):
      "media/\(id)"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    nil
  }

  public var jsonValue: Encodable? {
    switch self {
    case let .media(_, json):
      if let json {
        return json
      }
      return nil
    default:
      return nil
    }
  }
}

/// 媒体描述数据
///
/// 用于更新媒体附件的 Alt Text（替代文本）。
///
/// Alt Text 的作用：
/// - **无障碍访问**：屏幕阅读器会读出描述，帮助视障用户理解图片
/// - **上下文信息**：当图片无法加载时，显示描述文本
/// - **SEO 优化**：搜索引擎可以索引图片描述
///
/// 使用示例：
/// ```swift
/// // 为照片添加描述
/// let photoDesc = MediaDescriptionData(
///     description: "一只橙色的猫坐在窗台上，背景是蓝天"
/// )
///
/// // 为截图添加描述
/// let screenshotDesc = MediaDescriptionData(
///     description: "代码截图：Swift 函数定义，展示了 async/await 的使用"
/// )
///
/// // 为图表添加描述
/// let chartDesc = MediaDescriptionData(
///     description: "柱状图：2024 年各月销售额，12 月最高达 50 万"
/// )
/// ```
///
/// 最佳实践：
/// - ✅ 简洁明了："一只猫在睡觉"
/// - ❌ 避免冗余："这张图片显示了一只猫在睡觉"
/// - ✅ 包含重要信息："错误消息：找不到文件 config.json"
/// - ✅ 描述图表数据："折线图显示温度从 20°C 上升到 35°C"
///
/// - Note: 描述最多 1500 个字符
/// - Important: 为所有图片添加 Alt Text 是无障碍访问的最佳实践
public struct MediaDescriptionData: Encodable, Sendable {
  /// 媒体描述（Alt Text）
  ///
  /// 如果为 nil，将清除现有描述。
  public let description: String?

  public init(description: String?) {
    self.description = description
  }
}
