/*
 * Oauth.swift
 * IceCubesApp - OAuth 认证端点
 *
 * 功能描述：
 * 定义 OAuth 2.0 认证流程相关的 API 端点
 * 处理用户授权和访问令牌获取的完整流程
 *
 * 技术点：
 * 1. Endpoint 协议 - 实现统一的端点接口
 * 2. Enum 枚举 - 类型安全的端点定义
 * 3. Encodable 协议 - JSON 序列化支持
 * 4. 关联值 - 枚举携带参数数据
 * 5. 模式匹配 - switch 语句处理不同端点
 * 6. 结构体 - 封装令牌请求数据
 * 7. URLQueryItem - URL 查询参数构建
 * 8. OAuth 2.0 流程 - 标准授权码流程
 * 9. AppInfo 配置 - 应用程序配置访问
 * 10. 授权码交换 - 将授权码换取访问令牌
 *
 * 技术点详解：
 * - Endpoint：实现 Mastodon OAuth API 的统一接口
 * - 关联值：枚举case可以携带不同的参数组合
 * - TokenData：封装获取访问令牌所需的请求数据
 * - OAuth 2.0：标准的授权码流程（Authorization Code Flow）
 * - AppInfo：访问应用程序的重定向URI、权限范围等配置
 * - 授权端点：生成用户授权页面的URL和参数
 * - 令牌端点：将授权码换取访问令牌的API调用
 * - 查询参数：GET 请求的 URL 参数构建
 * - JSON 请求体：POST 请求的数据封装
 * - 类型安全：使用枚举和结构体确保数据类型正确
 */

// 导入 Foundation 框架，提供 URL 和基础数据类型
import Foundation
// 导入 Models 模块，提供应用程序配置信息
import Models

// OAuth 认证相关端点枚举
public enum Oauth: Endpoint {
  // 用户授权端点，需要客户端ID
  case authorize(clientId: String)
  // 获取访问令牌端点，需要授权码、客户端ID和密钥
  case token(code: String, clientId: String, clientSecret: String)

  // 实现 Endpoint 协议：返回 API 路径
  public func path() -> String {
    switch self {
    case .authorize:
      // OAuth 授权页面路径
      "oauth/authorize"
    case .token:
      // 获取访问令牌的 API 路径
      "oauth/token"
    }
  }

  // 实现 Endpoint 协议：返回 JSON 请求体
  public var jsonValue: Encodable? {
    switch self {
    case let .token(code, clientId, clientSecret):
      // 创建令牌请求数据，用于获取访问令牌
      TokenData(clientId: clientId, clientSecret: clientSecret, code: code)
    default:
      // 授权端点不需要 JSON 请求体
      nil
    }
  }

  // 令牌请求数据结构
  public struct TokenData: Encodable {
    // OAuth 2.0 授权类型，固定为授权码流程
    public let grantType = "authorization_code"
    // 客户端ID
    public let clientId: String
    // 客户端密钥
    public let clientSecret: String
    // 重定向URI，必须与注册时一致
    public let redirectUri = AppInfo.scheme
    // 授权码，从授权回调中获得
    public let code: String
    // 权限范围，定义应用程序可访问的功能
    public let scope = AppInfo.scopes
  }

  // 实现 Endpoint 协议：返回查询参数
  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .authorize(clientId):
      // 构建授权页面的查询参数
      [
        // 响应类型，授权码流程固定为 code
        .init(name: "response_type", value: "code"),
        // 客户端ID
        .init(name: "client_id", value: clientId),
        // 重定向URI，用户授权后的回调地址
        .init(name: "redirect_uri", value: AppInfo.scheme),
        // 权限范围，请求的访问权限
        .init(name: "scope", value: AppInfo.scopes),
      ]
    default:
      // 令牌端点不需要查询参数
      nil
    }
  }
}
