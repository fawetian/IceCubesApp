// 文件功能：Mastodon 自定义表情符号数据模型
//
// 核心职责：
// - 表示 Mastodon 实例的自定义表情符号
// - 包含表情的图片 URL 和代码
// - 支持表情选择器显示
// - 提供静态和动画版本
//
// 技术要点：
// - shortcode：表情代码（如 :blobcat:）
// - url：动画版本的图片 URL（GIF/APNG）
// - staticUrl：静态版本的图片 URL（PNG）
// - visibleInPicker：是否在表情选择器中显示
// - category：表情分类（如"动物"、"食物"）
//
// 自定义表情特性：
// - 每个 Mastodon 实例可以定义自己的表情
// - 用户可以在帖子和显示名称中使用
// - 格式：:shortcode:（如 :blobcat:）
// - 支持动画（GIF）和静态图片
//
// 依赖关系：
// - 依赖：Foundation（URL）
// - 被依赖：Status, Account, EmojiText

import Foundation

/// Mastodon 自定义表情符号数据模型
///
/// 表示 Mastodon 实例的自定义表情符号。
///
/// 自定义表情特性：
/// - 每个实例可以定义独特的表情
/// - 用户可以在帖子、显示名称、简介中使用
/// - 支持动画（GIF）和静态版本
/// - 可以按分类组织
///
/// 使用方式：
/// - 在文本中使用 :shortcode: 格式
/// - 例如：:blobcat: 会显示为猫咪表情
/// - 客户端自动将代码替换为图片
///
/// 使用示例：
/// ```swift
/// // 在帖子中显示自定义表情
/// ForEach(status.emojis) { emoji in
///     AsyncImage(url: emoji.url)
///         .frame(width: 20, height: 20)
/// }
///
/// // 替换文本中的表情代码
/// let text = "Hello :blobcat:!"
/// // 将 :blobcat: 替换为对应的图片
/// ```
public struct Emoji: Codable, Hashable, Identifiable, Equatable, Sendable {
  /// 哈希值计算
  ///
  /// 使用 shortcode 计算哈希，因为它是唯一标识符
  public func hash(into hasher: inout Hasher) {
    hasher.combine(shortcode)
  }

  /// 表情的唯一标识符
  ///
  /// 使用 shortcode 作为 ID，因为在同一实例中 shortcode 是唯一的
  public var id: String {
    shortcode
  }

  /// 表情代码
  ///
  /// 用于在文本中引用表情的短代码。
  ///
  /// 格式：
  /// - 不包含冒号的代码名称
  /// - 例如："blobcat"（不是 ":blobcat:"）
  /// - 通常是小写字母和下划线
  ///
  /// 使用：
  /// - 在文本中写 :shortcode: 来使用表情
  /// - 例如：:blobcat: 会被替换为猫咪表情图片
  ///
  /// 规则：
  /// - 在同一实例中必须唯一
  /// - 不同实例可以有相同的 shortcode
  /// - 通常是描述性的名称
  public let shortcode: String
  
  /// 表情图片的 URL
  ///
  /// 指向表情图片的完整 URL。
  ///
  /// 特性：
  /// - 如果是动画表情，这是 GIF 或 APNG 文件
  /// - 如果是静态表情，与 staticUrl 相同
  /// - 用于在帖子中显示表情
  ///
  /// 用途：
  /// - 在时间线中显示动画表情
  /// - 在帖子详情中显示表情
  /// - 在表情选择器中预览
  public let url: URL
  
  /// 静态版本的图片 URL
  ///
  /// 指向表情的静态（非动画）版本。
  ///
  /// 为什么需要静态版本？
  /// - 节省流量和性能
  /// - 在列表中显示静态版本，点击后显示动画
  /// - 用户可以选择禁用动画
  /// - 在低性能设备上使用静态版本
  ///
  /// 用途：
  /// - 在设置中禁用动画时使用
  /// - 在表情选择器的缩略图中使用
  /// - 在通知中使用（节省资源）
  public let staticUrl: URL
  
  /// 是否在表情选择器中显示
  ///
  /// 控制表情是否出现在表情选择器中。
  ///
  /// 为什么有些表情不显示？
  /// - 某些表情可能是管理员专用
  /// - 某些表情可能已弃用但保留兼容性
  /// - 某些表情可能是隐藏的彩蛋
  ///
  /// 用途：
  /// - 过滤表情选择器中的表情列表
  /// - 只显示用户可以主动使用的表情
  /// - 隐藏的表情仍然可以在帖子中显示
  public let visibleInPicker: Bool
  
  /// 表情分类
  ///
  /// 表情所属的分类，用于在表情选择器中组织。
  ///
  /// 常见分类：
  /// - "动物"：动物相关的表情
  /// - "食物"：食物相关的表情
  /// - "活动"：活动和运动相关
  /// - "表情"：面部表情
  /// - 自定义分类：实例管理员可以定义
  ///
  /// 用途：
  /// - 在表情选择器中按分类显示
  /// - 帮助用户快速找到想要的表情
  /// - 组织大量自定义表情
  ///
  /// - Note: 某些表情可能没有分类，此时为 nil
  public let category: String?
}
