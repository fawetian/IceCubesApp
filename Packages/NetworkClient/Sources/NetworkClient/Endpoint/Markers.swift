// 文件功能：Mastodon 阅读位置标记 API 端点定义
//
// 核心职责：
// - 定义阅读位置标记的 API 端点
// - 支持获取和更新阅读位置
// - 跨设备同步阅读进度
//
// 技术要点：
// - Markers：枚举类型，定义标记操作
// - MarkerPayload：标记数据结构
// - 支持主页和通知的阅读位置
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：TimelineView, NotificationsView, MastodonClient

import Foundation

/// Mastodon 阅读位置标记 API 端点
///
/// 定义了管理阅读位置的操作。
///
/// 阅读位置标记：
/// - 记录用户在时间线中的阅读位置
/// - 跨设备同步阅读进度
/// - 支持主页时间线和通知
/// - 自动滚动到上次阅读位置
///
/// 使用示例：
/// ```swift
/// // 获取阅读位置
/// let markers: [String: Marker] = try await client.get(
///     endpoint: Markers.markers
/// )
///
/// if let homeMarker = markers["home"] {
///     print("主页最后阅读：\(homeMarker.lastReadId)")
/// }
///
/// // 更新主页阅读位置
/// try await client.post(
///     endpoint: Markers.markHome(lastReadId: "123456")
/// )
///
/// // 更新通知阅读位置
/// try await client.post(
///     endpoint: Markers.markNotifications(lastReadId: "789012")
/// )
/// ```
///
/// 工作原理：
/// 1. 用户滚动时间线
/// 2. 记录最后可见的帖子 ID
/// 3. 定期更新到服务器
/// 4. 其他设备获取标记
/// 5. 自动滚动到标记位置
public enum Markers: Endpoint {
  /// 获取阅读位置标记
  ///
  /// 返回：字典，键为时间线类型，值为 Marker 对象
  ///
  /// 支持的时间线：
  /// - "home": 主页时间线
  /// - "notifications": 通知列表
  ///
  /// Marker 包含：
  /// - lastReadId: 最后阅读的帖子/通知 ID
  /// - version: 版本号
  /// - updatedAt: 更新时间
  ///
  /// 使用场景：
  /// - 应用启动时获取阅读位置
  /// - 跨设备同步
  /// - 显示未读数量
  ///
  /// API 路径：`/api/v1/markers`
  /// HTTP 方法：GET
  case markers
  
  /// 更新通知阅读位置
  ///
  /// - Parameter lastReadId: 最后阅读的通知 ID
  ///
  /// 更新后：
  /// - 服务器记录新的阅读位置
  /// - 其他设备可以同步
  /// - 用于计算未读数量
  ///
  /// 使用场景：
  /// - 用户查看通知时
  /// - 定期更新阅读进度
  /// - 标记为已读
  ///
  /// API 路径：`/api/v1/markers`
  /// HTTP 方法：POST
  case markNotifications(lastReadId: String)
  
  /// 更新主页阅读位置
  ///
  /// - Parameter lastReadId: 最后阅读的帖子 ID
  ///
  /// 更新后：
  /// - 服务器记录新的阅读位置
  /// - 其他设备可以同步
  /// - 下次打开时滚动到此位置
  ///
  /// 使用场景：
  /// - 用户滚动主页时
  /// - 定期更新阅读进度
  /// - 跨设备同步
  ///
  /// API 路径：`/api/v1/markers`
  /// HTTP 方法：POST
  case markHome(lastReadId: String)

  public func path() -> String {
    "markers"
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case .markers:
      [
        URLQueryItem(name: "timeline[]", value: "home"),
        URLQueryItem(name: "timeline[]", value: "notifications"),
      ]
    case .markNotifications, .markHome:
      nil
    }
  }

  public var jsonValue: Encodable? {
    switch self {
    case .markers:
      nil
    case .markNotifications(let lastReadId):
      MarkerPayload(notifications: MarkerPayload.Marker(lastReadId: lastReadId), home: nil)
    case .markHome(let lastReadId):
      MarkerPayload(notifications: nil, home: MarkerPayload.Marker(lastReadId: lastReadId))
    }
  }
}

/// 标记数据载荷（内部使用）
private struct MarkerPayload: Encodable {
  /// 单个标记
  struct Marker: Encodable {
    /// 最后阅读的 ID
    let lastReadId: String
  }

  /// 通知标记
  let notifications: Marker?
  /// 主页标记
  let home: Marker?
}
