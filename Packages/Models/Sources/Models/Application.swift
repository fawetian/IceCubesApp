// 文件功能：Mastodon 应用信息数据模型
//
// 核心职责：
// - 表示发布帖子的应用信息
// - 包含应用名称和网站
// - 显示帖子来源
// - 支持第三方应用识别
//
// 技术要点：
// - Application：应用的基本信息
// - 使用名称作为 ID
// - 自定义解码处理可选字段
// - Sendable 并发安全
//
// 应用信息：
// - 应用名称：如 "IceCubesApp"、"Mastodon for iOS"
// - 应用网站：应用的官方网站链接
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：Status

import Foundation

/// 应用信息数据模型
///
/// 表示发布帖子的应用程序信息。
///
/// 主要用途：
/// - **显示来源**：在帖子下方显示"来自 XXX"
/// - **应用识别**：识别使用的客户端
/// - **链接跳转**：点击可访问应用网站
///
/// 使用场景：
/// - 帖子详情显示应用来源
/// - 统计不同客户端的使用情况
/// - 提供应用下载链接
///
/// 示例：
/// ```swift
/// if let app = status.application {
///     HStack {
///         Text("来自")
///         if let website = app.website {
///             Link(app.name, destination: website)
///         } else {
///             Text(app.name)
///         }
///     }
///     .font(.caption)
///     .foregroundColor(.secondary)
/// }
/// ```
public struct Application: Codable, Identifiable, Hashable, Equatable, Sendable {
  /// 应用 ID
  ///
  /// 使用应用名称作为唯一标识符。
  ///
  /// 设计原因：
  /// - Mastodon API 不提供应用 ID
  /// - 使用名称作为标识符
  /// - 满足 Identifiable 协议要求
  public var id: String {
    name
  }

  /// 应用名称
  ///
  /// 应用的显示名称。
  ///
  /// 示例：
  /// - "IceCubesApp"
  /// - "Mastodon for iOS"
  /// - "Tusky"
  /// - "Web"
  public let name: String

  /// 应用网站
  ///
  /// 应用的官方网站 URL。
  ///
  /// 用途：
  /// - 提供应用下载链接
  /// - 显示应用信息
  /// - 支持点击跳转
  ///
  /// 示例：
  /// - https://github.com/Dimillian/IceCubesApp
  /// - https://joinmastodon.org/apps
  public let website: URL?
}

// MARK: - 自定义解码

/// Application 的自定义解码扩展
///
/// 为所有字段提供默认值，确保解码不会失败。
extension Application {
  /// 自定义初始化方法
  ///
  /// 从 JSON 解码时，为所有字段提供默认值。
  ///
  /// 默认值策略：
  /// - name：空字符串 ""（如果缺失）
  /// - website：nil（如果缺失或无效）
  ///
  /// 这样即使服务器返回的数据不完整，也能正常解码。
  ///
  /// - Note: website 使用 try? 忽略解码错误
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
    website = try? values.decodeIfPresent(URL.self, forKey: .website)
  }
}
