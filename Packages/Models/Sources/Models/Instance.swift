// 文件功能：Mastodon 实例数据模型
//
// 核心职责：
// - 表示 Mastodon 实例的完整信息
// - 包含实例的配置和限制
// - 提供实例的元数据和统计
// - 定义社区规则和联系方式
//
// 技术要点：
// - Instance：实例的完整信息
// - Configuration：实例的配置限制（字符数、媒体数等）
// - Rule：社区规则列表
// - Contact：管理员联系方式
// - APIVersions：API 版本信息
//
// 实例信息：
// - 基本信息：名称、域名、描述
// - 配置限制：帖子字符数、媒体附件数、投票选项数
// - 统计数据：活跃用户数
// - 社区规则：实例的使用规则
// - 注册状态：是否开放注册
//
// 依赖关系：
// - 依赖：Foundation, Account
// - 被依赖：CurrentInstance, InstanceView, AboutView

import Foundation

/// Mastodon 实例数据模型
///
/// 表示 Mastodon 实例的完整信息，包括配置、规则、统计等。
///
/// 主要用途：
/// - **实例信息展示**：显示实例的名称、描述、规则
/// - **配置限制检查**：验证帖子长度、媒体数量等
/// - **功能检测**：根据 API 版本判断功能支持
/// - **实例选择**：帮助用户选择合适的实例
///
/// 使用场景：
/// - 关于页面显示实例信息
/// - 发帖时检查字符数限制
/// - 上传媒体时检查数量限制
/// - 创建投票时检查选项限制
///
/// 示例：
/// ```swift
/// let instance = try await client.get(endpoint: Instances.instance)
/// print("实例名称：\(instance.title)")
/// print("最大字符数：\(instance.configuration?.statuses.maxCharacters ?? 500)")
/// print("社区规则：")
/// instance.rules?.forEach { rule in
///     print("- \(rule.text)")
/// }
/// ```
public struct Instance: Codable, Sendable, Hashable {
  /// 相等性比较
  ///
  /// 通过标题和域名判断两个实例是否相同。
  public static func == (lhs: Instance, rhs: Instance) -> Bool {
    lhs.title == rhs.title && lhs.domain == rhs.domain
  }

  /// 哈希值计算
  ///
  /// 使用标题和域名计算哈希值。
  public func hash(into hasher: inout Hasher) {
    hasher.combine(title)
    hasher.combine(domain)
  }

  /// 使用统计
  ///
  /// 实例的使用统计数据。
  public struct Usage: Codable, Sendable {
    /// 用户统计
    ///
    /// 用户相关的统计数据。
    public struct Users: Codable, Sendable {
      /// 月活跃用户数
      ///
      /// 最近一个月的活跃用户数量。
      public let activeMonth: Int?
    }
    
    /// 用户统计数据
    public let users: Users?
  }

  /// 实例配置
  ///
  /// 实例的各种配置限制和设置。
  public struct Configuration: Codable, Sendable {
    /// 帖子配置
    ///
    /// 帖子相关的限制设置。
    public struct Statuses: Codable, Sendable {
      /// 最大字符数
      ///
      /// 单条帖子允许的最大字符数。
      /// 默认为 500，某些实例可能更高（如 1000 或 5000）。
      public let maxCharacters: Int
      
      /// 最大媒体附件数
      ///
      /// 单条帖子允许的最大媒体附件数量。
      /// 通常为 4 个。
      public let maxMediaAttachments: Int
    }

    /// 投票配置
    ///
    /// 投票相关的限制设置。
    public struct Polls: Codable, Sendable {
      /// 最大选项数
      ///
      /// 单个投票允许的最大选项数量。
      /// 通常为 4 个。
      public let maxOptions: Int
      
      /// 每个选项的最大字符数
      ///
      /// 单个投票选项允许的最大字符数。
      /// 通常为 50 个字符。
      public let maxCharactersPerOption: Int
      
      /// 最小过期时间
      ///
      /// 投票的最小持续时间（秒）。
      /// 通常为 300 秒（5 分钟）。
      public let minExpiration: Int
      
      /// 最大过期时间
      ///
      /// 投票的最大持续时间（秒）。
      /// 通常为 604800 秒（7 天）。
      public let maxExpiration: Int
    }

    /// 帖子配置
    public let statuses: Statuses
    
    /// 投票配置
    public let polls: Polls
  }

  /// 社区规则
  ///
  /// 实例的使用规则和行为准则。
  public struct Rule: Codable, Identifiable, Sendable {
    /// 规则 ID
    public let id: String
    
    /// 规则文本
    ///
    /// 规则的具体内容描述。
    public let text: String
  }

  /// URL 配置
  ///
  /// 实例的各种 URL 地址。
  public struct URLs: Codable, Sendable {
    /// 流 API 地址
    ///
    /// WebSocket 流服务的 URL。
    /// 用于实时接收更新。
    public let streamingApi: URL?
  }

  /// API 版本
  ///
  /// 实例支持的 API 版本信息。
  public struct APIVersions: Codable, Sendable {
    /// Mastodon API 版本
    ///
    /// 实例支持的 Mastodon API 版本号。
    /// 用于判断功能支持情况。
    public let mastodon: Int?
  }

  /// 联系方式
  ///
  /// 实例管理员的联系信息。
  public struct Contact: Codable, Sendable {
    /// 管理员账户
    ///
    /// 实例管理员的 Mastodon 账户。
    public let account: Account?
    
    /// 联系邮箱
    ///
    /// 管理员的电子邮件地址。
    public let email: String
  }

  /// 注册状态
  ///
  /// 实例的注册开放状态。
  public struct Registrations: Codable, Sendable {
    /// 是否开放注册
    ///
    /// true 表示实例接受新用户注册。
    public let enabled: Bool
  }

  /// 缩略图
  ///
  /// 实例的缩略图图片。
  public struct Thumbnail: Codable, Sendable {
    /// 缩略图 URL
    ///
    /// 实例缩略图的图片地址。
    public let url: URL?
  }

  /// 实例标题
  ///
  /// 实例的显示名称。
  ///
  /// 示例："Mastodon.social"、"豆瓣长毛象"
  public let title: String
  
  /// 实例域名
  ///
  /// 实例的域名地址。
  ///
  /// 示例："mastodon.social"、"mastodon.online"
  public let domain: String
  
  /// 实例描述
  ///
  /// 实例的详细描述信息。
  ///
  /// 通常包含实例的特色、主题、规则等。
  public let description: String?
  
  /// 简短描述
  ///
  /// 实例的简短介绍。
  ///
  /// 用于列表显示或预览。
  public let shortDescription: String?
  
  /// Mastodon 版本
  ///
  /// 实例运行的 Mastodon 版本号。
  ///
  /// 示例："4.1.2"、"3.5.0"
  public let version: String
  
  /// API 版本信息
  ///
  /// 实例支持的 API 版本。
  ///
  /// 用于功能检测和兼容性判断。
  public let apiVersions: APIVersions?
  
  /// 使用统计
  ///
  /// 实例的使用统计数据。
  ///
  /// 包含活跃用户数等信息。
  public let usage: Usage?
  
  /// 支持的语言
  ///
  /// 实例支持的语言列表。
  ///
  /// 使用 ISO 639-1 语言代码。
  /// 示例：["en", "zh", "ja"]
  public let languages: [String]?
  
  /// 注册状态
  ///
  /// 实例的注册开放状态。
  public let registrations: Registrations
  
  /// 缩略图
  ///
  /// 实例的缩略图图片。
  public let thumbnail: Thumbnail
  
  /// 配置信息
  ///
  /// 实例的配置限制。
  ///
  /// 包含帖子字符数、媒体数量、投票选项等限制。
  public let configuration: Configuration?
  
  /// 社区规则
  ///
  /// 实例的使用规则列表。
  ///
  /// 用户在注册时需要同意这些规则。
  public let rules: [Rule]?
  
  /// URL 配置
  ///
  /// 实例的各种 URL 地址。
  ///
  /// 包含流 API 地址等。
  public let urls: URLs?
  
  /// 联系方式
  ///
  /// 实例管理员的联系信息。
  public let contact: Contact
}
