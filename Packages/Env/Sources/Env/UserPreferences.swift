// 文件功能：用户偏好设置管理
//
// 核心职责：
// - 管理所有用户可配置的应用设置
// - 持久化设置到 UserDefaults 和 App Group
// - 同步服务器端偏好设置（如默认可见性、敏感内容设置）
// - 提供设置的读写接口和计算属性
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架实现响应式更新
// - @MainActor：确保所有 UI 相关操作在主线程执行
// - @AppStorage：自动持久化设置到 UserDefaults
// - 单例模式：全局唯一的设置管理器
// - App Group：通过 shared UserDefaults 在主应用和扩展间共享数据
//
// 架构设计：
// - Storage 内部类：使用 @AppStorage 包装所有持久化属性
// - UserPreferences 公开属性：提供 Observable 的接口，didSet 时同步到 Storage
// - 这种双层设计确保了 @Observable 和 @AppStorage 的兼容性
//
// 依赖关系：
// - 依赖：Models（Visibility 等类型）、NetworkClient（获取服务器偏好）
// - 被依赖：所有需要访问用户设置的视图和服务

import Combine
import Foundation
import Models
import NetworkClient
import SwiftUI

/// 用户偏好设置管理器
///
/// 管理应用的所有用户可配置设置，包括：
/// - UI 偏好（浏览器、主题、字体等）
/// - 内容偏好（自动展开、媒体播放等）
/// - 交互偏好（触觉反馈、滑动手势等）
/// - 发帖默认设置（可见性、敏感内容等）
///
/// 使用示例：
/// ```swift
/// @Environment(UserPreferences.self) private var preferences
///
/// var body: some View {
///     Toggle("自动播放视频", isOn: $preferences.autoPlayVideo)
/// }
/// ```
///
/// - Note: 使用单例模式，通过 `UserPreferences.shared` 访问
/// - Warning: 所有属性访问必须在主线程（@MainActor）
@MainActor
@Observable public class UserPreferences {
  /// 内部存储类
  ///
  /// 使用 @AppStorage 包装所有需要持久化的设置。
  /// 这种设计模式解决了 @Observable 和 @AppStorage 的兼容性问题。
  ///
  /// 工作原理：
  /// 1. Storage 使用 @AppStorage 自动持久化到 UserDefaults
  /// 2. UserPreferences 的公开属性在 didSet 时同步到 Storage
  /// 3. @Observable 监听公开属性的变化，触发 UI 更新
  class Storage {
    @AppStorage("preferred_browser") public var preferredBrowser: PreferredBrowser = .inAppSafari
    @AppStorage("show_translate_button_inline") public var showTranslateButton: Bool = true
    @AppStorage("show_pending_at_bottom") public var pendingShownAtBottom: Bool = false
    @AppStorage("show_pending_left") public var pendingShownLeft: Bool = false

    @AppStorage("recently_used_languages") public var recentlyUsedLanguages: [String] = []
    @AppStorage("social_keyboard_composer") public var isSocialKeyboardEnabled: Bool = false

    @AppStorage("use_instance_content_settings") public var useInstanceContentSettings: Bool = true
    @AppStorage("app_auto_expand_spoilers") public var appAutoExpandSpoilers = false
    @AppStorage("app_auto_expand_media") public var appAutoExpandMedia:
      ServerPreferences.AutoExpandMedia = .hideSensitive
    @AppStorage("app_default_post_visibility") public var appDefaultPostVisibility:
      Models.Visibility = .pub
    @AppStorage("app_default_reply_visibility") public var appDefaultReplyVisibility:
      Models.Visibility = .pub
    @AppStorage("app_default_posts_sensitive") public var appDefaultPostsSensitive = false
    @AppStorage("app_require_alt_text") public var appRequireAltText = false
    @AppStorage("autoplay_video") public var autoPlayVideo = true
    @AppStorage("mute_video") public var muteVideo = true
    @AppStorage("preferred_translation_type") public var preferredTranslationType = TranslationType
      .useServerIfPossible
    @AppStorage("user_deepl_api_free") public var userDeeplAPIFree = true
    @AppStorage("auto_detect_post_language") public var autoDetectPostLanguage = true

    @AppStorage("inAppBrowserReaderView") public var inAppBrowserReaderView = false

    @AppStorage("haptic_tab") public var hapticTabSelectionEnabled = true
    @AppStorage("haptic_timeline") public var hapticTimelineEnabled = true
    @AppStorage("haptic_button_press") public var hapticButtonPressEnabled = true
    @AppStorage("sound_effect_enabled") public var soundEffectEnabled = true

    @AppStorage("show_alt_text_for_media") public var showAltTextForMedia = true

    @AppStorage("show_second_column_ipad") public var showiPadSecondaryColumn = true

    @AppStorage("swipeactions-status-trailing-right") public var swipeActionsStatusTrailingRight =
      StatusAction.favorite
    @AppStorage("swipeactions-status-trailing-left") public var swipeActionsStatusTrailingLeft =
      StatusAction.boost
    @AppStorage("swipeactions-status-leading-left") public var swipeActionsStatusLeadingLeft =
      StatusAction.reply
    @AppStorage("swipeactions-status-leading-right") public var swipeActionsStatusLeadingRight =
      StatusAction.none
    @AppStorage("swipeactions-use-theme-color") public var swipeActionsUseThemeColor = false
    @AppStorage("swipeactions-icon-style") public var swipeActionsIconStyle: SwipeActionsIconStyle =
      .iconWithText

    @AppStorage("requested_review") public var requestedReview = false

    @AppStorage("collapse-long-posts") public var collapseLongPosts = true

    @AppStorage("share-button-behavior") public var shareButtonBehavior:
      PreferredShareButtonBehavior = .linkOnly

    @AppStorage("boost-button-behavior") public var boostButtonBehavior:
      PreferredBoostButtonBehavior = .both

    @AppStorage("max_reply_indentation") public var maxReplyIndentation: UInt = 7
    @AppStorage("show_reply_indentation") public var showReplyIndentation: Bool = true

    @AppStorage("show_account_popover") public var showAccountPopover: Bool = true

    @AppStorage("sidebar_expanded") public var isSidebarExpanded: Bool = false
    
    @AppStorage("stream_home_timeline") public var streamHomeTimeline: Bool = false
    @AppStorage("full_timeline_fetch") public var fullTimelineFetch: Bool = false

    // Notifications
    @AppStorage("notifications-truncate-status-content")
    public var notificationsTruncateStatusContent: Bool = true

    init() {
      prepareTranslationType()
    }

    private func prepareTranslationType() {
      let sharedDefault = UserDefaults.standard
      if let alwaysUseDeepl = (sharedDefault.object(forKey: "always_use_deepl") as? Bool) {
        if alwaysUseDeepl {
          preferredTranslationType = .useDeepl
        }
        sharedDefault.removeObject(forKey: "always_use_deepl")
      }
      #if canImport(_Translation_SwiftUI)
        if #unavailable(iOS 17.4),
          preferredTranslationType == .useApple
        {
          preferredTranslationType = .useServerIfPossible
        }
      #else
        if preferredTranslationType == .useApple {
          preferredTranslationType = .useServerIfPossible
        }
      #endif
    }
  }

  public static let sharedDefault = UserDefaults(suiteName: "group.com.thomasricouard.IceCubesApp")
  public static let shared = UserPreferences()
  private let storage = Storage()

  private var client: MastodonClient?

  public var preferredBrowser: PreferredBrowser {
    didSet {
      storage.preferredBrowser = preferredBrowser
    }
  }

  public var showTranslateButton: Bool {
    didSet {
      storage.showTranslateButton = showTranslateButton
    }
  }

  public var pendingShownAtBottom: Bool {
    didSet {
      storage.pendingShownAtBottom = pendingShownAtBottom
    }
  }

  public var pendingShownLeft: Bool {
    didSet {
      storage.pendingShownLeft = pendingShownLeft
    }
  }

  public var pendingLocation: Alignment {
    let fromLeft =
      Locale.current.language.characterDirection == .leftToRight
      ? pendingShownLeft : !pendingShownLeft
    if pendingShownAtBottom {
      if fromLeft {
        return .bottomLeading
      } else {
        return .bottomTrailing
      }
    } else {
      if fromLeft {
        return .topLeading
      } else {
        return .topTrailing
      }
    }
  }

  public var recentlyUsedLanguages: [String] {
    didSet {
      storage.recentlyUsedLanguages = recentlyUsedLanguages
    }
  }

  public var isSocialKeyboardEnabled: Bool {
    didSet {
      storage.isSocialKeyboardEnabled = isSocialKeyboardEnabled
    }
  }

  public var useInstanceContentSettings: Bool {
    didSet {
      storage.useInstanceContentSettings = useInstanceContentSettings
    }
  }

  public var appAutoExpandSpoilers: Bool {
    didSet {
      storage.appAutoExpandSpoilers = appAutoExpandSpoilers
    }
  }

  public var appAutoExpandMedia: ServerPreferences.AutoExpandMedia {
    didSet {
      storage.appAutoExpandMedia = appAutoExpandMedia
    }
  }

  public var appDefaultPostVisibility: Models.Visibility {
    didSet {
      storage.appDefaultPostVisibility = appDefaultPostVisibility
    }
  }

  public var appDefaultReplyVisibility: Models.Visibility {
    didSet {
      storage.appDefaultReplyVisibility = appDefaultReplyVisibility
    }
  }

  public var appDefaultPostsSensitive: Bool {
    didSet {
      storage.appDefaultPostsSensitive = appDefaultPostsSensitive
    }
  }

  public var appRequireAltText: Bool {
    didSet {
      storage.appRequireAltText = appRequireAltText
    }
  }

  public var autoPlayVideo: Bool {
    didSet {
      storage.autoPlayVideo = autoPlayVideo
    }
  }

  public var muteVideo: Bool {
    didSet {
      storage.muteVideo = muteVideo
    }
  }

  public var preferredTranslationType: TranslationType {
    didSet {
      storage.preferredTranslationType = preferredTranslationType
    }
  }

  public var userDeeplAPIFree: Bool {
    didSet {
      storage.userDeeplAPIFree = userDeeplAPIFree
    }
  }

  public var autoDetectPostLanguage: Bool {
    didSet {
      storage.autoDetectPostLanguage = autoDetectPostLanguage
    }
  }

  public var inAppBrowserReaderView: Bool {
    didSet {
      storage.inAppBrowserReaderView = inAppBrowserReaderView
    }
  }

  public var hapticTabSelectionEnabled: Bool {
    didSet {
      storage.hapticTabSelectionEnabled = hapticTabSelectionEnabled
    }
  }

  public var hapticTimelineEnabled: Bool {
    didSet {
      storage.hapticTimelineEnabled = hapticTimelineEnabled
    }
  }

  public var hapticButtonPressEnabled: Bool {
    didSet {
      storage.hapticButtonPressEnabled = hapticButtonPressEnabled
    }
  }

  public var soundEffectEnabled: Bool {
    didSet {
      storage.soundEffectEnabled = soundEffectEnabled
    }
  }

  public var showAltTextForMedia: Bool {
    didSet {
      storage.showAltTextForMedia = showAltTextForMedia
    }
  }

  public var showiPadSecondaryColumn: Bool {
    didSet {
      storage.showiPadSecondaryColumn = showiPadSecondaryColumn
    }
  }

  public var swipeActionsStatusTrailingRight: StatusAction {
    didSet {
      storage.swipeActionsStatusTrailingRight = swipeActionsStatusTrailingRight
    }
  }

  public var swipeActionsStatusTrailingLeft: StatusAction {
    didSet {
      storage.swipeActionsStatusTrailingLeft = swipeActionsStatusTrailingLeft
    }
  }

  public var swipeActionsStatusLeadingLeft: StatusAction {
    didSet {
      storage.swipeActionsStatusLeadingLeft = swipeActionsStatusLeadingLeft
    }
  }

  public var swipeActionsStatusLeadingRight: StatusAction {
    didSet {
      storage.swipeActionsStatusLeadingRight = swipeActionsStatusLeadingRight
    }
  }

  public var swipeActionsUseThemeColor: Bool {
    didSet {
      storage.swipeActionsUseThemeColor = swipeActionsUseThemeColor
    }
  }

  public var swipeActionsIconStyle: SwipeActionsIconStyle {
    didSet {
      storage.swipeActionsIconStyle = swipeActionsIconStyle
    }
  }

  public var requestedReview: Bool {
    didSet {
      storage.requestedReview = requestedReview
    }
  }

  public var collapseLongPosts: Bool {
    didSet {
      storage.collapseLongPosts = collapseLongPosts
    }
  }

  public var shareButtonBehavior: PreferredShareButtonBehavior {
    didSet {
      storage.shareButtonBehavior = shareButtonBehavior
    }
  }

  public var boostButtonBehavior: PreferredBoostButtonBehavior {
    didSet {
      storage.boostButtonBehavior = boostButtonBehavior
    }
  }

  public var maxReplyIndentation: UInt {
    didSet {
      storage.maxReplyIndentation = maxReplyIndentation
    }
  }

  public var showReplyIndentation: Bool {
    didSet {
      storage.showReplyIndentation = showReplyIndentation
    }
  }

  public var showAccountPopover: Bool {
    didSet {
      storage.showAccountPopover = showAccountPopover
    }
  }

  public var isSidebarExpanded: Bool {
    didSet {
      storage.isSidebarExpanded = isSidebarExpanded
    }
  }
  
  public var streamHomeTimeline: Bool {
    didSet {
      storage.streamHomeTimeline = streamHomeTimeline
    }
  }

  public var fullTimelineFetch: Bool {
    didSet {
      storage.fullTimelineFetch = fullTimelineFetch
    }
  }

  // Notifications
  public var notificationsTruncateStatusContent: Bool {
    didSet {
      storage.notificationsTruncateStatusContent = notificationsTruncateStatusContent
    }
  }

  public func getRealMaxIndent() -> UInt {
    showReplyIndentation ? maxReplyIndentation : 0
  }

  public enum SwipeActionsIconStyle: String, CaseIterable {
    case iconWithText, iconOnly

    public var description: LocalizedStringKey {
      switch self {
      case .iconWithText:
        "enum.swipeactions.icon-with-text"
      case .iconOnly:
        "enum.swipeactions.icon-only"
      }
    }

    // Have to implement this manually here due to compiler not implicitly
    // inserting `nonisolated`, which leads to a warning:
    //
    //     Main actor-isolated static property 'allCases' cannot be used to
    //     satisfy nonisolated protocol requirement
    //
    public nonisolated static var allCases: [Self] {
      [.iconWithText, .iconOnly]
    }
  }

  public var postVisibility: Models.Visibility {
    if useInstanceContentSettings {
      serverPreferences?.postVisibility ?? .pub
    } else {
      appDefaultPostVisibility
    }
  }

  public func conformReplyVisibilityConstraints() {
    appDefaultReplyVisibility = getReplyVisibility()
  }

  private func getReplyVisibility() -> Models.Visibility {
    getMinVisibility(postVisibility, appDefaultReplyVisibility)
  }

  public func getReplyVisibility(of status: Status) -> Models.Visibility {
    getMinVisibility(getReplyVisibility(), status.visibility)
  }

  private func getMinVisibility(_ vis1: Models.Visibility, _ vis2: Models.Visibility)
    -> Models.Visibility
  {
    let no1 = Self.getIntOfVisibility(vis1)
    let no2 = Self.getIntOfVisibility(vis2)

    return no1 < no2 ? vis1 : vis2
  }

  public var postIsSensitive: Bool {
    if useInstanceContentSettings {
      serverPreferences?.postIsSensitive ?? false
    } else {
      appDefaultPostsSensitive
    }
  }

  public var autoExpandSpoilers: Bool {
    if useInstanceContentSettings {
      serverPreferences?.autoExpandSpoilers ?? true
    } else {
      appAutoExpandSpoilers
    }
  }

  public var autoExpandMedia: ServerPreferences.AutoExpandMedia {
    if useInstanceContentSettings {
      serverPreferences?.autoExpandMedia ?? .hideSensitive
    } else {
      appAutoExpandMedia
    }
  }

  public var notificationsCount: [OauthToken: Int] = [:] {
    didSet {
      for (key, value) in notificationsCount {
        Self.sharedDefault?.set(value, forKey: "push_notifications_count_\(key.createdAt)")
      }
    }
  }

  public var totalNotificationsCount: Int {
    notificationsCount.compactMap { $0.value }.reduce(0, +)
  }

  public func reloadNotificationsCount(tokens: [OauthToken]) {
    notificationsCount = [:]
    for token in tokens {
      notificationsCount[token] =
        Self.sharedDefault?.integer(forKey: "push_notifications_count_\(token.createdAt)") ?? 0
    }
  }

  public var serverPreferences: ServerPreferences?

  public func setClient(client: MastodonClient) {
    self.client = client
    Task {
      await refreshServerPreferences()
    }
  }

  public func refreshServerPreferences() async {
    guard let client, client.isAuth else { return }
    serverPreferences = try? await client.get(endpoint: Accounts.preferences)
  }

  public func markLanguageAsSelected(isoCode: String) {
    var copy = recentlyUsedLanguages
    if let index = copy.firstIndex(of: isoCode) {
      copy.remove(at: index)
    }
    copy.insert(isoCode, at: 0)
    recentlyUsedLanguages = Array(copy.prefix(3))
  }

  public static func getIntOfVisibility(_ vis: Models.Visibility) -> Int {
    switch vis {
    case .direct:
      0
    case .priv:
      1
    case .unlisted:
      2
    case .pub:
      3
    }
  }

  private init() {
    preferredBrowser = storage.preferredBrowser
    showTranslateButton = storage.showTranslateButton
    recentlyUsedLanguages = storage.recentlyUsedLanguages
    isSocialKeyboardEnabled = storage.isSocialKeyboardEnabled
    useInstanceContentSettings = storage.useInstanceContentSettings
    appAutoExpandSpoilers = storage.appAutoExpandSpoilers
    appAutoExpandMedia = storage.appAutoExpandMedia
    appDefaultPostVisibility = storage.appDefaultPostVisibility
    appDefaultReplyVisibility = storage.appDefaultReplyVisibility
    appDefaultPostsSensitive = storage.appDefaultPostsSensitive
    appRequireAltText = storage.appRequireAltText
    autoPlayVideo = storage.autoPlayVideo
    preferredTranslationType = storage.preferredTranslationType
    userDeeplAPIFree = storage.userDeeplAPIFree
    autoDetectPostLanguage = storage.autoDetectPostLanguage
    inAppBrowserReaderView = storage.inAppBrowserReaderView
    hapticTabSelectionEnabled = storage.hapticTabSelectionEnabled
    hapticTimelineEnabled = storage.hapticTimelineEnabled
    hapticButtonPressEnabled = storage.hapticButtonPressEnabled
    soundEffectEnabled = storage.soundEffectEnabled
    showAltTextForMedia = storage.showAltTextForMedia
    showiPadSecondaryColumn = storage.showiPadSecondaryColumn
    swipeActionsStatusTrailingRight = storage.swipeActionsStatusTrailingRight
    swipeActionsStatusTrailingLeft = storage.swipeActionsStatusTrailingLeft
    swipeActionsStatusLeadingLeft = storage.swipeActionsStatusLeadingLeft
    swipeActionsStatusLeadingRight = storage.swipeActionsStatusLeadingRight
    swipeActionsUseThemeColor = storage.swipeActionsUseThemeColor
    swipeActionsIconStyle = storage.swipeActionsIconStyle
    requestedReview = storage.requestedReview
    collapseLongPosts = storage.collapseLongPosts
    shareButtonBehavior = storage.shareButtonBehavior
    boostButtonBehavior = storage.boostButtonBehavior
    pendingShownAtBottom = storage.pendingShownAtBottom
    pendingShownLeft = storage.pendingShownLeft
    maxReplyIndentation = storage.maxReplyIndentation
    showReplyIndentation = storage.showReplyIndentation
    showAccountPopover = storage.showAccountPopover
    muteVideo = storage.muteVideo
    isSidebarExpanded = storage.isSidebarExpanded
    notificationsTruncateStatusContent = storage.notificationsTruncateStatusContent
    streamHomeTimeline = storage.streamHomeTimeline
    fullTimelineFetch = storage.fullTimelineFetch
  }
}

extension UInt: @retroactive RawRepresentable {
  public var rawValue: Int {
    Int(self)
  }

  public init?(rawValue: Int) {
    if rawValue >= 0 {
      self.init(rawValue)
    } else {
      return nil
    }
  }
}
