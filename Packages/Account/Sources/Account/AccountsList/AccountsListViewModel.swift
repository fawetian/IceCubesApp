/*
 * AccountsListViewModel.swift
 * IceCubesApp - 账户列表视图模型
 *
 * 文件功能：
 * 管理账户列表的加载、分页和搜索逻辑。
 *
 * 核心职责：
 * - 根据模式加载不同类型的账户列表（关注者、正在关注、屏蔽等）
 * - 支持分页加载
 * - 处理账户关系状态
 * - 提供搜索功能（仅限关注列表）
 *
 * 技术要点：
 * - @Observable 管理状态
 * - 支持多种列表模式
 * - 分页处理（LinkHandler）
 * - 关系批量查询
 * - 防抖搜索（250ms）
 *
 * 使用场景：
 * - AccountsListView 的数据管理
 * - 账户详情页的关注者/正在关注列表
 * - 帖子的点赞/转发用户列表
 * - 屏蔽/静音列表
 *
 * 依赖关系：
 * - Models: Account、Relationship
 * - NetworkClient: Accounts、Statuses、Search 端点
 */

import Models
import NetworkClient
import OSLog
import Observation
import SwiftUI

/// 账户列表模式枚举。
///
/// 定义不同类型的账户列表加载方式。
public enum AccountsListMode {
  /// 正在关注列表（指定账户）。
  case following(accountId: String)
  /// 关注者列表（指定账户）。
  case followers(accountId: String)
  /// 点赞用户列表（指定帖子）。
  case favoritedBy(statusId: String)
  /// 转发用户列表（指定帖子）。
  case rebloggedBy(statusId: String)
  /// 预定义账户列表。
  case accountsList(accounts: [Account])
  /// 屏蔽列表。
  case blocked
  /// 静音列表。
  case muted

  /// 列表标题。
  var title: LocalizedStringKey {
    switch self {
    case .following:
      "account.following"
    case .followers:
      "account.followers"
    case .favoritedBy:
      "account.favorited-by"
    case .rebloggedBy:
      "account.boosted-by"
    case .accountsList:
      ""
    case .blocked:
      "account.blocked"
    case .muted:
      "account.muted"
    }
  }
}

/// 账户列表视图模型。
///
/// 管理账户列表的数据加载和状态。
@MainActor
@Observable class AccountsListViewModel {
  /// Mastodon 客户端。
  var client: MastodonClient?

  /// 列表模式。
  let mode: AccountsListMode

  /// 视图状态枚举。
  public enum State {
    /// 分页状态枚举。
    public enum PagingState {
      /// 有下一页。
      case hasNextPage
      /// 无下一页。
      case none
    }

    /// 加载中。
    case loading
    /// 已加载（账户列表、关系列表、分页状态）。
    case display(
      accounts: [Account],
      relationships: [Relationship],
      nextPageState: PagingState)
    /// 加载错误。
    case error(error: Error)
  }

  /// 账户列表（内部存储）。
  private var accounts: [Account] = []
  /// 关系列表（内部存储）。
  private var relationships: [Relationship] = []

  /// 当前视图状态。
  var state = State.loading
  /// 账户总数（仅关注者/正在关注模式）。
  var totalCount: Int?
  /// 账户 ID（用于搜索关注列表）。
  var accountId: String?

  /// 搜索查询字符串。
  var searchQuery: String = ""

  /// 下一页 ID（用于分页）。
  private var nextPageId: String?

  /// 初始化方法。
  ///
  /// - Parameter mode: 列表模式。
  init(mode: AccountsListMode) {
    self.mode = mode
  }

  /// 拉取账户列表（首次加载）。
  ///
  /// 根据模式加载对应的账户列表和关系状态。
  func fetch() async {
    guard let client else { return }
    do {
      state = .loading
      let link: LinkHandler?
      switch mode {
      case .followers(let accountId):
        let account: Account = try await client.get(endpoint: Accounts.accounts(id: accountId))
        totalCount = account.followersCount
        (accounts, link) = try await client.getWithLink(
          endpoint: Accounts.followers(
            id: accountId,
            maxId: nil))
      case .following(let accountId):
        self.accountId = accountId
        let account: Account = try await client.get(endpoint: Accounts.accounts(id: accountId))
        totalCount = account.followingCount
        (accounts, link) = try await client.getWithLink(
          endpoint: Accounts.following(
            id: accountId,
            maxId: nil))
      case .rebloggedBy(let statusId):
        (accounts, link) = try await client.getWithLink(
          endpoint: Statuses.rebloggedBy(
            id: statusId,
            maxId: nil))
      case .favoritedBy(let statusId):
        (accounts, link) = try await client.getWithLink(
          endpoint: Statuses.favoritedBy(
            id: statusId,
            maxId: nil))
      case .accountsList(let accounts):
        self.accounts = accounts
        link = nil

      case .blocked:
        (accounts, link) = try await client.getWithLink(endpoint: Accounts.blockList)

      case .muted:
        (accounts, link) = try await client.getWithLink(endpoint: Accounts.muteList)
      }
      nextPageId = link?.maxId
      relationships = try await client.get(
        endpoint:
          Accounts.relationships(ids: accounts.map(\.id)))
      state = .display(
        accounts: accounts,
        relationships: relationships,
        nextPageState: link?.maxId != nil ? .hasNextPage : .none)
    } catch {}
  }

  /// 拉取下一页账户列表。
  ///
  /// 使用 nextPageId 加载更多账户。
  func fetchNextPage() async throws {
    guard let client, let nextPageId else { return }
    let newAccounts: [Account]
    let link: LinkHandler?
    switch mode {
    case .followers(let accountId):
      (newAccounts, link) = try await client.getWithLink(
        endpoint: Accounts.followers(
          id: accountId,
          maxId: nextPageId))
    case .following(let accountId):
      (newAccounts, link) = try await client.getWithLink(
        endpoint: Accounts.following(
          id: accountId,
          maxId: nextPageId))
    case .rebloggedBy(let statusId):
      (newAccounts, link) = try await client.getWithLink(
        endpoint: Statuses.rebloggedBy(
          id: statusId,
          maxId: nextPageId))
    case .favoritedBy(let statusId):
      (newAccounts, link) = try await client.getWithLink(
        endpoint: Statuses.favoritedBy(
          id: statusId,
          maxId: nextPageId))
    case .accountsList:
      newAccounts = []
      link = nil

    case .blocked:
      (newAccounts, link) = try await client.getWithLink(endpoint: Accounts.blockList)

    case .muted:
      (newAccounts, link) = try await client.getWithLink(endpoint: Accounts.muteList)
    }

    accounts.append(contentsOf: newAccounts)
    let newRelationships: [Relationship] =
      try await client.get(endpoint: Accounts.relationships(ids: newAccounts.map(\.id)))

    relationships.append(contentsOf: newRelationships)
    self.nextPageId = link?.maxId
    state = .display(
      accounts: accounts,
      relationships: relationships,
      nextPageState: link?.maxId != nil ? .hasNextPage : .none)
  }

  /// 搜索账户（仅关注列表支持）。
  ///
  /// 使用防抖延迟 250ms 搜索当前用户的关注列表。
  func search() async {
    guard let client, !searchQuery.isEmpty else { return }
    do {
      state = .loading
      try await Task.sleep(for: .milliseconds(250))
      var results: SearchResults = try await client.get(
        endpoint: Search.search(
          query: searchQuery,
          type: .accounts,
          offset: nil,
          following: true),
        forceVersion: .v2)
      let relationships: [Relationship] =
        try await client.get(endpoint: Accounts.relationships(ids: results.accounts.map(\.id)))
      results.relationships = relationships
      withAnimation {
        state = .display(
          accounts: results.accounts,
          relationships: relationships,
          nextPageState: .none)
      }
    } catch {}
  }
}
