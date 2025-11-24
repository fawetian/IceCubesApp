// 文件功能：Mastodon API 客户端核心实现
//
// 核心职责：
// - 提供与 Mastodon API 交互的统一接口
// - 管理 OAuth 认证和访问令牌
// - 处理 HTTP 请求（GET、POST、PUT、DELETE、PATCH）
// - 支持媒体文件上传（图片、视频、音频）
// - 管理 WebSocket 连接（实时流）
// - 处理 API 错误和响应解析
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架，支持 SwiftUI 响应式更新
// - OSAllocatedUnfairLock：使用锁保证线程安全，使类符合 Sendable
// - async/await：所有网络请求使用现代 Swift 并发
// - JSONDecoder：自动将 snake_case 转换为 camelCase
// - URLSession：底层网络请求实现
// - OAuth 2.0：标准的 OAuth 认证流程
//
// 使用场景：
// - 在 SwiftUI 视图中通过 @Environment 注入
// - 执行所有 Mastodon API 操作（获取时间线、发帖、关注等）
// - 管理用户认证状态
// - 上传媒体文件
// - 建立实时流连接
//
// 依赖关系：
// - 依赖：Foundation, Models, Observation, OSLog
// - 被依赖：所有需要访问 Mastodon API 的模块

import Combine
import Foundation
import Models
import OSLog
import Observation
import SwiftUI
import os

/// Mastodon API 客户端
///
/// 这是与 Mastodon 服务器交互的核心类，提供了所有 API 操作的统一接口。
///
/// 主要功能：
/// - **认证管理**：处理 OAuth 2.0 认证流程，管理访问令牌
/// - **HTTP 请求**：支持 GET、POST、PUT、DELETE、PATCH 方法
/// - **媒体上传**：支持图片、视频、音频的上传，带进度回调
/// - **实时流**：创建 WebSocket 连接，接收实时更新
/// - **错误处理**：解析服务器错误，提供详细的错误信息
/// - **多实例支持**：可以同时连接多个 Mastodon 实例
///
/// 线程安全：
/// - 使用 `OSAllocatedUnfairLock` 保护可变状态
/// - 所有公共方法都是线程安全的
/// - 符合 `Sendable` 协议，可以安全地跨并发域传递
///
/// 使用示例：
/// ```swift
/// // 1. 创建客户端
/// let client = MastodonClient(
///     server: "mastodon.social",
///     oauthToken: token
/// )
///
/// // 2. 在 SwiftUI 中注入
/// struct ContentView: View {
///     @Environment(MastodonClient.self) private var client
///
///     var body: some View {
///         Button("获取时间线") {
///             Task {
///                 let statuses: [Status] = try await client.get(
///                     endpoint: Timelines.home(maxId: nil)
///                 )
///                 print("获取到 \(statuses.count) 条帖子")
///             }
///         }
///     }
/// }
///
/// // 3. 发布帖子
/// let newStatus: Status = try await client.post(
///     endpoint: Statuses.postStatus(
///         json: StatusData(status: "Hello Mastodon!")
///     )
/// )
///
/// // 4. 上传媒体
/// let attachment: MediaAttachment = try await client.mediaUpload(
///     endpoint: Media.medias,
///     version: .v2,
///     method: "POST",
///     mimeType: "image/jpeg",
///     filename: "photo.jpg",
///     data: imageData
/// )
/// ```
///
/// OAuth 认证流程：
/// ```swift
/// // 1. 获取授权 URL
/// let oauthURL = try await client.oauthURL()
/// // 打开浏览器让用户授权
///
/// // 2. 用户授权后，应用收到回调 URL
/// let callbackURL = URL(string: "icecubes://oauth-callback?code=...")!
///
/// // 3. 完成 OAuth 流程，获取访问令牌
/// let token = try await client.continueOauthFlow(url: callbackURL)
/// // 现在客户端已经认证，可以进行 API 调用
/// ```
///
/// - Note: 客户端会自动处理 API 版本（v1 或 v2）和请求头
/// - Warning: 确保在使用前已经设置了有效的 OAuth 令牌
/// - SeeAlso: `Endpoint` 协议定义了所有可用的 API 端点
@Observable
public final class MastodonClient: Equatable, Identifiable, Hashable, Sendable {
  /// 相等性比较
  ///
  /// 两个客户端相等的条件：
  /// - 连接到同一个服务器
  /// - 认证状态相同（都有令牌或都没有令牌）
  /// - 如果都有令牌，则访问令牌相同
  ///
  /// 这个比较是线程安全的，使用锁来访问令牌。
  public static func == (lhs: MastodonClient, rhs: MastodonClient) -> Bool {
    let lhsToken = lhs.critical.withLock { $0.oauthToken }
    let rhsToken = rhs.critical.withLock { $0.oauthToken }

    return (lhsToken != nil) == (rhsToken != nil) && lhs.server == rhs.server
      && lhsToken?.accessToken == rhsToken?.accessToken
  }

  /// Mastodon API 版本
  ///
  /// Mastodon 支持多个 API 版本，不同版本的端点路径不同。
  ///
  /// - v1: API v1，大多数端点使用此版本（/api/v1/...）
  /// - v2: API v2，一些新端点使用此版本（/api/v2/...）
  ///
  /// 示例：
  /// - v1: /api/v1/timelines/home
  /// - v2: /api/v2/search
  public enum Version: String, Sendable {
    case v1, v2
  }

  /// 客户端错误
  ///
  /// 表示客户端内部错误，通常是请求构建失败。
  public enum ClientError: Error {
    /// 无法构建有效的请求
    ///
    /// 可能的原因：
    /// - URL 组件无效
    /// - 端点配置错误
    case unexpectedRequest
  }

  /// OAuth 认证错误
  ///
  /// 表示 OAuth 认证流程中的错误。
  public enum OauthError: Error {
    /// 缺少应用信息
    ///
    /// 在完成 OAuth 流程前，必须先调用 `oauthURL()` 注册应用。
    case missingApp
    
    /// 无效的重定向 URL
    ///
    /// OAuth 回调 URL 格式不正确或缺少授权码。
    case invalidRedirectURL
  }

  /// 客户端的唯一标识符
  ///
  /// 标识符由以下部分组成：
  /// - 认证状态（true/false）
  /// - 服务器地址
  /// - 令牌创建时间（如果有令牌）
  ///
  /// 这确保了每个服务器+令牌组合都有唯一的 ID。
  public var id: String {
    critical.withLock {
      let isAuth = $0.oauthToken != nil
      return "\(isAuth)\(server)\($0.oauthToken?.createdAt ?? 0)"
    }
  }

  /// 哈希值计算
  ///
  /// 使用客户端 ID 计算哈希，确保相同的客户端有相同的哈希值。
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  /// Mastodon 服务器地址
  ///
  /// 格式：域名（不含协议）
  /// 示例：
  /// - "mastodon.social"
  /// - "mas.to"
  /// - "fosstodon.org"
  public let server: String
  
  /// API 版本
  ///
  /// 默认使用 v1，某些端点可能需要 v2。
  public let version: Version
  
  /// URL 会话
  ///
  /// 用于执行所有 HTTP 请求。使用共享会话以提高性能。
  private let urlSession: URLSession
  
  /// JSON 解码器
  ///
  /// 配置：
  /// - keyDecodingStrategy: .convertFromSnakeCase
  ///   自动将 API 的 snake_case 转换为 Swift 的 camelCase
  ///
  /// 示例：
  /// - API: "display_name" → Swift: "displayName"
  /// - API: "created_at" → Swift: "createdAt"
  private let decoder = JSONDecoder()

  /// 日志记录器
  ///
  /// 用于记录网络请求和错误，便于调试。
  private let logger = Logger(subsystem: "com.icecubesapp", category: "networking")

  /// 临界区（线程安全的可变状态）
  ///
  /// 使用 `OSAllocatedUnfairLock` 保护所有可变状态，这使得 `MastodonClient`
  /// 可以安全地符合 `Sendable` 协议。
  ///
  /// 设计原理：
  /// - 锁是一个结构体，但内部使用 `ManagedBuffer` 引用类型
  /// - 所有对可变状态的访问都必须通过 `withLock` 闭包
  /// - 这确保了在并发环境中的线程安全
  ///
  /// 为什么需要线程安全：
  /// - SwiftUI 视图可能在任何线程上访问客户端
  /// - 多个异步任务可能同时使用同一个客户端
  /// - OAuth 流程可能在后台线程完成
  private let critical: OSAllocatedUnfairLock<Critical>
  
  /// 临界区内的可变状态
  ///
  /// 所有可变状态都封装在这个结构体中，通过锁保护。
  private struct Critical: Sendable {
    /// OAuth 应用信息（临时）
    ///
    /// 仅在 OAuth 认证流程中使用：
    /// 1. 调用 `oauthURL()` 时注册应用，保存应用信息
    /// 2. 调用 `continueOauthFlow()` 时使用应用信息获取令牌
    /// 3. 获取令牌后，这个字段不再使用
    var oauthApp: InstanceApp?
    
    /// OAuth 访问令牌
    ///
    /// 用于认证所有 API 请求。
    ///
    /// 令牌包含：
    /// - accessToken: 实际的访问令牌字符串
    /// - tokenType: 通常是 "Bearer"
    /// - scope: 授权范围
    /// - createdAt: 创建时间
    var oauthToken: OauthToken?
    
    /// 已知的连接服务器集合
    ///
    /// 包含所有与此客户端有关联的服务器域名。
    ///
    /// 用途：
    /// - 判断一个 URL 是否属于已知的 Mastodon 实例
    /// - 决定是否可以在应用内打开链接
    /// - 支持跨实例交互
    var connections: Set<String> = []
  }

  /// 是否已认证
  ///
  /// - true: 客户端有有效的访问令牌，可以进行 API 调用
  /// - false: 客户端未认证，只能访问公开端点
  ///
  /// 使用场景：
  /// - 决定是否显示登录按钮
  /// - 判断是否可以执行需要认证的操作
  /// - 在 UI 中显示认证状态
  public var isAuth: Bool {
    critical.withLock { $0.oauthToken != nil }
  }

  /// 已知的连接服务器集合
  ///
  /// 返回所有与此客户端关联的服务器域名。
  ///
  /// 用途：
  /// - 判断链接是否指向已知的 Mastodon 实例
  /// - 决定是否在应用内打开链接
  public var connections: Set<String> {
    critical.withLock { $0.connections }
  }

  /// 初始化 Mastodon 客户端
  ///
  /// - Parameters:
  ///   - server: Mastodon 服务器地址（域名，不含协议）
  ///   - version: API 版本，默认为 v1
  ///   - oauthToken: OAuth 访问令牌（可选）
  ///
  /// 使用示例：
  /// ```swift
  /// // 创建未认证的客户端（只能访问公开内容）
  /// let publicClient = MastodonClient(server: "mastodon.social")
  ///
  /// // 创建已认证的客户端
  /// let authenticatedClient = MastodonClient(
  ///     server: "mastodon.social",
  ///     oauthToken: savedToken
  /// )
  ///
  /// // 使用 v2 API
  /// let v2Client = MastodonClient(
  ///     server: "mastodon.social",
  ///     version: .v2,
  ///     oauthToken: savedToken
  /// )
  /// ```
  ///
  /// 初始化过程：
  /// 1. 保存服务器地址和 API 版本
  /// 2. 初始化临界区，保存令牌和服务器连接
  /// 3. 配置 JSON 解码器（snake_case → camelCase）
  /// 4. 使用共享的 URLSession
  public init(server: String, version: Version = .v1, oauthToken: OauthToken? = nil) {
    self.server = server
    self.version = version
    critical = .init(initialState: Critical(oauthToken: oauthToken, connections: [server]))
    urlSession = URLSession.shared
    decoder.keyDecodingStrategy = .convertFromSnakeCase
  }

  /// 添加已知的连接服务器
  ///
  /// 将新的服务器域名添加到已知连接集合中。
  ///
  /// - Parameter connections: 要添加的服务器域名数组
  ///
  /// 使用场景：
  /// - 用户关注了其他实例的账户
  /// - 发现了新的联邦实例
  /// - 需要判断链接是否指向 Mastodon 实例
  ///
  /// 示例：
  /// ```swift
  /// client.addConnections(["fosstodon.org", "mas.to"])
  /// ```
  public func addConnections(_ connections: [String]) {
    critical.withLock {
      $0.connections.formUnion(connections)
    }
  }

  /// 检查 URL 是否指向已知的连接服务器
  ///
  /// - Parameter url: 要检查的 URL
  /// - Returns: 如果 URL 的主机是已知的 Mastodon 实例，返回 true
  ///
  /// 检查逻辑：
  /// 1. 提取 URL 的主机名
  /// 2. 检查主机名是否在已知连接中
  /// 3. 如果主机名有子域名，也检查根域名
  ///    （因为有时 Mastodon 运行在子域名上，但连接记录的是根域名）
  ///
  /// 示例：
  /// ```swift
  /// let url = URL(string: "https://mastodon.social/@user")!
  /// if client.hasConnection(with: url) {
  ///     // 在应用内打开
  ///     openInApp(url)
  /// } else {
  ///     // 在外部浏览器打开
  ///     openInBrowser(url)
  /// }
  /// ```
  ///
  /// 特殊处理：
  /// - 如果 Mastodon 运行在 mastodon.domain.com
  /// - 但连接记录的是 domain.com
  /// - 这个方法仍然会返回 true
  public func hasConnection(with url: URL) -> Bool {
    guard let host = url.host else { return false }
    return critical.withLock {
      if let rootHost = host.split(separator: ".", maxSplits: 1).last {
        // 有时连接是与根域名建立的，而不是子域名
        // 例如：Mastodon 运行在 mastodon.domain.com，但连接是 domain.com
        $0.connections.contains(host) || $0.connections.contains(String(rootHost))
      } else {
        $0.connections.contains(host)
      }
    }
  }

  private func makeURL(
    scheme: String = "https",
    endpoint: Endpoint,
    forceVersion: Version? = nil,
    forceServer: String? = nil
  ) throws -> URL {
    var components = URLComponents()
    components.scheme = scheme
    components.host = forceServer ?? server
    if type(of: endpoint) == Oauth.self {
      components.path += "/\(endpoint.path())"
    } else {
      components.path += "/api/\(forceVersion?.rawValue ?? version.rawValue)/\(endpoint.path())"
    }
    components.queryItems = endpoint.queryItems()
    guard let url = components.url else {
      throw ClientError.unexpectedRequest
    }
    return url
  }

  private func makeURLRequest(url: URL, endpoint: Endpoint, httpMethod: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = httpMethod
    if let oauthToken = critical.withLock({ $0.oauthToken }) {
      request.setValue("Bearer \(oauthToken.accessToken)", forHTTPHeaderField: "Authorization")
    }
    if let json = endpoint.jsonValue {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      encoder.outputFormatting = .sortedKeys
      do {
        let jsonData = try encoder.encode(json)
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      } catch {
        logger.error("Error encoding JSON: \(error.localizedDescription)")
      }
    }
    return request
  }

  private func makeGet(endpoint: Endpoint) throws -> URLRequest {
    let url = try makeURL(endpoint: endpoint)
    return makeURLRequest(url: url, endpoint: endpoint, httpMethod: "GET")
  }

  /// 执行 GET 请求并解码响应
  ///
  /// - Parameters:
  ///   - endpoint: API 端点
  ///   - forceVersion: 强制使用的 API 版本（可选，默认使用客户端的版本）
  /// - Returns: 解码后的实体对象
  /// - Throws: 网络错误、解码错误或服务器错误
  ///
  /// 使用示例：
  /// ```swift
  /// // 获取主页时间线
  /// let statuses: [Status] = try await client.get(
  ///     endpoint: Timelines.home(maxId: nil)
  /// )
  ///
  /// // 获取账户信息
  /// let account: Account = try await client.get(
  ///     endpoint: Accounts.accounts(id: "123")
  /// )
  ///
  /// // 强制使用 v2 API
  /// let searchResults: SearchResults = try await client.get(
  ///     endpoint: Search.search(query: "swift"),
  ///     forceVersion: .v2
  /// )
  /// ```
  ///
  /// 请求流程：
  /// 1. 构建 URL（包含路径和查询参数）
  /// 2. 创建 URLRequest（添加认证头）
  /// 3. 执行请求
  /// 4. 解码 JSON 响应
  /// 5. 如果失败，尝试解码服务器错误
  public func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: Version? = nil) async throws
    -> Entity
  {
    try await makeEntityRequest(endpoint: endpoint, method: "GET", forceVersion: forceVersion)
  }

  /// 执行 GET 请求并返回响应数据和分页链接
  ///
  /// - Parameter endpoint: API 端点
  /// - Returns: 元组（解码后的实体对象，分页链接处理器）
  /// - Throws: 网络错误、解码错误或服务器错误
  ///
  /// 分页链接：
  /// Mastodon API 在响应头的 `Link` 字段中返回分页信息：
  /// - `next`: 下一页的 URL
  /// - `prev`: 上一页的 URL
  ///
  /// 使用示例：
  /// ```swift
  /// // 获取时间线和分页链接
  /// let (statuses, linkHandler) = try await client.getWithLink(
  ///     endpoint: Timelines.home(maxId: nil)
  /// )
  ///
  /// // 加载下一页
  /// if let nextMaxId = linkHandler?.maxId {
  ///     let (moreStatuses, _) = try await client.getWithLink(
  ///         endpoint: Timelines.home(maxId: nextMaxId)
  ///     )
  /// }
  /// ```
  ///
  /// - Note: 这个方法主要用于需要分页的列表端点
  /// - SeeAlso: `LinkHandler` 用于解析分页链接
  public func getWithLink<Entity: Decodable>(endpoint: Endpoint) async throws -> (
    Entity, LinkHandler?
  ) {
    let request = try makeGet(endpoint: endpoint)
    let (data, httpResponse) = try await urlSession.data(for: request)
    var linkHandler: LinkHandler?
    if let response = httpResponse as? HTTPURLResponse,
      let link = response.allHeaderFields["Link"] as? String
    {
      linkHandler = .init(rawLink: link)
    }
    logResponseOnError(httpResponse: httpResponse, data: data)
    logger.log(level: .info, "\(request)")
    return try (decoder.decode(Entity.self, from: data), linkHandler)
  }

  /// 执行 POST 请求并解码响应
  ///
  /// - Parameters:
  ///   - endpoint: API 端点
  ///   - forceVersion: 强制使用的 API 版本（可选）
  /// - Returns: 解码后的实体对象
  /// - Throws: 网络错误、解码错误或服务器错误
  ///
  /// 使用示例：
  /// ```swift
  /// // 发布新帖子
  /// let newStatus: Status = try await client.post(
  ///     endpoint: Statuses.postStatus(
  ///         json: StatusData(status: "Hello Mastodon!")
  ///     )
  /// )
  ///
  /// // 关注用户
  /// let relationship: Relationship = try await client.post(
  ///     endpoint: Accounts.follow(id: "123")
  /// )
  ///
  /// // 点赞帖子
  /// let status: Status = try await client.post(
  ///     endpoint: Statuses.favourite(id: "456")
  /// )
  /// ```
  ///
  /// POST 请求特点：
  /// - 通常用于创建资源或执行操作
  /// - 请求体包含 JSON 数据（通过 endpoint.jsonValue）
  /// - 返回创建的资源或操作结果
  public func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: Version? = nil) async throws
    -> Entity
  {
    try await makeEntityRequest(endpoint: endpoint, method: "POST", forceVersion: forceVersion)
  }

  /// 执行 POST 请求（不解码响应）
  ///
  /// - Parameters:
  ///   - endpoint: API 端点
  ///   - forceVersion: 强制使用的 API 版本（可选）
  /// - Returns: HTTP 响应对象
  /// - Throws: 网络错误或服务器错误
  ///
  /// 使用场景：
  /// - 操作不需要返回数据
  /// - 只需要检查 HTTP 状态码
  ///
  /// 示例：
  /// ```swift
  /// // 静音用户（不需要返回数据）
  /// let response = try await client.post(
  ///     endpoint: Accounts.mute(id: "123")
  /// )
  /// if response?.statusCode == 200 {
  ///     print("静音成功")
  /// }
  /// ```
  public func post(endpoint: Endpoint, forceVersion: Version? = nil) async throws
    -> HTTPURLResponse?
  {
    let url = try makeURL(endpoint: endpoint, forceVersion: forceVersion)
    let request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: "POST")
    let (_, httpResponse) = try await urlSession.data(for: request)
    return httpResponse as? HTTPURLResponse
  }

  /// 执行 PATCH 请求
  ///
  /// - Parameter endpoint: API 端点
  /// - Returns: HTTP 响应对象
  /// - Throws: 网络错误或服务器错误
  ///
  /// PATCH 用途：
  /// - 部分更新资源
  /// - 只修改指定的字段
  ///
  /// 示例：
  /// ```swift
  /// // 更新账户信息
  /// let response = try await client.patch(
  ///     endpoint: Accounts.updateCredentials(
  ///         json: AccountUpdateData(displayName: "新名称")
  ///     )
  /// )
  /// ```
  public func patch(endpoint: Endpoint) async throws -> HTTPURLResponse? {
    let url = try makeURL(endpoint: endpoint)
    let request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: "PATCH")
    let (_, httpResponse) = try await urlSession.data(for: request)
    return httpResponse as? HTTPURLResponse
  }

  /// 执行 PUT 请求并解码响应
  ///
  /// - Parameters:
  ///   - endpoint: API 端点
  ///   - forceVersion: 强制使用的 API 版本（可选）
  /// - Returns: 解码后的实体对象
  /// - Throws: 网络错误、解码错误或服务器错误
  ///
  /// PUT 用途：
  /// - 完整替换资源
  /// - 更新整个对象
  ///
  /// 示例：
  /// ```swift
  /// // 更新列表
  /// let list: List = try await client.put(
  ///     endpoint: Lists.updateList(
  ///         id: "123",
  ///         title: "新标题"
  ///     )
  /// )
  /// ```
  public func put<Entity: Decodable>(endpoint: Endpoint, forceVersion: Version? = nil) async throws
    -> Entity
  {
    try await makeEntityRequest(endpoint: endpoint, method: "PUT", forceVersion: forceVersion)
  }

  /// 执行 DELETE 请求
  ///
  /// - Parameters:
  ///   - endpoint: API 端点
  ///   - forceVersion: 强制使用的 API 版本（可选）
  /// - Returns: HTTP 响应对象
  /// - Throws: 网络错误或服务器错误
  ///
  /// DELETE 用途：
  /// - 删除资源
  /// - 取消操作
  ///
  /// 示例：
  /// ```swift
  /// // 删除帖子
  /// let response = try await client.delete(
  ///     endpoint: Statuses.status(id: "123")
  /// )
  /// if response?.statusCode == 200 {
  ///     print("删除成功")
  /// }
  ///
  /// // 取消关注
  /// try await client.delete(
  ///     endpoint: Accounts.unfollow(id: "456")
  /// )
  /// ```
  public func delete(endpoint: Endpoint, forceVersion: Version? = nil) async throws
    -> HTTPURLResponse?
  {
    let url = try makeURL(endpoint: endpoint, forceVersion: forceVersion)
    let request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: "DELETE")
    let (_, httpResponse) = try await urlSession.data(for: request)
    return httpResponse as? HTTPURLResponse
  }

  private func makeEntityRequest<Entity: Decodable>(
    endpoint: Endpoint,
    method: String,
    forceVersion: Version? = nil
  ) async throws -> Entity {
    let url = try makeURL(endpoint: endpoint, forceVersion: forceVersion)
    let request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: method)
    let (data, httpResponse) = try await urlSession.data(for: request)
    logger.log(level: .info, "\(request)")
    logResponseOnError(httpResponse: httpResponse, data: data)
    do {
      return try decoder.decode(Entity.self, from: data)
    } catch {
      if var serverError = try? decoder.decode(ServerError.self, from: data) {
        if let httpResponse = httpResponse as? HTTPURLResponse {
          serverError.httpCode = httpResponse.statusCode
        }
        throw serverError
      }
      throw error
    }
  }

  /// 获取 OAuth 授权 URL
  ///
  /// 这是 OAuth 2.0 认证流程的第一步。
  ///
  /// - Returns: 用户授权 URL，应在浏览器中打开
  /// - Throws: 网络错误或应用注册失败
  ///
  /// OAuth 流程：
  /// 1. **注册应用**：向 Mastodon 服务器注册应用，获取 client_id 和 client_secret
  /// 2. **获取授权 URL**：构建授权 URL，包含 client_id 和回调 URL
  /// 3. **用户授权**：在浏览器中打开 URL，用户登录并授权
  /// 4. **获取授权码**：用户授权后，浏览器重定向到回调 URL，包含授权码
  /// 5. **交换令牌**：使用授权码交换访问令牌（调用 `continueOauthFlow`）
  ///
  /// 使用示例：
  /// ```swift
  /// // 1. 获取授权 URL
  /// let oauthURL = try await client.oauthURL()
  ///
  /// // 2. 在浏览器中打开（SwiftUI）
  /// @State private var showSafari = false
  /// @State private var oauthURL: URL?
  ///
  /// Button("登录") {
  ///     Task {
  ///         oauthURL = try await client.oauthURL()
  ///         showSafari = true
  ///     }
  /// }
  /// .sheet(isPresented: $showSafari) {
  ///     if let url = oauthURL {
  ///         SafariView(url: url)
  ///     }
  /// }
  ///
  /// // 3. 处理回调（在 AppDelegate 或 SceneDelegate 中）
  /// func application(_ app: UIApplication,
  ///                  open url: URL,
  ///                  options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
  ///     Task {
  ///         let token = try await client.continueOauthFlow(url: url)
  ///         // 保存令牌，更新 UI
  ///     }
  ///     return true
  /// }
  /// ```
  ///
  /// - Note: 应用信息会临时保存在 `oauthApp` 中，用于后续的令牌交换
  /// - Warning: 必须先调用此方法，才能调用 `continueOauthFlow`
  public func oauthURL() async throws -> URL {
    let app: InstanceApp = try await post(endpoint: Apps.registerApp)
    critical.withLock { $0.oauthApp = app }
    return try makeURL(endpoint: Oauth.authorize(clientId: app.clientId))
  }

  /// 完成 OAuth 认证流程
  ///
  /// 这是 OAuth 2.0 认证流程的最后一步。
  ///
  /// - Parameter url: OAuth 回调 URL（包含授权码）
  /// - Returns: 访问令牌
  /// - Throws: `OauthError.missingApp` 如果未先调用 `oauthURL()`
  ///           `OauthError.invalidRedirectURL` 如果回调 URL 格式不正确
  ///           网络错误或令牌交换失败
  ///
  /// 回调 URL 格式：
  /// ```
  /// icecubes://oauth-callback?code=AUTHORIZATION_CODE
  /// ```
  ///
  /// 使用示例：
  /// ```swift
  /// // 在 URL scheme 处理器中
  /// func handleOAuthCallback(_ url: URL) {
  ///     Task {
  ///         do {
  ///             let token = try await client.continueOauthFlow(url: url)
  ///             
  ///             // 保存令牌到 Keychain
  ///             try saveToken(token)
  ///             
  ///             // 更新 UI，显示已登录状态
  ///             await MainActor.run {
  ///                 isLoggedIn = true
  ///             }
  ///         } catch {
  ///             print("OAuth 失败: \(error)")
  ///         }
  ///     }
  /// }
  /// ```
  ///
  /// 实现逻辑：
  /// 1. 检查是否有保存的应用信息（必须先调用 `oauthURL()`）
  /// 2. 从回调 URL 中提取授权码
  /// 3. 使用授权码、client_id 和 client_secret 交换访问令牌
  /// 4. 保存访问令牌到客户端
  /// 5. 返回令牌供调用者保存
  ///
  /// - Note: 令牌会自动保存到客户端，后续的 API 调用会自动使用此令牌
  /// - Warning: 回调 URL 必须与注册应用时指定的重定向 URI 匹配
  public func continueOauthFlow(url: URL) async throws -> OauthToken {
    guard let app = critical.withLock({ $0.oauthApp }) else {
      throw OauthError.missingApp
    }
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
    else {
      throw OauthError.invalidRedirectURL
    }
    let token: OauthToken = try await post(
      endpoint: Oauth.token(
        code: code,
        clientId: app.clientId,
        clientSecret: app.clientSecret))
    critical.withLock { $0.oauthToken = token }
    return token
  }

  /// 创建 WebSocket 任务（用于实时流）
  ///
  /// - Parameters:
  ///   - endpoint: 流端点（user, public, hashtag 等）
  ///   - instanceStreamingURL: 实例的流服务器 URL（可选）
  /// - Returns: WebSocket 任务
  /// - Throws: URL 构建失败
  ///
  /// Mastodon 实时流：
  /// Mastodon 支持通过 WebSocket 接收实时更新：
  /// - **user**: 用户的主页时间线更新
  /// - **public**: 公共时间线更新
  /// - **public:local**: 本地时间线更新
  /// - **hashtag**: 特定标签的更新
  /// - **list**: 特定列表的更新
  ///
  /// 使用示例：
  /// ```swift
  /// // 创建 WebSocket 任务
  /// let task = try client.makeWebSocketTask(
  ///     endpoint: Streaming.user,
  ///     instanceStreamingURL: nil
  /// )
  ///
  /// // 开始连接
  /// task.resume()
  ///
  /// // 接收消息
  /// Task {
  ///     while true {
  ///         let message = try await task.receive()
  ///         switch message {
  ///         case .string(let text):
  ///             // 解析流事件
  ///             let event = try JSONDecoder().decode(StreamEvent.self, from: text.data(using: .utf8)!)
  ///             handleStreamEvent(event)
  ///         case .data(let data):
  ///             // 处理二进制数据
  ///             break
  ///         @unknown default:
  ///             break
  ///         }
  ///     }
  /// }
  /// ```
  ///
  /// 认证：
  /// - 如果客户端已认证，访问令牌会作为 WebSocket 子协议传递
  /// - 这样服务器就知道是哪个用户在连接
  ///
  /// - Note: 某些实例可能使用单独的流服务器，通过 `instanceStreamingURL` 指定
  /// - SeeAlso: `StreamWatcher` 类封装了 WebSocket 的使用
  public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws
    -> URLSessionWebSocketTask
  {
    let url = try makeURL(
      scheme: "wss", endpoint: endpoint, forceServer: instanceStreamingURL?.host)
    var subprotocols: [String] = []
    if let oauthToken = critical.withLock({ $0.oauthToken }) {
      subprotocols.append(oauthToken.accessToken)
    }
    return urlSession.webSocketTask(with: url, protocols: subprotocols)
  }

  /// 上传媒体文件并解码响应
  ///
  /// - Parameters:
  ///   - endpoint: 媒体上传端点
  ///   - version: API 版本（通常使用 v2）
  ///   - method: HTTP 方法（通常是 "POST"）
  ///   - mimeType: 文件的 MIME 类型
  ///   - filename: 文件名
  ///   - data: 文件数据
  /// - Returns: 解码后的媒体附件对象
  /// - Throws: 网络错误、解码错误或服务器错误
  ///
  /// 支持的媒体类型：
  /// - **图片**: image/jpeg, image/png, image/gif, image/webp
  /// - **视频**: video/mp4, video/quicktime, video/webm
  /// - **音频**: audio/mpeg, audio/ogg, audio/wav
  ///
  /// 使用示例：
  /// ```swift
  /// // 上传图片
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
  /// // 使用附件 ID 发布帖子
  /// let status: Status = try await client.post(
  ///     endpoint: Statuses.postStatus(
  ///         json: StatusData(
  ///             status: "看看我的照片！",
  ///             mediaIds: [attachment.id]
  ///         )
  ///     )
  /// )
  /// ```
  ///
  /// 上传流程：
  /// 1. 构建 multipart/form-data 请求
  /// 2. 上传文件数据
  /// 3. 服务器处理文件（可能需要转码）
  /// 4. 返回媒体附件对象（包含 ID 和 URL）
  ///
  /// - Note: 上传后需要使用返回的 `id` 来关联到帖子
  /// - Warning: 文件大小和类型限制由服务器配置决定
  public func mediaUpload<Entity: Decodable>(
    endpoint: Endpoint,
    version: Version,
    method: String,
    mimeType: String,
    filename: String,
    data: Data
  ) async throws -> Entity {
    let request = try makeFormDataRequest(
      endpoint: endpoint,
      version: version,
      method: method,
      mimeType: mimeType,
      filename: filename,
      data: data)
    let (data, httpResponse) = try await urlSession.data(for: request)
    logResponseOnError(httpResponse: httpResponse, data: data)
    do {
      return try decoder.decode(Entity.self, from: data)
    } catch {
      if let serverError = try? decoder.decode(ServerError.self, from: data) {
        throw serverError
      }
      throw error
    }
  }

  /// 上传媒体文件并解码响应（带进度回调）
  ///
  /// - Parameters:
  ///   - endpoint: 媒体上传端点
  ///   - version: API 版本（通常使用 v2）
  ///   - method: HTTP 方法（通常是 "POST"）
  ///   - mimeType: 文件的 MIME 类型
  ///   - filename: 文件名
  ///   - data: 文件数据
  ///   - progressHandler: 上传进度回调（0.0 到 1.0）
  /// - Returns: 解码后的媒体附件对象
  /// - Throws: 网络错误、解码错误或服务器错误
  ///
  /// 使用示例：
  /// ```swift
  /// // 上传视频并显示进度
  /// @State private var uploadProgress: Double = 0
  ///
  /// let videoData = try Data(contentsOf: videoURL)
  /// let attachment: MediaAttachment = try await client.mediaUpload(
  ///     endpoint: Media.medias,
  ///     version: .v2,
  ///     method: "POST",
  ///     mimeType: "video/mp4",
  ///     filename: "video.mp4",
  ///     data: videoData,
  ///     progressHandler: { progress in
  ///         await MainActor.run {
  ///             uploadProgress = progress
  ///         }
  ///     }
  /// )
  ///
  /// // 在 UI 中显示进度
  /// ProgressView(value: uploadProgress) {
  ///     Text("上传中... \(Int(uploadProgress * 100))%")
  /// }
  /// ```
  ///
  /// 进度回调：
  /// - 在上传过程中多次调用
  /// - 参数是 0.0（开始）到 1.0（完成）的进度值
  /// - 回调在后台线程执行，更新 UI 需要切换到主线程
  ///
  /// - Note: 适用于大文件上传，提供用户反馈
  /// - SeeAlso: `UploadProgressDelegate` 处理进度回调
  public func mediaUpload<Entity: Decodable>(
    endpoint: Endpoint,
    version: Version,
    method: String,
    mimeType: String,
    filename: String,
    data: Data,
    progressHandler: @escaping @Sendable (Double) -> Void
  ) async throws -> Entity {
    let request = try makeFormDataRequest(
      endpoint: endpoint,
      version: version,
      method: method,
      mimeType: mimeType,
      filename: filename,
      data: data)
    
    let (data, httpResponse) = try await urlSession.upload(for: request, from: request.httpBody!, delegate: UploadProgressDelegate(progressHandler: progressHandler))
    logResponseOnError(httpResponse: httpResponse, data: data)
    do {
      return try decoder.decode(Entity.self, from: data)
    } catch {
      if let serverError = try? decoder.decode(ServerError.self, from: data) {
        throw serverError
      }
      throw error
    }
  }

  public func mediaUpload(
    endpoint: Endpoint,
    version: Version,
    method: String,
    mimeType: String,
    filename: String,
    data: Data
  ) async throws -> HTTPURLResponse? {
    let request = try makeFormDataRequest(
      endpoint: endpoint,
      version: version,
      method: method,
      mimeType: mimeType,
      filename: filename,
      data: data)
    let (_, httpResponse) = try await urlSession.data(for: request)
    return httpResponse as? HTTPURLResponse
  }

  public func mediaUpload(
    endpoint: Endpoint,
    version: Version,
    method: String,
    mimeType: String,
    filename: String,
    data: Data,
    progressHandler: @escaping @Sendable (Double) -> Void
  ) async throws -> HTTPURLResponse? {
    let request = try makeFormDataRequest(
      endpoint: endpoint,
      version: version,
      method: method,
      mimeType: mimeType,
      filename: filename,
      data: data)
    let (_, httpResponse) = try await urlSession.upload(for: request, from: request.httpBody!, delegate: UploadProgressDelegate(progressHandler: progressHandler))
    return httpResponse as? HTTPURLResponse
  }

  private func makeFormDataRequest(
    endpoint: Endpoint,
    version: Version,
    method: String,
    mimeType: String,
    filename: String,
    data: Data
  ) throws -> URLRequest {
    let url = try makeURL(endpoint: endpoint, forceVersion: version)
    var request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: method)
    let boundary = UUID().uuidString
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    let httpBody = NSMutableData()
    httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
    httpBody.append(
      "Content-Disposition: form-data; name=\"\(filename)\"; filename=\"\(filename)\"\r\n".data(
        using: .utf8)!)
    httpBody.append("Content-Type: \(mimeType)\r\n".data(using: .utf8)!)
    httpBody.append("\r\n".data(using: .utf8)!)
    httpBody.append(data)
    httpBody.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = httpBody as Data
    return request
  }

  private func logResponseOnError(httpResponse: URLResponse, data: Data) {
    if let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode > 299 {
      let error =
        "HTTP Response error: \(httpResponse.statusCode), response: \(httpResponse), data: \(String(data: data, encoding: .utf8) ?? "")"
      logger.error("\(error)")
    }
  }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
  private let progressHandler: @Sendable (Double) -> Void
  
  init(progressHandler: @escaping @Sendable (Double) -> Void) {
    self.progressHandler = progressHandler
  }
  
  func urlSession(_ session: URLSession,
                  task: URLSessionTask,
                  didSendBodyData bytesSent: Int64,
                  totalBytesSent: Int64,
                  totalBytesExpectedToSend: Int64) {
    guard totalBytesExpectedToSend > 0 else { return }
    let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
    progressHandler(progress)
  }
}
