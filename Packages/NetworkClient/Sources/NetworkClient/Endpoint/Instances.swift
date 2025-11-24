// 文件功能：Mastodon 实例信息 API 端点定义
//
// 核心职责：
// - 定义实例信息相关的 API 端点
// - 支持获取实例详情
// - 支持获取联邦实例列表
//
// 技术要点：
// - Instances：枚举类型，定义实例操作
// - 实例信息：配置、规则、统计数据
// - 联邦网络：连接的其他实例
//
// 实例操作类型：
// - instance：获取实例信息
// - peers：获取联邦实例列表
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：InstanceInfoView, MastodonClient

import Foundation

/// Mastodon 实例信息 API 端点
///
/// 定义了获取实例信息的操作。
///
/// 主要功能：
/// - **实例信息**：获取实例的配置和统计
/// - **联邦网络**：查看连接的其他实例
///
/// 实例信息包含：
/// - 实例名称和描述
/// - 管理员联系方式
/// - 社区规则
/// - 配置限制（字符数、媒体大小等）
/// - 统计数据（用户数、帖子数）
/// - 注册状态
///
/// 使用示例：
/// ```swift
/// // 获取实例信息
/// let instance: Instance = try await client.get(
///     endpoint: Instances.instance
/// )
///
/// print("实例名称：\(instance.title)")
/// print("用户数：\(instance.stats.userCount)")
/// print("帖子字符限制：\(instance.configuration.statuses.maxCharacters)")
///
/// // 获取联邦实例列表
/// let peers: [String] = try await client.get(
///     endpoint: Instances.peers
/// )
///
/// print("连接了 \(peers.count) 个实例")
/// ```
///
/// - Note: 实例信息不需要认证即可访问
/// - SeeAlso: `Instance` 模型包含完整的实例信息
public enum Instances: Endpoint {
  /// 获取实例信息
  ///
  /// 返回：Instance 对象，包含：
  /// - title: 实例名称
  /// - description: 实例描述
  /// - email: 管理员邮箱
  /// - version: Mastodon 版本
  /// - languages: 支持的语言
  /// - registrations: 是否开放注册
  /// - approvalRequired: 是否需要审核
  /// - rules: 社区规则
  /// - configuration: 配置限制
  /// - stats: 统计数据
  ///
  /// 使用场景：
  /// - 显示实例信息页
  /// - 检查实例配置
  /// - 显示社区规则
  /// - 注册前查看实例
  ///
  /// API 路径：`/api/v1/instance`
  /// HTTP 方法：GET
  case instance
  
  /// 获取联邦实例列表
  ///
  /// 返回：String 数组（实例域名列表）
  ///
  /// 联邦网络：
  /// - Mastodon 是去中心化的
  /// - 实例之间可以互相连接
  /// - 用户可以跨实例交互
  /// - 这个端点返回已知的连接实例
  ///
  /// 使用场景：
  /// - 显示联邦网络图
  /// - 发现其他实例
  /// - 了解实例的连接情况
  ///
  /// API 路径：`/api/v1/instance/peers`
  /// HTTP 方法：GET
  case peers

  public func path() -> String {
    switch self {
    case .instance:
      "instance"
    case .peers:
      "instance/peers"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    nil
  }
}
