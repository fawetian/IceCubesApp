/*
 * TimelineFilter.swift
 * IceCubesApp - 时间线过滤器枚举
 *
 * 文件功能：
 * 定义所有可用的时间线类型和远程实例时间线过滤器。
 *
 * 核心职责：
 * - 枚举所有时间线类型（主页、本地、联邦、标签、列表等）
 * - 提供每种时间线的标题、图标和本地化
 * - 根据过滤器生成对应的 API 端点
 * - 判断时间线是否支持特定功能（分页、未读等）
 *
 * 技术要点：
 * - Hashable + Identifiable + Sendable 协议支持
 * - 关联值存储标签、列表、服务器等参数
 * - 自定义 id 和 hash 实现
 * - 条件判断支持的分页模式
 *
 * 使用场景：
 * - TimelineView 的过滤器参数
 * - 导航栏下拉菜单选择
 * - 快捷访问 Pills 显示
 *
 * 依赖关系：
 * - Models: List、Tag 等数据模型
 * - NetworkClient: Endpoint、Timelines、Statuses
 */

import Foundation
import Models
import NetworkClient
import SwiftUI

/// 远程实例时间线过滤器。
///
/// 用于浏览其他 Mastodon 实例的时间线。
public enum RemoteTimelineFilter: String, CaseIterable, Hashable, Equatable, Sendable {
  /// 本地时间线（仅本实例的帖子）。
  case local
  /// 联邦时间线（本实例及关联实例的帖子）。
  case federated
  /// 趋势时间线（热门帖子）。
  case trending

  /// 返回本地化标题。
  public func localizedTitle() -> LocalizedStringKey {
    switch self {
    case .federated:
      "timeline.federated"
    case .local:
      "timeline.local"
    case .trending:
      "timeline.trending"
    }
  }

  /// 返回图标名称（SF Symbols）。
  public func iconName() -> String {
    switch self {
    case .federated:
      "globe.americas"
    case .local:
      "person.2"
    case .trending:
      "chart.line.uptrend.xyaxis"
    }
  }
}

/// 时间线过滤器。
///
/// 定义所有可用的时间线类型，包括主页、本地、联邦、标签、列表等。
public enum TimelineFilter: Hashable, Equatable, Identifiable, Sendable {
  /// 主页时间线（关注的账号）。
  case home
  /// 本地时间线（仅本实例）。
  case local
  /// 联邦时间线（所有联邦实例）。
  case federated
  /// 趋势时间线（热门帖子）。
  case trending
  /// 标签时间线（指定标签的帖子）。
  case hashtag(tag: String, accountId: String?)
  /// 标签组时间线（多个标签）。
  case tagGroup(title: String, tags: [String], symbolName: String?)
  /// 列表时间线（用户自定义列表）。
  case list(list: Models.List)
  /// 远程实例时间线（浏览其他实例）。
  case remoteLocal(server: String, filter: RemoteTimelineFilter)
  /// 链接时间线（自定义 URL）。
  case link(url: URL, title: String)
  /// 引用时间线（某条帖子的所有引用）。
  case quotes(statusId: String)
  /// 特殊：刷新到最新。
  case latest
  /// 特殊：恢复到断点位置。
  case resume

  /// 相等性判断（基于 ID）。
  public static func == (lhs: TimelineFilter, rhs: TimelineFilter) -> Bool {
    lhs.id == rhs.id
  }

  /// 唯一标识符（用于 Identifiable 协议）。
  public var id: String {
    switch self {
    case .remoteLocal(let server, let filter):
      return server + filter.rawValue
    case .list(let list):
      return list.id
    case .tagGroup(let title, let tags, _):
      return title + tags.joined()
    case .link(let url, _):
      return url.absoluteString
    case .quotes(let statusId):
      return "quotes" + statusId
    default:
      return title
    }
  }

  /// Hash 实现（基于 ID）。
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  /// 根据客户端状态返回可用的时间线列表。
  ///
  /// - Parameter client: Mastodon 客户端。
  /// - Returns: 可用的时间线过滤器数组。
  public static func availableTimeline(client: MastodonClient) -> [TimelineFilter] {
    if !client.isAuth {
      return [.local, .federated, .trending]
    }
    return [.home, .local, .federated, .trending]
  }

  /// 是否支持最新分页模式（从最新帖子向上拉取）。
  public var supportNewestPagination: Bool {
    switch self {
    case .trending:
      false
    case .remoteLocal(_, let filter):
      filter != .trending
    default:
      true
    }
  }

  /// 返回过滤器的显示标题（英文）。
  public var title: String {
    switch self {
    case .latest:
      "Latest"
    case .resume:
      "Resume"
    case .federated:
      "Federated"
    case .local:
      "Local"
    case .trending:
      "Trending"
    case .home:
      "Home"
    case .quotes:
      "Quotes"
    case .link(_, let title):
      title
    case .hashtag(let tag, _):
      "#\(tag)"
    case .tagGroup(let title, _, _):
      title
    case .list(let list):
      list.title
    case .remoteLocal(let server, _):
      server
    }
  }

  public func localizedTitle() -> LocalizedStringKey {
    switch self {
    case .latest:
      "timeline.latest"
    case .resume:
      "timeline.resume"
    case .federated:
      "timeline.federated"
    case .local:
      "timeline.local"
    case .trending:
      "timeline.trending"
    case .home:
      "timeline.home"
    case .link(_, let title):
      LocalizedStringKey(title)
    case .hashtag(let tag, _):
      "#\(tag)"
    case .tagGroup(let title, _, _):
      LocalizedStringKey(title)  // ?? not sure since this can't be localized.
    case .list(let list):
      LocalizedStringKey(list.title)
    case .remoteLocal(let server, _):
      LocalizedStringKey(server)
    case .quotes:
      "Quotes"
    }
  }

  public func iconName() -> String {
    switch self {
    case .latest:
      "arrow.counterclockwise"
    case .resume:
      "clock.arrow.2.circlepath"
    case .federated:
      "globe.americas"
    case .local:
      "person.2"
    case .trending:
      "chart.line.uptrend.xyaxis"
    case .home:
      "house"
    case .list:
      "list.bullet"
    case .remoteLocal:
      "dot.radiowaves.right"
    case .tagGroup(_, _, let symbolName):
      symbolName ?? "tag"
    case .hashtag:
      "number"
    case .link:
      "link"
    case .quotes:
      "quote.bubble"
    }
  }

  /// 根据过滤器类型生成对应的 API 端点。
  ///
  /// - Parameters:
  ///   - sinceId: 起始 ID（向下分页）。
  ///   - maxId: 最大 ID（向上分页）。
  ///   - minId: 最小 ID（追赶未读）。
  ///   - offset: 偏移量（用于趋势等不支持 ID 分页的端点）。
  ///   - limit: 每页数量限制。
  /// - Returns: NetworkClient 的 Endpoint 对象。
  public func endpoint(
    sinceId: String?,
    maxId: String?,
    minId: String?,
    offset: Int?,
    limit: Int?
  ) -> Endpoint {
    switch self {
    case .federated:
      return Timelines.pub(sinceId: sinceId, maxId: maxId, minId: minId, local: false, limit: limit)
    case .local:
      return Timelines.pub(sinceId: sinceId, maxId: maxId, minId: minId, local: true, limit: limit)
    case .remoteLocal(_, let filter):
      switch filter {
      case .local:
        return Timelines.pub(
          sinceId: sinceId, maxId: maxId, minId: minId, local: true, limit: limit)
      case .federated:
        return Timelines.pub(
          sinceId: sinceId, maxId: maxId, minId: minId, local: false, limit: limit)
      case .trending:
        return Trends.statuses(offset: offset)
      }
    case .quotes(let statusId):
      return Statuses.quotesBy(id: statusId, maxId: maxId)
    case .latest: return Timelines.home(sinceId: nil, maxId: nil, minId: nil, limit: limit)
    case .resume: return Timelines.home(sinceId: nil, maxId: nil, minId: nil, limit: limit)
    case .home: return Timelines.home(sinceId: sinceId, maxId: maxId, minId: minId, limit: limit)
    case .trending: return Trends.statuses(offset: offset)
    case .link(let url, _):
      return Timelines.link(url: url, sinceId: sinceId, maxId: maxId, minId: minId)
    case .list(let list):
      return Timelines.list(listId: list.id, sinceId: sinceId, maxId: maxId, minId: minId)
    case .hashtag(let tag, let accountId):
      if let accountId {
        return Accounts.statuses(
          id: accountId,
          sinceId: nil,
          tag: tag,
          onlyMedia: false,
          excludeReplies: false,
          excludeReblogs: false,
          pinned: nil)
      } else {
        return Timelines.hashtag(tag: tag, additional: nil, maxId: maxId, minId: minId)
      }
    case .tagGroup(_, let tags, _):
      var tags = tags
      if !tags.isEmpty {
        let tag = tags.removeFirst()
        return Timelines.hashtag(tag: tag, additional: tags, maxId: maxId, minId: minId)
      } else {
        return Timelines.hashtag(tag: "", additional: tags, maxId: maxId, minId: minId)
      }
    }
  }
}

extension TimelineFilter: Codable {
  enum CodingKeys: String, CodingKey {
    case home
    case local
    case federated
    case trending
    case hashtag
    case tagGroup
    case list
    case remoteLocal
    case latest
    case resume
    case link
    case quotes
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = container.allKeys.first
    switch key {
    case .home:
      self = .home
    case .local:
      self = .local
    case .federated:
      self = .federated
    case .trending:
      self = .trending
    case .hashtag:
      var nestedContainer = try container.nestedUnkeyedContainer(forKey: .hashtag)
      let tag = try nestedContainer.decode(String.self)
      let accountId = try nestedContainer.decode(String?.self)
      self = .hashtag(
        tag: tag,
        accountId: accountId
      )
    case .tagGroup:
      var nestedContainer = try container.nestedUnkeyedContainer(forKey: .tagGroup)
      let title = try nestedContainer.decode(String.self)
      let tags = try nestedContainer.decode([String].self)
      let symbolName = try? nestedContainer.decode(String.self)
      self = .tagGroup(
        title: title,
        tags: tags,
        symbolName: symbolName
      )
    case .list:
      let list = try container.decode(
        Models.List.self,
        forKey: .list
      )
      self = .list(list: list)
    case .quotes:
      let id = try container.decode(
        String.self,
        forKey: .quotes
      )
      self = .quotes(statusId: id)
    case .remoteLocal:
      var nestedContainer = try container.nestedUnkeyedContainer(forKey: .remoteLocal)
      let server = try nestedContainer.decode(String.self)
      let filter = try nestedContainer.decode(RemoteTimelineFilter.self)
      self = .remoteLocal(
        server: server,
        filter: filter
      )
    case .latest:
      self = .latest
    case .link:
      var nestedContainer = try container.nestedUnkeyedContainer(forKey: .link)
      let url = try nestedContainer.decode(URL.self)
      let title = try nestedContainer.decode(String.self)
      self = .link(url: url, title: title)
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Unabled to decode enum."
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .home:
      try container.encode(CodingKeys.home.rawValue, forKey: .home)
    case .local:
      try container.encode(CodingKeys.local.rawValue, forKey: .local)
    case .federated:
      try container.encode(CodingKeys.federated.rawValue, forKey: .federated)
    case .trending:
      try container.encode(CodingKeys.trending.rawValue, forKey: .trending)
    case .hashtag(let tag, let accountId):
      var nestedContainer = container.nestedUnkeyedContainer(forKey: .hashtag)
      try nestedContainer.encode(tag)
      try nestedContainer.encode(accountId)
    case .tagGroup(let title, let tags, let symbolName):
      var nestedContainer = container.nestedUnkeyedContainer(forKey: .tagGroup)
      try nestedContainer.encode(title)
      try nestedContainer.encode(tags)
      try? nestedContainer.encode(symbolName)
    case .list(let list):
      try container.encode(list, forKey: .list)
    case .quotes(let id):
      try container.encode(id, forKey: .quotes)
    case .remoteLocal(let server, let filter):
      var nestedContainer = container.nestedUnkeyedContainer(forKey: .remoteLocal)
      try nestedContainer.encode(server)
      try nestedContainer.encode(filter)
    case .latest:
      try container.encode(CodingKeys.latest.rawValue, forKey: .latest)
    case .resume:
      try container.encode(CodingKeys.resume.rawValue, forKey: .latest)
    case .link(let url, let title):
      var nestedContainer = container.nestedUnkeyedContainer(forKey: .link)
      try nestedContainer.encode(url)
      try nestedContainer.encode(title)
    }
  }
}

extension TimelineFilter: RawRepresentable {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
      let result = try? JSONDecoder().decode(TimelineFilter.self, from: data)
    else {
      return nil
    }
    self = result
  }

  public var rawValue: String {
    guard let data = try? JSONEncoder().encode(self),
      let result = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return result
  }
}

extension RemoteTimelineFilter: Codable {
  enum CodingKeys: String, CodingKey {
    case local
    case federated
    case trending
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = container.allKeys.first
    switch key {
    case .local:
      self = .local
    case .federated:
      self = .federated
    case .trending:
      self = .trending
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Unabled to decode enum."
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .local:
      try container.encode(CodingKeys.local.rawValue, forKey: .local)
    case .federated:
      try container.encode(CodingKeys.federated.rawValue, forKey: .federated)
    case .trending:
      try container.encode(CodingKeys.trending.rawValue, forKey: .trending)
    }
  }
}

extension RemoteTimelineFilter: RawRepresentable {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
      let result = try? JSONDecoder().decode(RemoteTimelineFilter.self, from: data)
    else {
      return nil
    }
    self = result
  }

  public var rawValue: String {
    guard let data = try? JSONEncoder().encode(self),
      let result = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return result
  }
}
