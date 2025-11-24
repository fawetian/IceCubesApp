// 文件功能：推送通知服务核心类
//
// 核心职责：
// - 管理应用的推送通知订阅
// - 处理推送通知的加密和解密
// - 管理多账户的推送通知设置
// - 与推送通知中继服务器通信
// - 处理通知的接收和展示
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架，支持 SwiftUI 响应式更新
// - @MainActor：确保所有 UI 相关操作在主线程执行
// - CryptoKit：使用 P256 椭圆曲线加密保护通知内容
// - KeychainSwift：安全存储加密密钥
// - UNUserNotificationCenter：处理系统通知
// - 中继服务器：使用自定义服务器转发推送通知
//
// 架构设计：
// - PushKeys：管理加密密钥的生成和存储
// - PushAccount：表示单个账户的推送配置
// - PushNotificationsService：主服务类，管理所有推送逻辑
// - PushNotificationSubscriptionSettings：单个账户的订阅设置
//
// 工作流程：
// 1. 生成或加载加密密钥对
// 2. 向系统请求推送权限
// 3. 获取设备推送令牌
// 4. 为每个账户创建订阅
// 5. 向 Mastodon 服务器注册推送端点
// 6. 接收加密的推送通知
// 7. 解密并展示通知内容
//
// 依赖关系：
// - 依赖：Foundation, Models, NetworkClient, CryptoKit, KeychainSwift
// - 被依赖：应用主类、设置页面、通知处理逻辑

import Combine
import CryptoKit
import Foundation
import KeychainSwift
import Models
import NetworkClient
import Observation
import SwiftUI
import UserNotifications

// MARK: - Sendable 扩展

/// 使 UNNotification 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递通知对象。
extension UNNotification: @unchecked @retroactive Sendable {}

/// 使 UNNotificationResponse 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递通知响应对象。
extension UNNotificationResponse: @unchecked @retroactive Sendable {}

/// 使 UNUserNotificationCenter 符合 Sendable 协议
///
/// 允许在并发上下文中安全使用通知中心。
extension UNUserNotificationCenter: @unchecked @retroactive Sendable {}

// MARK: - 推送密钥管理

/// 推送通知加密密钥管理器
///
/// 负责生成、存储和检索推送通知所需的加密密钥。
///
/// 密钥类型：
/// - **私钥**：P256 椭圆曲线私钥，用于解密推送通知
/// - **认证密钥**：随机生成的 16 字节密钥，用于验证通知来源
///
/// 存储方式：
/// - 使用 Keychain 安全存储
/// - 首次访问时自动生成
/// - 在应用卸载时自动删除
///
/// 使用场景：
/// - 订阅推送通知时提供公钥
/// - 接收推送通知时使用私钥解密
/// - 验证通知来源的真实性
///
/// 示例：
/// ```swift
/// let pushKeys = PushKeys()
/// let publicKey = pushKeys.notificationsPrivateKeyAsKey.publicKey
/// let authKey = pushKeys.notificationsAuthKeyAsKey
///
/// // 用于订阅推送通知
/// let subscription = try await client.post(
///     endpoint: Push.createSub(
///         endpoint: listenerURL,
///         p256dh: publicKey.x963Representation,
///         auth: authKey,
///         ...
///     )
/// )
/// ```
///
/// - Note: 密钥在首次访问时自动生成并存储到 Keychain
/// - Important: 私钥必须妥善保管，泄露会导致通知内容被解密
public struct PushKeys: Sendable {
  /// Keychain 存储键常量
  enum Constants {
    /// 认证密钥的 Keychain 键
    static let keychainAuthKey = "notifications_auth_key"
    /// 私钥的 Keychain 键
    static let keychainPrivateKey = "notifications_private_key"
  }

  public init() {}

  /// Keychain 实例
  ///
  /// 配置了正确的访问组，用于在应用和扩展间共享密钥。
  ///
  /// 访问组配置：
  /// - Release 模式：使用 App Group 共享
  /// - Debug/模拟器：使用默认 Keychain
  private var keychain: KeychainSwift {
    let keychain = KeychainSwift()
    #if !DEBUG && !targetEnvironment(simulator)
      keychain.accessGroup = AppInfo.keychainGroup
    #endif
    return keychain
  }

  /// 通知私钥
  ///
  /// P256 椭圆曲线私钥，用于解密推送通知内容。
  ///
  /// 获取逻辑：
  /// 1. 尝试从 Keychain 读取现有密钥
  /// 2. 如果存在，解析并返回
  /// 3. 如果不存在或解析失败，生成新密钥
  /// 4. 将新密钥保存到 Keychain
  ///
  /// 访问控制：
  /// - 设备首次解锁后可访问
  /// - 在应用和扩展间共享
  ///
  /// 使用场景：
  /// - 订阅推送时提供公钥
  /// - 接收推送时使用私钥解密
  ///
  /// - Note: 密钥在首次访问时自动生成
  /// - Important: 私钥永远不会离开设备
  public var notificationsPrivateKeyAsKey: P256.KeyAgreement.PrivateKey {
    if let key = keychain.get(Constants.keychainPrivateKey),
      let data = Data(base64Encoded: key)
    {
      do {
        return try P256.KeyAgreement.PrivateKey(rawRepresentation: data)
      } catch {
        // 解析失败，生成新密钥
        let key = P256.KeyAgreement.PrivateKey()
        keychain.set(
          key.rawRepresentation.base64EncodedString(),
          forKey: Constants.keychainPrivateKey,
          withAccess: .accessibleAfterFirstUnlock)
        return key
      }
    } else {
      // 密钥不存在，生成新密钥
      let key = P256.KeyAgreement.PrivateKey()
      keychain.set(
        key.rawRepresentation.base64EncodedString(),
        forKey: Constants.keychainPrivateKey,
        withAccess: .accessibleAfterFirstUnlock)
      return key
    }
  }

  /// 通知认证密钥
  ///
  /// 随机生成的 16 字节密钥，用于验证推送通知的来源。
  ///
  /// 获取逻辑：
  /// 1. 尝试从 Keychain 读取现有密钥
  /// 2. 如果存在，返回
  /// 3. 如果不存在，生成新的随机密钥
  /// 4. 将新密钥保存到 Keychain
  ///
  /// 访问控制：
  /// - 设备首次解锁后可访问
  /// - 在应用和扩展间共享
  ///
  /// 使用场景：
  /// - 订阅推送时提供给服务器
  /// - 验证接收到的推送通知
  ///
  /// - Note: 密钥在首次访问时自动生成
  public var notificationsAuthKeyAsKey: Data {
    if let key = keychain.get(Constants.keychainAuthKey),
      let data = Data(base64Encoded: key)
    {
      return data
    } else {
      // 密钥不存在，生成新密钥
      let key = Self.makeRandomNotificationsAuthKey()
      keychain.set(
        key.base64EncodedString(),
        forKey: Constants.keychainAuthKey,
        withAccess: .accessibleAfterFirstUnlock)
      return key
    }
  }

  /// 生成随机认证密钥
  ///
  /// 使用系统安全随机数生成器创建 16 字节的随机数据。
  ///
  /// - Returns: 16 字节的随机数据
  ///
  /// 安全性：
  /// - 使用 SecRandomCopyBytes 确保密码学安全
  /// - 每次生成的密钥都是唯一的
  ///
  /// - Note: 这是一个私有方法，只在内部使用
  private static func makeRandomNotificationsAuthKey() -> Data {
    let byteCount = 16
    var bytes = Data(count: byteCount)
    _ = bytes.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, byteCount, $0.baseAddress!)
    }
    return bytes
  }
}

// MARK: - 推送账户

/// 推送通知账户
///
/// 表示一个配置了推送通知的 Mastodon 账户。
///
/// 属性：
/// - **server**：Mastodon 实例服务器地址
/// - **token**：OAuth 访问令牌
/// - **accountName**：账户显示名称（可选）
///
/// 使用场景：
/// - 创建推送订阅
/// - 识别通知所属账户
/// - 管理多账户推送设置
///
/// 示例：
/// ```swift
/// let pushAccount = PushAccount(
///     server: "mastodon.social",
///     token: oauthToken,
///     accountName: "@user@mastodon.social"
/// )
/// ```
public struct PushAccount: Equatable {
  /// Mastodon 实例服务器地址
  ///
  /// 例如："mastodon.social"
  public let server: String
  
  /// OAuth 访问令牌
  ///
  /// 用于认证推送订阅请求。
  public let token: OauthToken
  
  /// 账户显示名称
  ///
  /// 用于在通知中显示账户信息。
  /// 格式：@username@server
  public let accountName: String?

  public init(server: String, token: OauthToken, accountName: String?) {
    self.server = server
    self.token = token
    self.accountName = accountName
  }
}

// MARK: - 已处理通知

/// 已处理的通知
///
/// 表示用户点击后已处理的推送通知。
///
/// 属性：
/// - **account**：通知所属的账户
/// - **notification**：完整的通知对象
///
/// 使用场景：
/// - 用户点击通知后跳转到对应页面
/// - 在应用中显示通知详情
/// - 标记通知为已读
///
/// 工作流程：
/// 1. 用户点击推送通知
/// 2. 解密通知内容
/// 3. 从服务器获取完整通知对象
/// 4. 创建 HandledNotification
/// 5. 应用根据通知类型跳转到对应页面
///
/// 示例：
/// ```swift
/// if let handled = PushNotificationsService.shared.handledNotification {
///     // 跳转到通知详情页
///     router.navigate(to: .notification(handled.notification))
/// }
/// ```
public struct HandledNotification: Equatable {
  /// 通知所属的账户
  public let account: PushAccount
  
  /// 完整的通知对象
  ///
  /// 包含通知类型、发送者、相关帖子等信息。
  public let notification: Models.Notification
}

// MARK: - 推送通知服务

/// 推送通知服务
///
/// 管理应用的推送通知功能，包括订阅、接收和处理通知。
///
/// 主要功能：
/// - **权限管理**：请求和管理推送通知权限
/// - **订阅管理**：为每个账户创建和更新推送订阅
/// - **通知接收**：接收和解密推送通知
/// - **通知处理**：处理用户点击通知的操作
/// - **多账户支持**：同时管理多个账户的推送通知
///
/// 架构设计：
/// - 使用中继服务器转发推送通知
/// - 端到端加密保护通知内容
/// - 支持细粒度的通知类型控制
///
/// 使用方式：
/// ```swift
/// // 请求推送权限
/// PushNotificationsService.shared.requestPushNotifications()
///
/// // 设置账户
/// let accounts = [
///     PushAccount(server: "mastodon.social", token: token1, accountName: "@user1"),
///     PushAccount(server: "mastodon.online", token: token2, accountName: "@user2")
/// ]
/// PushNotificationsService.shared.setAccounts(accounts: accounts)
///
/// // 更新订阅
/// await PushNotificationsService.shared.updateSubscriptions(forceCreate: false)
///
/// // 处理点击的通知
/// if let handled = PushNotificationsService.shared.handledNotification {
///     // 跳转到对应页面
/// }
/// ```
///
/// 工作流程：
/// 1. 请求系统推送权限
/// 2. 获取设备推送令牌
/// 3. 为每个账户创建订阅设置
/// 4. 向 Mastodon 服务器注册推送端点
/// 5. 接收加密的推送通知
/// 6. 解密并展示通知
/// 7. 处理用户点击操作
///
/// - Note: 使用单例模式，通过 `PushNotificationsService.shared` 访问
/// - Important: 需要在应用启动时初始化并设置账户
/// - SeeAlso: `PushNotificationSubscriptionSettings` 管理单个账户的订阅
@MainActor
@Observable public class PushNotificationsService: NSObject {
  /// 服务常量
  enum Constants {
    /// 推送通知中继服务器端点
    ///
    /// IceCubes 使用自己的中继服务器来转发推送通知，
    /// 这样可以保护用户隐私，避免直接暴露设备令牌给 Mastodon 服务器。
    static let endpoint = "https://icecubesrelay.fly.dev"
  }

  /// 单例实例
  ///
  /// 全局共享的推送通知服务实例。
  public static let shared = PushNotificationsService()

  /// 推送密钥管理器
  ///
  /// 管理加密密钥的生成和存储。
  private let pushKeys = PushKeys()

  /// 所有账户的订阅设置
  ///
  /// 每个账户都有独立的推送订阅配置。
  ///
  /// 特点：
  /// - 支持多账户
  /// - 每个账户可以独立配置通知类型
  /// - 自动同步到服务器
  public private(set) var subscriptions: [PushNotificationSubscriptionSettings] = []

  /// 设备推送令牌
  ///
  /// 从 APNs 获取的设备唯一标识符。
  ///
  /// 获取时机：
  /// - 应用首次启动时
  /// - 用户授权推送权限后
  /// - 令牌更新时
  ///
  /// 使用场景：
  /// - 注册推送订阅
  /// - 更新订阅设置
  public var pushToken: Data?

  /// 已处理的通知
  ///
  /// 用户点击推送通知后，存储完整的通知对象。
  ///
  /// 使用场景：
  /// - 应用启动后跳转到通知详情
  /// - 在应用中显示通知内容
  ///
  /// 生命周期：
  /// - 用户点击通知时设置
  /// - 应用处理完通知后清空
  public var handledNotification: HandledNotification?

  /// 初始化推送通知服务
  ///
  /// 设置通知中心的代理，准备接收通知。
  override init() {
    super.init()

    // 设置为通知中心的代理，接收通知回调
    UNUserNotificationCenter.current().delegate = self
  }

  /// 请求推送通知权限
  ///
  /// 向用户请求推送通知权限，并注册远程通知。
  ///
  /// 请求的权限：
  /// - **alert**：显示横幅和通知中心
  /// - **sound**：播放通知声音
  /// - **badge**：显示应用角标
  ///
  /// 执行流程：
  /// 1. 请求用户授权
  /// 2. 用户同意后，向 APNs 注册
  /// 3. 获取设备推送令牌
  /// 4. 使用令牌创建推送订阅
  ///
  /// 使用场景：
  /// - 应用首次启动时
  /// - 用户在设置中启用推送时
  /// - 添加新账户时
  ///
  /// 示例：
  /// ```swift
  /// Button("启用推送通知") {
  ///     PushNotificationsService.shared.requestPushNotifications()
  /// }
  /// ```
  ///
  /// - Note: 用户可以在系统设置中随时更改权限
  public func requestPushNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      @Sendable _, _ in
      DispatchQueue.main.async {
        // 注册远程通知，获取设备令牌
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  /// 设置推送账户
  ///
  /// 为指定的账户列表创建推送订阅设置。
  ///
  /// - Parameter accounts: 要启用推送的账户列表
  ///
  /// 执行流程：
  /// 1. 清空现有订阅
  /// 2. 为每个账户创建订阅设置
  /// 3. 使用加密密钥和推送令牌配置订阅
  ///
  /// 使用场景：
  /// - 用户登录后
  /// - 添加新账户时
  /// - 账户列表变化时
  ///
  /// 示例：
  /// ```swift
  /// let accounts = [
  ///     PushAccount(server: "mastodon.social", token: token1, accountName: "@user1"),
  ///     PushAccount(server: "mastodon.online", token: token2, accountName: "@user2")
  /// ]
  /// PushNotificationsService.shared.setAccounts(accounts: accounts)
  /// await PushNotificationsService.shared.updateSubscriptions(forceCreate: false)
  /// ```
  ///
  /// - Note: 调用此方法后需要调用 `updateSubscriptions` 来实际创建订阅
  public func setAccounts(accounts: [PushAccount]) {
    subscriptions = []
    for account in accounts {
      let sub = PushNotificationSubscriptionSettings(
        account: account,
        key: pushKeys.notificationsPrivateKeyAsKey.publicKey.x963Representation,
        authKey: pushKeys.notificationsAuthKeyAsKey,
        pushToken: pushToken)
      subscriptions.append(sub)
    }
  }

  /// 更新推送订阅
  ///
  /// 向 Mastodon 服务器更新所有账户的推送订阅。
  ///
  /// - Parameter forceCreate: 是否强制创建新订阅
  ///
  /// 更新逻辑：
  /// - **forceCreate = false**：
  ///   1. 获取现有订阅
  ///   2. 如果存在，先删除再重新创建
  ///   3. 如果不存在，不执行任何操作
  ///
  /// - **forceCreate = true**：
  ///   1. 直接创建新订阅
  ///   2. 覆盖现有订阅
  ///
  /// 使用场景：
  /// - 设置账户后首次创建订阅
  /// - 推送令牌更新后
  /// - 订阅设置变化后
  /// - 修复订阅问题时
  ///
  /// 并发处理：
  /// - 使用 TaskGroup 并发更新所有账户
  /// - 提高更新效率
  ///
  /// 示例：
  /// ```swift
  /// // 首次创建订阅
  /// await PushNotificationsService.shared.updateSubscriptions(forceCreate: true)
  ///
  /// // 更新现有订阅
  /// await PushNotificationsService.shared.updateSubscriptions(forceCreate: false)
  /// ```
  ///
  /// - Note: 这是一个异步方法，可能需要几秒钟完成
  public func updateSubscriptions(forceCreate: Bool) async {
    for subscription in subscriptions {
      await withTaskGroup(
        of: Void.self,
        body: { group in
          group.addTask {
            await subscription.fetchSubscription()
            if await subscription.subscription != nil, !forceCreate {
              // 存在订阅且不强制创建，先删除再更新
              await subscription.deleteSubscription()
              await subscription.updateSubscription()
            } else if forceCreate {
              // 强制创建新订阅
              await subscription.updateSubscription()
            }
          }
        })
    }
  }
}

// MARK: - 通知中心代理

/// 推送通知服务的通知中心代理实现
///
/// 处理推送通知的接收和用户交互。
extension PushNotificationsService: UNUserNotificationCenterDelegate {
  /// 处理用户点击通知的操作
  ///
  /// 当用户点击推送通知时调用此方法。
  ///
  /// - Parameters:
  ///   - center: 通知中心
  ///   - response: 用户的响应（点击、滑动等）
  ///
  /// 处理流程：
  /// 1. 从通知中提取解密后的内容
  /// 2. 解析 Mastodon 推送通知对象
  /// 3. 根据访问令牌找到对应的账户
  /// 4. 使用账户客户端从服务器获取完整通知
  /// 5. 创建 HandledNotification 对象
  /// 6. 应用根据此对象跳转到对应页面
  ///
  /// 通知内容：
  /// - **plaintext**：解密后的通知内容（Data）
  /// - 包含通知 ID 和访问令牌
  /// - 用于识别通知和账户
  ///
  /// 使用场景：
  /// - 用户点击通知横幅
  /// - 用户在通知中心点击通知
  /// - 用户通过 3D Touch 预览通知后点击
  ///
  /// 错误处理：
  /// - 如果解析失败，静默返回
  /// - 如果找不到账户，静默返回
  /// - 如果网络请求失败，静默返回
  ///
  /// - Note: 这是一个异步方法，在后台线程执行
  public func userNotificationCenter(
    _: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    guard let plaintext = response.notification.request.content.userInfo["plaintext"] as? Data,
      let mastodonPushNotification = try? JSONDecoder().decode(
        MastodonPushNotification.self, from: plaintext),
      let account = subscriptions.first(where: {
        $0.account.token.accessToken == mastodonPushNotification.accessToken
      })
    else {
      return
    }
    do {
      // 从服务器获取完整的通知对象
      let client = MastodonClient(server: account.account.server, oauthToken: account.account.token)
      let notification: Models.Notification =
        try await client.get(
          endpoint: Notifications.notification(id: String(mastodonPushNotification.notificationID)))
      // 保存已处理的通知，供应用使用
      handledNotification = .init(account: account.account, notification: notification)
    } catch {}
  }

  /// 决定如何展示前台通知
  ///
  /// 当应用在前台时收到推送通知，此方法决定如何展示。
  ///
  /// - Parameters:
  ///   - center: 通知中心
  ///   - notification: 接收到的通知
  /// - Returns: 展示选项
  ///
  /// 展示选项：
  /// - **banner**：显示横幅通知
  /// - **sound**：播放通知声音
  ///
  /// 使用场景：
  /// - 应用在前台运行时
  /// - 收到新的推送通知
  ///
  /// 行为：
  /// - 即使应用在前台，也显示通知横幅
  /// - 播放通知声音提醒用户
  /// - 不更新应用角标（因为用户正在使用应用）
  ///
  /// - Note: 这是一个异步方法，在后台线程执行
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    return [.banner, .sound]
  }
}

// MARK: - Data 扩展

/// Data 的十六进制字符串扩展
extension Data {
  /// 将 Data 转换为十六进制字符串
  ///
  /// 用于将推送令牌转换为 URL 路径的一部分。
  ///
  /// 转换示例：
  /// ```
  /// Data([0x12, 0x34, 0xAB, 0xCD]) -> "1234abcd"
  /// ```
  ///
  /// 使用场景：
  /// - 构建推送端点 URL
  /// - 调试和日志记录
  ///
  /// - Returns: 小写的十六进制字符串
  var hexString: String {
    map { String(format: "%02.2hhx", arguments: [$0]) }.joined()
  }
}

// MARK: - 推送订阅设置

/// 单个账户的推送通知订阅设置
///
/// 管理单个 Mastodon 账户的推送通知配置和订阅状态。
///
/// 主要功能：
/// - **订阅管理**：创建、更新、删除推送订阅
/// - **通知类型控制**：细粒度控制接收哪些类型的通知
/// - **状态同步**：与服务器同步订阅状态
/// - **加密配置**：管理推送通知的加密密钥
///
/// 支持的通知类型：
/// - **关注**：有人关注了你
/// - **点赞**：有人点赞了你的帖子
/// - **转发**：有人转发了你的帖子
/// - **提及**：有人在帖子中提到了你
/// - **投票**：你参与的投票结束了
/// - **新帖子**：你关注的人发布了新帖子
///
/// 使用方式：
/// ```swift
/// let settings = PushNotificationSubscriptionSettings(
///     account: pushAccount,
///     key: publicKey,
///     authKey: authKey,
///     pushToken: deviceToken
/// )
///
/// // 配置通知类型
/// settings.isMentionNotificationEnabled = true
/// settings.isFollowNotificationEnabled = true
///
/// // 创建订阅
/// await settings.updateSubscription()
///
/// // 删除订阅
/// await settings.deleteSubscription()
/// ```
///
/// 工作流程：
/// 1. 创建设置对象
/// 2. 配置要接收的通知类型
/// 3. 调用 updateSubscription 创建订阅
/// 4. 服务器开始发送推送通知
/// 5. 可以随时更新或删除订阅
///
/// - Note: 所有操作都在主线程执行，确保 UI 安全
/// - Important: 需要有效的推送令牌才能创建订阅
@MainActor
@Observable public class PushNotificationSubscriptionSettings {
  /// 是否启用推送通知
  ///
  /// 控制此账户的推送通知总开关。
  ///
  /// 状态：
  /// - true：推送通知已启用
  /// - false：推送通知已禁用
  ///
  /// - Note: 禁用后不会接收任何推送通知
  public var isEnabled: Bool = true
  
  /// 是否启用关注通知
  ///
  /// 当有人关注你时是否发送推送通知。
  public var isFollowNotificationEnabled: Bool = true
  
  /// 是否启用点赞通知
  ///
  /// 当有人点赞你的帖子时是否发送推送通知。
  public var isFavoriteNotificationEnabled: Bool = true
  
  /// 是否启用转发通知
  ///
  /// 当有人转发你的帖子时是否发送推送通知。
  public var isReblogNotificationEnabled: Bool = true
  
  /// 是否启用提及通知
  ///
  /// 当有人在帖子中提到你时是否发送推送通知。
  public var isMentionNotificationEnabled: Bool = true
  
  /// 是否启用投票通知
  ///
  /// 当你参与的投票结束时是否发送推送通知。
  public var isPollNotificationEnabled: Bool = true
  
  /// 是否启用新帖子通知
  ///
  /// 当你关注的人发布新帖子时是否发送推送通知。
  ///
  /// - Note: 这可能会产生大量通知，建议谨慎启用
  public var isNewPostsNotificationEnabled: Bool = true

  /// 关联的推送账户
  ///
  /// 包含服务器地址、访问令牌和账户名称。
  public let account: PushAccount

  /// 公钥
  ///
  /// P256 椭圆曲线公钥，用于加密推送通知内容。
  ///
  /// - Note: 这是私钥对应的公钥，发送给服务器用于加密
  private let key: Data
  
  /// 认证密钥
  ///
  /// 用于验证推送通知来源的密钥。
  private let authKey: Data

  /// 设备推送令牌
  ///
  /// 从 APNs 获取的设备唯一标识符。
  ///
  /// - Note: 如果为 nil，无法创建推送订阅
  public var pushToken: Data?

  /// 当前的推送订阅
  ///
  /// 从服务器获取的订阅信息。
  ///
  /// 状态：
  /// - nil：未订阅或订阅失败
  /// - PushSubscription：订阅成功，包含订阅详情
  ///
  /// 使用场景：
  /// - 检查订阅状态
  /// - 显示当前配置
  /// - 更新订阅设置
  public private(set) var subscription: PushSubscription?

  /// 初始化推送订阅设置
  ///
  /// - Parameters:
  ///   - account: 推送账户
  ///   - key: 公钥（用于加密）
  ///   - authKey: 认证密钥
  ///   - pushToken: 设备推送令牌
  public init(account: PushAccount, key: Data, authKey: Data, pushToken: Data?) {
    self.account = account
    self.key = key
    self.authKey = authKey
    self.pushToken = pushToken
  }

  /// 刷新订阅 UI 状态
  ///
  /// 从服务器返回的订阅信息更新本地 UI 状态。
  ///
  /// 同步的设置：
  /// - 关注通知开关
  /// - 点赞通知开关
  /// - 转发通知开关
  /// - 提及通知开关
  /// - 投票通知开关
  /// - 新帖子通知开关
  ///
  /// 使用场景：
  /// - 获取订阅后
  /// - 更新订阅后
  /// - 删除订阅后
  ///
  /// - Note: 这是一个私有方法，只在内部使用
  private func refreshSubscriptionsUI() {
    if let subscription {
      isFollowNotificationEnabled = subscription.alerts.follow
      isFavoriteNotificationEnabled = subscription.alerts.favourite
      isReblogNotificationEnabled = subscription.alerts.reblog
      isMentionNotificationEnabled = subscription.alerts.mention
      isPollNotificationEnabled = subscription.alerts.poll
      isNewPostsNotificationEnabled = subscription.alerts.status
    }
  }

  /// 更新推送订阅
  ///
  /// 向 Mastodon 服务器创建或更新推送订阅。
  ///
  /// 执行流程：
  /// 1. 检查推送令牌是否存在
  /// 2. 构建中继服务器的监听 URL
  /// 3. 向 Mastodon 服务器发送订阅请求
  /// 4. 更新本地订阅状态
  /// 5. 刷新 UI 状态
  ///
  /// 监听 URL 格式：
  /// ```
  /// https://icecubesrelay.fly.dev/push/{pushToken}/{accountName}
  /// ```
  ///
  /// Debug 模式：
  /// - 添加 `?sandbox=true` 参数
  /// - 使用 APNs 沙盒环境
  ///
  /// 订阅参数：
  /// - **endpoint**：中继服务器的监听 URL
  /// - **p256dh**：公钥，用于加密通知内容
  /// - **auth**：认证密钥，用于验证通知来源
  /// - **通知类型开关**：各种通知类型的启用状态
  ///
  /// 使用场景：
  /// - 首次创建订阅
  /// - 更新通知类型设置
  /// - 推送令牌更新后
  ///
  /// 错误处理：
  /// - 如果没有推送令牌，直接返回
  /// - 如果请求失败，设置 isEnabled 为 false
  ///
  /// 示例：
  /// ```swift
  /// // 配置通知类型
  /// settings.isMentionNotificationEnabled = true
  /// settings.isFollowNotificationEnabled = false
  ///
  /// // 更新订阅
  /// await settings.updateSubscription()
  /// ```
  ///
  /// - Note: 这是一个异步方法，可能需要几秒钟完成
  public func updateSubscription() async {
    guard let pushToken else { return }
    let client = MastodonClient(server: account.server, oauthToken: account.token)
    do {
      // 构建中继服务器的监听 URL
      var listenerURL = PushNotificationsService.Constants.endpoint
      listenerURL += "/push/"
      listenerURL += pushToken.hexString
      listenerURL += "/\(account.accountName ?? account.server)"
      #if DEBUG
        listenerURL += "?sandbox=true"
      #endif
      
      // 向 Mastodon 服务器创建订阅
      subscription =
        try await client.post(
          endpoint: Push.createSub(
            endpoint: listenerURL,
            p256dh: key,
            auth: authKey,
            mentions: isMentionNotificationEnabled,
            status: isNewPostsNotificationEnabled,
            reblog: isReblogNotificationEnabled,
            follow: isFollowNotificationEnabled,
            favorite: isFavoriteNotificationEnabled,
            poll: isPollNotificationEnabled))
      isEnabled = subscription != nil

    } catch {
      isEnabled = false
    }
    refreshSubscriptionsUI()
  }

  /// 删除推送订阅
  ///
  /// 从 Mastodon 服务器删除推送订阅。
  ///
  /// 执行流程：
  /// 1. 向服务器发送删除请求
  /// 2. 清空本地订阅状态
  /// 3. 重新获取订阅（验证删除成功）
  /// 4. 如果仍然存在，递归删除
  /// 5. 更新 UI 状态
  ///
  /// 递归删除：
  /// - 某些情况下订阅可能无法一次删除
  /// - 使用递归确保完全删除
  /// - 避免残留订阅导致的问题
  ///
  /// 使用场景：
  /// - 用户禁用推送通知
  /// - 删除账户时
  /// - 重置推送设置时
  ///
  /// 错误处理：
  /// - 如果删除失败，静默返回
  /// - 最终会设置 isEnabled 为 false
  ///
  /// 示例：
  /// ```swift
  /// // 禁用推送通知
  /// await settings.deleteSubscription()
  /// ```
  ///
  /// - Note: 这是一个异步方法，可能需要几秒钟完成
  /// - Important: 删除后需要重新调用 updateSubscription 才能恢复推送
  public func deleteSubscription() async {
    let client = MastodonClient(server: account.server, oauthToken: account.token)
    do {
      _ = try await client.delete(endpoint: Push.subscription)
      subscription = nil
      await fetchSubscription()
      refreshSubscriptionsUI()
      // 递归删除，确保完全删除
      while subscription != nil {
        await deleteSubscription()
      }
      isEnabled = false
    } catch {}
  }

  /// 获取推送订阅
  ///
  /// 从 Mastodon 服务器获取当前的推送订阅信息。
  ///
  /// 执行流程：
  /// 1. 向服务器发送获取请求
  /// 2. 更新本地订阅状态
  /// 3. 更新 isEnabled 状态
  /// 4. 刷新 UI 状态
  ///
  /// 使用场景：
  /// - 应用启动时检查订阅状态
  /// - 验证订阅是否存在
  /// - 同步服务器端的设置
  ///
  /// 错误处理：
  /// - 如果获取失败，设置 subscription 为 nil
  /// - 设置 isEnabled 为 false
  ///
  /// 示例：
  /// ```swift
  /// // 检查订阅状态
  /// await settings.fetchSubscription()
  /// if settings.isEnabled {
  ///     print("推送通知已启用")
  /// } else {
  ///     print("推送通知未启用")
  /// }
  /// ```
  ///
  /// - Note: 这是一个异步方法，可能需要几秒钟完成
  public func fetchSubscription() async {
    let client = MastodonClient(server: account.server, oauthToken: account.token)
    do {
      subscription = try await client.get(endpoint: Push.subscription)
      isEnabled = subscription != nil
    } catch {
      subscription = nil
      isEnabled = false
    }
    refreshSubscriptionsUI()
  }
}
