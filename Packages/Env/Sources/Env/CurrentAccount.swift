// 文件功能：当前账户管理
//
// 核心职责：
// - 管理当前登录账户的信息和状态
// - 缓存账户数据，提高性能
// - 获取和管理用户的列表、标签、关注请求
// - 提供账户相关的操作接口
// - 作为全局单例，在整个应用中共享
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架，支持 SwiftUI 响应式更新
// - @MainActor：确保所有操作在主线程执行，保证 UI 安全
// - 单例模式：全局共享的账户状态
// - 账户缓存：使用静态字典缓存账户信息
// - 并发获取：使用 TaskGroup 并行获取多个数据
//
// 使用场景：
// - 在 SwiftUI 视图中通过 @Environment 注入
// - 显示当前用户信息
// - 管理用户的列表和标签
// - 处理关注请求
//
// 依赖关系：
// - 依赖：Foundation, Models, NetworkClient, Observation
// - 被依赖：所有需要访问当前账户信息的视图

import Combine
import Foundation
import Models
import NetworkClient
import Observation

/// 当前账户管理类
///
/// 管理当前登录用户的账户信息和相关数据。
///
/// 主要功能：
/// - **账户管理**：获取和缓存当前账户信息
/// - **列表管理**：获取、创建、删除用户列表
/// - **标签管理**：获取、关注、取消关注标签
/// - **关注请求**：处理关注请求的批准和拒绝
/// - **数据同步**：自动获取和更新用户数据
///
/// 设计模式：
/// - **单例模式**：全局共享的账户状态
/// - **观察者模式**：使用 @Observable，视图自动响应变化
/// - **主线程执行**：使用 @MainActor，确保 UI 安全
/// - **缓存策略**：静态缓存账户信息，减少网络请求
///
/// 使用示例：
/// ```swift
/// // 在 SwiftUI 视图中使用
/// struct ProfileView: View {
///     @Environment(CurrentAccount.self) private var currentAccount
///
///     var body: some View {
///         if let account = currentAccount.account {
///             Text("欢迎，\(account.displayName)")
///             Text("关注者：\(account.followersCount)")
///         }
///     }
/// }
///
/// // 获取用户列表
/// let lists = currentAccount.sortedLists
/// ForEach(lists) { list in
///     Text(list.title)
/// }
///
/// // 关注标签
/// await currentAccount.followTag(id: "swift")
///
/// // 处理关注请求
/// await currentAccount.acceptFollowerRequest(id: "123")
/// ```
///
/// 生命周期：
/// 1. 应用启动时创建单例
/// 2. 用户登录后调用 `setClient()`
/// 3. 自动获取用户数据
/// 4. 视图通过 @Environment 访问
/// 5. 用户注销时清空数据
///
/// - Note: 所有操作都在主线程执行，可以安全地更新 UI
/// - Warning: 必须先调用 `setClient()` 才能使用其他功能
/// - SeeAlso: `MastodonClient` 提供网络请求功能
@MainActor
@Observable public class CurrentAccount {
  /// 账户缓存
  ///
  /// 静态字典，缓存不同客户端的账户信息。
  ///
  /// 缓存策略：
  /// - 键：客户端 ID（server + token）
  /// - 值：Account 对象
  /// - 减少重复的网络请求
  /// - 跨会话保持数据
  private static var accountsCache: [String: Account] = [:]

  /// 当前账户信息
  ///
  /// 当前登录用户的完整账户信息。
  ///
  /// 状态：
  /// - nil: 未登录或正在加载
  /// - Account: 已登录，包含完整信息
  ///
  /// 使用场景：
  /// - 显示用户头像和名称
  /// - 显示关注者和关注数
  /// - 检查账户设置
  public private(set) var account: Account?
  
  /// 用户的列表
  ///
  /// 当前用户创建的所有列表。
  ///
  /// 使用场景：
  /// - 显示列表选择器
  /// - 列表管理界面
  /// - 侧边栏导航
  public private(set) var lists: [List] = []
  
  /// 关注的标签
  ///
  /// 当前用户关注的所有标签。
  ///
  /// 使用场景：
  /// - 显示关注的标签列表
  /// - 快速访问标签时间线
  /// - 标签管理
  public private(set) var tags: [Tag] = []
  
  /// 关注请求列表
  ///
  /// 待处理的关注请求（仅锁定账户）。
  ///
  /// 使用场景：
  /// - 显示待批准的关注请求
  /// - 关注请求管理界面
  public private(set) var followRequests: [Account] = []
  
  /// 是否正在更新
  ///
  /// 标记是否有数据更新操作正在进行。
  public private(set) var isUpdating: Bool = false
  
  /// 正在处理的关注请求 ID 集合
  ///
  /// 用于防止重复操作和显示加载状态。
  public private(set) var updatingFollowRequestAccountIds = Set<String>()
  
  /// 是否正在加载账户信息
  ///
  /// 用于显示加载指示器。
  public private(set) var isLoadingAccount: Bool = false

  /// Mastodon 客户端
  ///
  /// 用于执行所有 API 请求。
  private var client: MastodonClient?

  /// 全局单例
  ///
  /// 在整个应用中共享的唯一实例。
  ///
  /// 使用方式：
  /// ```swift
  /// // 在应用启动时注入
  /// @State private var currentAccount = CurrentAccount.shared
  ///
  /// var body: some Scene {
  ///     WindowGroup {
  ///         ContentView()
  ///             .environment(currentAccount)
  ///     }
  /// }
  /// ```
  public static let shared = CurrentAccount()

  /// 排序后的列表
  ///
  /// 按标题字母顺序排序的列表。
  ///
  /// 排序规则：
  /// - 不区分大小写
  /// - 字母顺序
  ///
  /// 使用场景：
  /// - 在 UI 中显示有序的列表
  public var sortedLists: [List] {
    lists.sorted { $0.title.lowercased() < $1.title.lowercased() }
  }

  /// 排序后的标签
  ///
  /// 按标签名称字母顺序排序的标签。
  ///
  /// 排序规则：
  /// - 不区分大小写
  /// - 字母顺序
  ///
  /// 使用场景：
  /// - 在 UI 中显示有序的标签
  public var sortedTags: [Tag] {
    tags.sorted { $0.name.lowercased() < $1.name.lowercased() }
  }

  /// 私有初始化
  ///
  /// 防止外部创建实例，确保单例模式。
  private init() {}

  public func setClient(client: MastodonClient) {
    self.client = client
    guard client.isAuth else { return }
    Task(priority: .userInitiated) {
      await fetchUserData()
    }
  }

  private func fetchUserData() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.fetchCurrentAccount() }
      group.addTask { await self.fetchConnections() }
      group.addTask { await self.fetchLists() }
      group.addTask { await self.fetchFollowedTags() }
      group.addTask { await self.fetchFollowerRequests() }
    }
  }

  public func fetchConnections() async {
    guard let client else { return }
    do {
      let connections: [String] = try await client.get(endpoint: Instances.peers)
      client.addConnections(connections)
    } catch {}
  }

  public func fetchCurrentAccount() async {
    guard let client, client.isAuth else {
      account = nil
      return
    }
    account = Self.accountsCache[client.id]
    if account == nil {
      isLoadingAccount = true
    }
    account = try? await client.get(endpoint: Accounts.verifyCredentials)
    isLoadingAccount = false
    Self.accountsCache[client.id] = account
  }

  public func fetchLists() async {
    guard let client, client.isAuth else { return }
    do {
      lists = try await client.get(endpoint: Lists.lists)
    } catch {
      lists = []
    }
  }

  public func fetchFollowedTags() async {
    guard let client, client.isAuth else { return }
    do {
      tags = try await client.get(endpoint: Accounts.followedTags)
    } catch {
      tags = []
    }
  }

  public func deleteList(_ list: Models.List) async {
    guard let client else { return }
    lists.removeAll(where: { $0.id == list.id })
    let response = try? await client.delete(endpoint: Lists.list(id: list.id))
    if response?.statusCode != 200 {
      lists.append(list)
    }
  }

  public func followTag(id: String) async -> Tag? {
    guard let client else { return nil }
    do {
      let tag: Tag = try await client.post(endpoint: Tags.follow(id: id))
      tags.append(tag)
      return tag
    } catch {
      return nil
    }
  }

  public func unfollowTag(id: String) async -> Tag? {
    guard let client else { return nil }
    do {
      let tag: Tag = try await client.post(endpoint: Tags.unfollow(id: id))
      tags.removeAll { $0.id == tag.id }
      return tag
    } catch {
      return nil
    }
  }

  public func fetchFollowerRequests() async {
    guard let client else { return }
    do {
      followRequests = try await client.get(endpoint: FollowRequests.list)
    } catch {
      followRequests = []
    }
  }

  public func acceptFollowerRequest(id: String) async {
    guard let client else { return }
    do {
      updatingFollowRequestAccountIds.insert(id)
      defer {
        updatingFollowRequestAccountIds.remove(id)
      }
      _ = try await client.post(endpoint: FollowRequests.accept(id: id))
      await fetchFollowerRequests()
    } catch {}
  }

  public func rejectFollowerRequest(id: String) async {
    guard let client else { return }
    do {
      updatingFollowRequestAccountIds.insert(id)
      defer {
        updatingFollowRequestAccountIds.remove(id)
      }
      _ = try await client.post(endpoint: FollowRequests.reject(id: id))
      await fetchFollowerRequests()
    } catch {}
  }
}
