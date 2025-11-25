/*
 * IceCubesApp.swift
 * IceCubesApp - 应用主入口
 *
 * 文件功能：
 * 应用的主入口点，初始化全局服务、管理应用生命周期和推送通知。
 *
 * 核心职责：
 * - 初始化所有全局单例（Theme、UserPreferences、CurrentAccount 等）
 * - 管理应用生命周期（前台/后台切换）
 * - 配置推送通知和 RevenueCat 订阅
 * - 处理 WebSocket 实时流
 * - 管理多账户系统
 * - 配置应用级服务（Telemetry、WishKit）
 *
 * 技术要点：
 * - @main 应用入口
 * - @UIApplicationDelegateAdaptor 集成 AppDelegate
 * - @State 管理全局服务单例
 * - @Namespace 动画命名空间
 * - scenePhase 生命周期监听
 * - RevenueCat 订阅管理
 *
 * 使用场景：
 * - 应用启动入口
 * - 全局状态和服务初始化
 * - 推送通知处理
 *
 * 依赖关系：
 * - Env: 所有全局服务和管理器
 * - AppAccount: 多账户管理
 * - RevenueCat: 应用内购买
 * - WishKit: 用户反馈系统
 */

import AVFoundation
import Account
import AppAccount
import DesignSystem
import Env
import KeychainSwift
import MediaUI
import NetworkClient
import RevenueCat
import StatusKit
import SwiftUI
import Timeline
import WishKit

/// IceCubes 应用主结构。
///
/// 应用的根入口，管理全局状态和生命周期。
@main
struct IceCubesApp: App {
  /// UIKit AppDelegate 适配器。
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  /// 应用场景阶段（前台/后台/非活动）。
  @Environment(\.scenePhase) var scenePhase
  /// 打开新窗口的函数（macOS/visionOS）。
  @Environment(\.openWindow) var openWindow

  /// 多账户管理器。
  @State var appAccountsManager = AppAccountsManager.shared
  /// 当前实例管理器。
  @State var currentInstance = CurrentInstance.shared
  /// 当前账户管理器。
  @State var currentAccount = CurrentAccount.shared
  /// 用户偏好设置。
  @State var userPreferences = UserPreferences.shared
  /// 推送通知服务。
  @State var pushNotificationsService = PushNotificationsService.shared
  /// 应用快捷指令服务。
  @State var appIntentService = AppIntentService.shared
  /// WebSocket 流监听器。
  @State var watcher = StreamWatcher.shared
  /// 快速预览服务。
  @State var quickLook = QuickLook.shared
  /// 主题管理器。
  @State var theme = Theme.shared

  /// 当前选中的标签页。
  @State var selectedTab: AppTab = .timeline
  /// 应用路由路径。
  @State var appRouterPath = RouterPath()

  /// 是否为订阅用户（支持者）。
  @State var isSupporter: Bool = false

  /// 动画命名空间（用于共享元素动画）。
  @Namespace var namespace

  /// 初始化方法。
  init() {
    #if DEBUG
      UserDefaults.standard.register(defaults: [
        "com.apple.SwiftUI.GraphReuseLogging": true,  // Enable "GraphReuseLogging" by default. The log can be found via - subsystem: "com.apple.SwiftUI" category: "GraphReuse"
        "LogForEachSlowPath": true,  // Enable "LogForEachSlowPath" by default. The log can be found via - subsystem: "com.apple.SwiftUI" category: "Invalid Configuration"
      ])
    #endif
  }

  /// 应用场景主体。
  var body: some Scene {
    appScene
    otherScenes
  }

  /// 在环境中设置新的 Mastodon 客户端。
  ///
  /// 为所有全局服务注入新的客户端实例，并启动实时流监听。
  ///
  /// - Parameter client: 新的 Mastodon 客户端。
  func setNewClientsInEnv(client: MastodonClient) {
    quickLook.namespace = namespace
    currentAccount.setClient(client: client)
    currentInstance.setClient(client: client)
    userPreferences.setClient(client: client)
    Task {
      await currentInstance.fetchCurrentInstance()
      watcher.setClient(
        client: client, instanceStreamingURL: currentInstance.instance?.urls?.streamingApi)
      watcher.watch(streams: [.user, .direct])
    }
  }

  /// 处理应用场景阶段变化。
  ///
  /// 根据应用进入前台或后台状态，启动或停止实时流监听，并更新通知计数。
  ///
  /// - Parameter scenePhase: 场景阶段（前台/后台/非活动）。
  func handleScenePhase(scenePhase: ScenePhase) {
    switch scenePhase {
    case .background:
      watcher.stopWatching()
    case .active:
      watcher.watch(streams: [.user, .direct])
      UNUserNotificationCenter.current().setBadgeCount(0)
      userPreferences.reloadNotificationsCount(
        tokens: appAccountsManager.availableAccounts.compactMap(\.oauthToken))
      Task {
        await userPreferences.refreshServerPreferences()
      }
    default:
      break
    }
  }

  /// 配置 RevenueCat 订阅系统。
  ///
  /// 初始化应用内购买服务，检查用户是否为支持者（Supporter）。
  func setupRevenueCat() {
    Purchases.logLevel = .error
    Purchases.configure(withAPIKey: "appl_JXmiRckOzXXTsHKitQiicXCvMQi")
    Purchases.shared.getCustomerInfo { info, _ in
      if info?.entitlements["Supporter"]?.isActive == true {
        isSupporter = true
      }
    }
  }

  /// 刷新推送通知订阅。
  ///
  /// 重新请求推送通知权限并更新订阅。
  func refreshPushSubs() {
    PushNotificationsService.shared.requestPushNotifications()
  }
}

/// 应用委托类。
///
/// 处理应用生命周期事件、推送通知注册和菜单构建。
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
    try? AVAudioSession.sharedInstance().setActive(true)
    PushNotificationsService.shared.setAccounts(accounts: AppAccountsManager.shared.pushAccounts)
    Telemetry.setup()
    Telemetry.signal("app.launched")
    WishKit.configure(with: "AF21AE07-3BA9-4FE2-BFB1-59A3B3941730")
    return true
  }

  func application(
    _: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    PushNotificationsService.shared.pushToken = deviceToken
    Task {
      PushNotificationsService.shared.setAccounts(accounts: AppAccountsManager.shared.pushAccounts)
      await PushNotificationsService.shared.updateSubscriptions(forceCreate: false)
    }
  }

  func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError _: Error) {}

  func application(_: UIApplication, didReceiveRemoteNotification _: [AnyHashable: Any]) async
    -> UIBackgroundFetchResult
  {
    UserPreferences.shared.reloadNotificationsCount(
      tokens: AppAccountsManager.shared.availableAccounts.compactMap(\.oauthToken))
    return .noData
  }

  func application(
    _: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
    options _: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    if connectingSceneSession.role == .windowApplication {
      configuration.delegateClass = SceneDelegate.self
    }
    return configuration
  }

  override func buildMenu(with builder: UIMenuBuilder) {
    super.buildMenu(with: builder)
    builder.remove(menu: .document)
    builder.remove(menu: .toolbar)
  }
}
