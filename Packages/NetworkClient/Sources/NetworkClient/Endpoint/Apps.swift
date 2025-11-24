// 文件功能：Mastodon 应用注册 API 端点定义
//
// 核心职责：
// - 定义应用注册的 API 端点
// - 支持 OAuth 应用注册
// - 提供应用信息数据结构
//
// 依赖关系：
// - 依赖：Foundation, Models
// - 被依赖：MastodonClient (OAuth 流程)

import Foundation
import Models

/// 应用注册请求数据（内部使用）
private struct InstanceAppRequest: Codable, Sendable {
  /// 应用名称
  public let clientName: String
  /// 重定向 URI（OAuth 回调地址）
  public let redirectUris: String
  /// 权限范围
  public let scopes: String
  /// 应用网站
  public let website: String
}

/// Mastodon 应用注册 API 端点
///
/// 定义了 OAuth 应用注册操作。
///
/// OAuth 流程第一步：
/// 1. 注册应用，获取 client_id 和 client_secret
/// 2. 使用 client_id 生成授权 URL
/// 3. 用户授权后获得授权码
/// 4. 使用授权码交换访问令牌
///
/// 使用示例：
/// ```swift
/// // 注册应用（在 MastodonClient.oauthURL() 中自动调用）
/// let app: InstanceApp = try await client.post(
///     endpoint: Apps.registerApp
/// )
///
/// print("Client ID: \(app.clientId)")
/// print("Client Secret: \(app.clientSecret)")
/// ```
public enum Apps: Endpoint {
  /// 注册 OAuth 应用
  ///
  /// 返回：InstanceApp 对象，包含：
  /// - clientId: 客户端 ID
  /// - clientSecret: 客户端密钥
  /// - name: 应用名称
  /// - redirectUri: 重定向 URI
  /// - website: 应用网站
  ///
  /// 注册信息来自 AppInfo：
  /// - clientName: 应用名称
  /// - scheme: 重定向 URI
  /// - scopes: 权限范围
  /// - weblink: 应用网站
  ///
  /// API 路径：`/api/v1/apps`
  /// HTTP 方法：POST
  case registerApp

  public func path() -> String {
    switch self {
    case .registerApp:
      "apps"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    nil
  }

  public var jsonValue: Encodable? {
    switch self {
    case .registerApp:
      InstanceAppRequest(
        clientName: AppInfo.clientName, redirectUris: AppInfo.scheme, scopes: AppInfo.scopes,
        website: AppInfo.weblink)
    }
  }
}
