// 文件功能：Mastodon 链接卡片数据模型
//
// 核心职责：
// - 表示帖子中的链接预览卡片
// - 包含链接的标题、描述、图片等元数据
// - 支持不同类型的卡片（链接、视频、照片）
// - 显示作者和来源信息
//
// 技术要点：
// - Card：链接卡片的完整信息
// - CardAuthor：卡片作者信息（可能关联 Mastodon 账户）
// - type：卡片类型（link, photo, video, rich）
// - Open Graph：基于 Open Graph 协议的元数据
//
// 卡片类型：
// - link：普通链接卡片（最常见）
// - photo：图片卡片
// - video：视频卡片（如 YouTube）
// - rich：富媒体卡片（如嵌入式播放器）
//
// 依赖关系：
// - 依赖：Account, History
// - 被依赖：Status, StatusRowView

import Foundation

/// Mastodon 链接卡片数据模型
///
/// 表示帖子中的链接预览卡片，类似于 Twitter 的链接卡片。
///
/// 卡片特性：
/// - 自动从链接提取元数据（Open Graph）
/// - 显示标题、描述、预览图
/// - 显示来源网站和作者
/// - 支持不同类型的内容（链接、图片、视频）
///
/// 工作原理：
/// 1. 用户在帖子中发布链接
/// 2. Mastodon 服务器抓取链接的元数据
/// 3. 生成卡片并附加到帖子
/// 4. 客户端显示卡片预览
///
/// 使用示例：
/// ```swift
/// if let card = status.card {
///     VStack(alignment: .leading) {
///         if let image = card.image {
///             AsyncImage(url: image)
///         }
///         Text(card.title ?? "")
///             .font(.headline)
///         Text(card.description ?? "")
///             .font(.caption)
///         Text(card.providerName ?? "")
///             .font(.caption2)
///     }
/// }
/// ```
public struct Card: Codable, Identifiable, Equatable, Hashable {
  /// 卡片的唯一标识符
  ///
  /// 使用 URL 作为 ID，因为同一个链接的卡片应该是相同的。
  public var id: String {
    url
  }

  /// 卡片作者信息
  ///
  /// 表示内容的作者，可能关联到 Mastodon 账户。
  ///
  /// 使用场景：
  /// - 显示文章作者
  /// - 如果作者有 Mastodon 账户，可以点击查看
  /// - 显示作者的个人网站
  ///
  /// 示例：
  /// - 博客文章：作者名称和博客链接
  /// - 新闻文章：记者名称和个人主页
  /// - 如果作者在 Mastodon 上，account 字段包含其账户信息
  public struct CardAuthor: Codable, Sendable, Identifiable, Equatable, Hashable {
    /// 作者的唯一标识符
    ///
    /// 使用作者 URL 作为 ID
    public var id: String {
      url
    }

    /// 作者名称
    ///
    /// 例如："张三"、"John Doe"
    public let name: String
    
    /// 作者的个人网站或主页 URL
    public let url: String
    
    /// 作者的 Mastodon 账户（如果有）
    ///
    /// 如果作者在 Mastodon 上，这里包含其账户信息。
    ///
    /// 用途：
    /// - 点击作者名称跳转到其 Mastodon 个人资料
    /// - 显示作者的头像
    /// - 关注作者
    ///
    /// - Note: 大多数情况下为 nil，因为不是所有作者都在 Mastodon 上
    public let account: Account?
  }

  // MARK: - 基本信息
  
  /// 链接的 URL
  ///
  /// 卡片指向的完整 URL。
  ///
  /// 用途：
  /// - 点击卡片时打开此链接
  /// - 作为卡片的唯一标识符
  public let url: String
  
  /// 链接的标题
  ///
  /// 从网页的 `<title>` 或 Open Graph `og:title` 提取。
  ///
  /// 示例：
  /// - "SwiftUI 教程：构建你的第一个应用"
  /// - "Mastodon 4.0 发布公告"
  ///
  /// - Note: 某些网页可能没有标题，此时为 nil
  public let title: String?
  
  /// 作者名称
  ///
  /// 从网页元数据中提取的作者名称。
  ///
  /// 来源：
  /// - Open Graph `article:author`
  /// - HTML `<meta name="author">`
  ///
  /// - Note: 不是所有网页都有作者信息
  public let authorName: String?
  
  /// 链接的描述
  ///
  /// 从网页的描述元数据提取。
  ///
  /// 来源：
  /// - Open Graph `og:description`
  /// - HTML `<meta name="description">`
  ///
  /// 用途：
  /// - 显示链接的简短摘要
  /// - 帮助用户决定是否点击
  ///
  /// - Note: 通常限制在 200-300 字符
  public let description: String?
  
  /// 来源网站名称
  ///
  /// 链接所属的网站或服务名称。
  ///
  /// 示例：
  /// - "YouTube"
  /// - "GitHub"
  /// - "个人博客"
  ///
  /// 来源：
  /// - Open Graph `og:site_name`
  /// - 域名
  ///
  /// 用途：
  /// - 显示内容来源
  /// - 帮助用户识别网站
  public let providerName: String?
  
  /// 卡片类型
  ///
  /// 定义卡片的显示方式和交互行为。
  ///
  /// 类型说明：
  /// - "link": 普通链接卡片（最常见）
  /// - "photo": 图片卡片（主要内容是图片）
  /// - "video": 视频卡片（如 YouTube、Vimeo）
  /// - "rich": 富媒体卡片（嵌入式内容）
  ///
  /// UI 差异：
  /// - link: 显示标题、描述、小图
  /// - photo: 大图显示
  /// - video: 显示播放按钮
  /// - rich: 可能包含嵌入式播放器
  public let type: String
  
  // MARK: - 媒体信息
  
  /// 预览图片的 URL
  ///
  /// 卡片的预览图片，通常是网页的特色图片。
  ///
  /// 来源：
  /// - Open Graph `og:image`
  /// - Twitter Card `twitter:image`
  /// - 网页的第一张图片
  ///
  /// 用途：
  /// - 显示链接的视觉预览
  /// - 吸引用户点击
  /// - 提供内容的视觉线索
  ///
  /// - Note: 某些网页可能没有图片
  public let image: URL?
  
  /// 预览图片的宽度
  ///
  /// 用于计算图片的宽高比和布局。
  ///
  /// - Note: 如果网页未提供，可能为 nil
  public let width: CGFloat?
  
  /// 预览图片的高度
  ///
  /// 用于计算图片的宽高比和布局。
  ///
  /// - Note: 如果网页未提供，可能为 nil
  public let height: CGFloat?
  
  // MARK: - 额外信息
  
  /// 链接的历史使用数据
  ///
  /// 如果这是一个热门链接，包含其使用历史。
  ///
  /// 用途：
  /// - 显示链接的热度
  /// - 判断链接是否值得关注
  /// - 在"热门链接"页面显示趋势
  ///
  /// - Note: 只有在特定 API 端点（如趋势链接）才会返回
  public let history: [History]?
  
  /// 作者列表
  ///
  /// 内容的作者信息，可能有多个作者。
  ///
  /// 使用场景：
  /// - 显示文章的所有作者
  /// - 如果作者在 Mastodon 上，可以点击查看
  /// - 显示作者的个人网站
  ///
  /// - Note: 大多数情况下为 nil 或只有一个作者
  public let authors: [CardAuthor]?
}

// MARK: - Sendable 一致性

/// Card 符合 Sendable 协议
///
/// 所有属性都是不可变的，可以安全地在并发上下文中使用
extension Card: Sendable {}
