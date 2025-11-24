// 文件功能：Mastodon 媒体附件数据模型
//
// 核心职责：
// - 表示帖子中的媒体附件（图片、视频、音频、GIF）
// - 包含媒体的 URL、预览图、尺寸等元数据
// - 提供类型安全的媒体类型枚举
// - 支持无障碍访问的本地化描述
//
// 技术要点：
// - SupportedType：四种支持的媒体类型
// - MetaContainer：媒体元数据（尺寸、时长等）
// - description：图片描述（Alt Text），用于无障碍访问
// - previewUrl：缩略图 URL，用于列表显示
//
// 媒体类型说明：
// - image：静态图片（JPEG, PNG, WebP 等）
// - gifv：动画 GIF（实际上是无声视频）
// - video：视频文件（MP4, WebM 等）
// - audio：音频文件（MP3, OGG 等）
//
// 依赖关系：
// - 依赖：Foundation（URL, Codable）
// - 被依赖：Status, MediaStatus, MediaUI

import Foundation

/// Mastodon 媒体附件数据模型
///
/// 表示帖子中的媒体内容，包括：
/// - 图片：静态图片文件
/// - GIF：动画 GIF（实际存储为视频）
/// - 视频：视频文件
/// - 音频：音频文件
///
/// 每个帖子最多可以包含 4 个媒体附件。
///
/// 使用示例：
/// ```swift
/// for attachment in status.mediaAttachments {
///     switch attachment.supportedType {
///     case .image:
///         displayImage(url: attachment.url)
///     case .video, .gifv:
///         displayVideo(url: attachment.url)
///     case .audio:
///         displayAudioPlayer(url: attachment.url)
///     default:
///         break
///     }
/// }
/// ```
///
/// - Note: Mastodon 会自动生成预览图和多种尺寸的版本
public struct MediaAttachment: Codable, Identifiable, Hashable, Equatable {
  /// 媒体元数据容器
  ///
  /// 包含媒体的技术信息，如尺寸、时长、帧率等。
  ///
  /// 用途：
  /// - 在加载前确定图片尺寸，优化布局
  /// - 显示视频时长
  /// - 计算宽高比
  public struct MetaContainer: Codable, Equatable {
    /// 媒体元数据
    ///
    /// 包含媒体的基本尺寸信息。
    ///
    /// - Note: Mastodon 可能返回多个版本的元数据（original, small 等）
    public struct Meta: Codable, Equatable {
      /// 媒体宽度（像素）
      public let width: Int?
      
      /// 媒体高度（像素）
      public let height: Int?
    }

    /// 原始媒体的元数据
    ///
    /// 包含上传的原始文件的尺寸信息。
    /// Mastodon 还可能提供其他版本（如 small），但这里只保留 original。
    public let original: Meta?
  }

  /// 支持的媒体类型枚举
  ///
  /// 定义 Ice Cubes 支持的四种媒体类型。
  ///
  /// 类型说明：
  /// - image: 静态图片（JPEG, PNG, WebP 等）
  /// - gifv: 动画 GIF（Mastodon 将 GIF 转换为无声视频以节省空间）
  /// - video: 视频文件（MP4, WebM 等）
  /// - audio: 音频文件（MP3, OGG, FLAC 等）
  ///
  /// 为什么 GIF 叫 gifv？
  /// - Mastodon 将上传的 GIF 转换为视频格式
  /// - 视频格式文件更小，加载更快
  /// - 但在 UI 上仍然像 GIF 一样自动循环播放
  ///
  /// - Note: Mastodon 可能支持其他类型，但 Ice Cubes 只处理这四种
  public enum SupportedType: String {
    case image  // 图片
    case gifv   // 动画 GIF（实际是视频）
    case video  // 视频
    case audio  // 音频
  }

  /// 哈希值计算
  ///
  /// 只使用 ID 计算哈希，因为 ID 是唯一且不变的标识符
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // MARK: - 基本信息
  
  /// 媒体附件的唯一标识符
  public let id: String
  
  /// 媒体类型（字符串格式）
  ///
  /// 直接来自 API 的原始类型字符串。
  /// 使用 supportedType 获取类型安全的枚举值。
  public let type: String
  
  /// 类型安全的媒体类型
  ///
  /// 将字符串类型转换为枚举类型，提供类型安全。
  ///
  /// 返回值：
  /// - 如果 type 是已知类型，返回对应的枚举值
  /// - 如果 type 是未知类型，返回 nil
  ///
  /// 使用示例：
  /// ```swift
  /// if let type = attachment.supportedType {
  ///     switch type {
  ///     case .image:
  ///         loadImage()
  ///     case .video, .gifv:
  ///         loadVideo()
  ///     case .audio:
  ///         loadAudio()
  ///     }
  /// }
  /// ```
  public var supportedType: SupportedType? {
    SupportedType(rawValue: type)
  }

  /// 本地化的类型描述
  ///
  /// 返回媒体类型的本地化字符串，用于无障碍访问。
  ///
  /// 用途：
  /// - VoiceOver 会读出这个描述
  /// - 帮助视障用户理解媒体类型
  ///
  /// 返回值示例：
  /// - image: "图片"
  /// - video: "视频"
  /// - audio: "音频"
  /// - gifv: "动画"
  ///
  /// - Note: 如果类型未知，返回 nil
  public var localizedTypeDescription: String? {
    if let supportedType {
      switch supportedType {
      case .image:
        return NSLocalizedString(
          "accessibility.media.supported-type.image.label", bundle: .main,
          comment: "A localized description of SupportedType.image")
      case .gifv:
        return NSLocalizedString(
          "accessibility.media.supported-type.gifv.label", bundle: .main,
          comment: "A localized description of SupportedType.gifv")
      case .video:
        return NSLocalizedString(
          "accessibility.media.supported-type.video.label", bundle: .main,
          comment: "A localized description of SupportedType.video")
      case .audio:
        return NSLocalizedString(
          "accessibility.media.supported-type.audio.label", bundle: .main,
          comment: "A localized description of SupportedType.audio")
      }
    }
    return nil
  }

  // MARK: - 媒体资源
  
  /// 媒体文件的 URL
  ///
  /// 指向完整尺寸的媒体文件。
  ///
  /// 用途：
  /// - 点击预览图后加载完整媒体
  /// - 下载媒体文件
  /// - 在媒体查看器中显示
  ///
  /// - Note: 某些情况下可能为 nil（如媒体正在处理中）
  public let url: URL?
  
  /// 预览图的 URL
  ///
  /// 指向缩略图或预览图。
  ///
  /// 用途：
  /// - 在时间线中显示小图
  /// - 快速加载，节省流量
  /// - 视频的第一帧截图
  ///
  /// 尺寸：
  /// - 通常是原图的缩小版
  /// - Mastodon 自动生成多种尺寸
  /// - 适合列表显示
  public let previewUrl: URL?
  
  /// 媒体描述（Alt Text）
  ///
  /// 用户为媒体添加的文字描述。
  ///
  /// 用途：
  /// - 无障碍访问：VoiceOver 会读出这个描述
  /// - 图片加载失败时显示
  /// - 帮助视障用户理解图片内容
  /// - SEO 优化
  ///
  /// 最佳实践：
  /// - 发帖时应该为所有图片添加描述
  /// - Ice Cubes 支持 AI 自动生成图片描述
  /// - 某些实例要求必须添加描述才能发布
  ///
  /// - Note: 如果用户未添加描述，此值为 nil
  public let description: String?
  
  /// 媒体元数据
  ///
  /// 包含媒体的技术信息（尺寸、时长等）。
  ///
  /// 用途：
  /// - 在加载前计算布局
  /// - 显示视频时长
  /// - 优化图片加载策略
  public let meta: MetaContainer?

  // MARK: - 便捷构造方法
  
  /// 创建图片附件
  ///
  /// 用于测试和预览，快速创建一个图片附件。
  ///
  /// - Parameter url: 图片 URL
  /// - Returns: MediaAttachment 实例
  ///
  /// 使用场景：
  /// ```swift
  /// let attachment = MediaAttachment.imageWith(url: imageURL)
  /// ```
  public static func imageWith(url: URL) -> MediaAttachment {
    .init(
      id: UUID().uuidString,
      type: "image",
      url: url,
      previewUrl: url,
      description: nil,
      meta: nil)
  }

  /// 创建视频附件
  ///
  /// 用于测试和预览，快速创建一个视频附件。
  ///
  /// - Parameter url: 视频 URL
  /// - Returns: MediaAttachment 实例
  ///
  /// 使用场景：
  /// ```swift
  /// let attachment = MediaAttachment.videoWith(url: videoURL)
  /// ```
  public static func videoWith(url: URL) -> MediaAttachment {
    .init(
      id: UUID().uuidString,
      type: "video",
      url: url,
      previewUrl: url,
      description: nil,
      meta: nil)
  }
}

// MARK: - Sendable 一致性

/// MediaAttachment 符合 Sendable 协议
///
/// 所有属性都是不可变的，可以安全地在并发上下文中使用
extension MediaAttachment: Sendable {}

/// MetaContainer 符合 Sendable 协议
extension MediaAttachment.MetaContainer: Sendable {}

/// Meta 符合 Sendable 协议
extension MediaAttachment.MetaContainer.Meta: Sendable {}

/// SupportedType 符合 Sendable 协议
extension MediaAttachment.SupportedType: Sendable {}
