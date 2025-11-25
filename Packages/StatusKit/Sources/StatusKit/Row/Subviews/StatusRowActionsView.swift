/*
 * StatusRowActionsView.swift
 * IceCubesApp - 帖子操作按钮组件
 *
 * 功能描述：
 * 显示帖子的所有操作按钮（回复、转发、点赞、书签、分享、菜单）
 * 处理用户交互并执行相应的操作
 *
 * 核心功能：
 * 1. 操作按钮显示 - 根据配置显示不同的操作按钮
 * 2. 交互处理 - 处理点击、长按等用户交互
 * 3. 状态同步 - 同步按钮状态（已点赞、已转发等）
 * 4. 计数显示 - 显示回复数、点赞数、转发数
 * 5. 分享功能 - 支持链接分享和链接+文本分享
 * 6. 上下文菜单 - 长按显示更多操作
 * 7. 远程状态 - 自动拉取远程帖子以启用操作
 * 8. 乐观更新 - 立即更新 UI，后台同步服务器
 * 9. 触觉反馈 - 操作时提供触觉和声音反馈
 * 10. 可见性限制 - 根据帖子可见性限制某些操作
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @Environment - 环境依赖注入
 * 3. @Binding - 双向数据绑定
 * 4. @State - 本地状态管理
 * 5. ViewBuilder - 条件视图构建
 * 6. ShareLink - iOS 16+ 原生分享
 * 7. HStack - 水平布局
 * 8. 枚举配置 - 按钮配置和行为
 * 9. 条件编译 - macCatalyst 和 visionOS 适配
 * 10. WindowGroup - macCatalyst/visionOS 窗口管理
 *
 * 视图层次：
 * - VStack
 *   - HStack（actionsRow）
 *     - ForEach（遍历 actions）
 *       - actionButton / shareActionView / menuActionView
 *
 * 按钮类型：
 * - respond: 回复按钮
 * - boost: 转发按钮（或引用，取决于配置）
 * - quote: 引用按钮
 * - favorite: 点赞按钮
 * - bookmark: 书签按钮
 * - share: 分享按钮
 * - menu: 更多菜单按钮
 *
 * 按钮行为配置：
 * - boostOnly: 只显示转发
 * - quoteOnly: 只显示引用
 * - both: 显示转发+菜单（包含引用）
 *
 * 操作流程：
 * 1. 用户点击按钮
 * 2. 检查是否为远程帖子，如需拉取本地副本
 * 3. 播放声音和触觉反馈
 * 4. 执行操作（乐观更新 UI）
 * 5. 后台同步到服务器
 * 6. 更新按钮状态和计数
 *
 * 使用场景：
 * - 时间线中的帖子操作栏
 * - 帖子详情页的操作栏
 * - 通知中的帖子操作
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 环境对象和路由
 * - Models: 数据模型
 * - NetworkClient: API 客户端
 */

import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

/// 帖子操作按钮视图
///
/// 显示帖子的所有操作按钮并处理用户交互。
///
/// 主要功能：
/// - **按钮显示**：根据用户配置显示不同的操作按钮
/// - **交互处理**：处理点击、长按等用户交互
/// - **状态同步**：同步按钮状态和计数
/// - **远程操作**：自动处理远程帖子的本地化
/// - **触觉反馈**：提供声音和触觉反馈
///
/// 使用示例：
/// ```swift
/// StatusRowActionsView(
///     viewModel: viewModel,
///     isBlockConfirmationPresented: $isBlockConfirmationPresented
/// )
/// ```
///
/// - Note: 所有操作都是乐观更新，先更新 UI 再同步服务器
/// - Important: 远程帖子需要先拉取本地副本才能执行操作
@MainActor
struct StatusRowActionsView: View {
  /// 主题设置
  @Environment(Theme.self) private var theme
  /// 当前账户信息
  @Environment(CurrentAccount.self) private var currentAccount
  /// 帖子数据控制器（管理帖子状态）
  @Environment(StatusDataController.self) private var statusDataController
  /// 用户偏好设置
  @Environment(UserPreferences.self) private var userPreferences
  /// Mastodon API 客户端
  @Environment(MastodonClient.self) private var client
  /// 场景代理（窗口管理）
  @Environment(SceneDelegate.self) private var sceneDelegate

  /// 打开新窗口的环境方法
  @Environment(\.openWindow) private var openWindow
  /// 帖子是否聚焦（影响计数显示）
  @Environment(\.isStatusFocused) private var isFocused
  /// 水平尺寸类别（compact/regular）
  @Environment(\.horizontalSizeClass) var horizontalSizeClass

  /// 是否显示可选文本弹窗
  @State private var showTextForSelection: Bool = false
  /// 是否显示分享为图片的弹窗
  @State private var isShareAsImageSheetPresented: Bool = false

  /// 是否显示屏蔽确认弹窗（父视图传入）
  @Binding var isBlockConfirmationPresented: Bool

  /// 操作按钮配置
  ///
  /// 定义按钮的显示类型和触发类型。
  struct ActionButtonConfiguration {
    /// 显示的按钮类型
    let display: Action
    /// 实际触发的操作类型
    let trigger: Action
    /// 是否显示菜单（用于转发/引用选择）
    let showsMenu: Bool
  }

  /// 帖子行视图模型
  var viewModel: StatusRowViewModel

  /// 是否为窄屏布局
  ///
  /// 在 iPad 或 Mac 的紧凑模式下返回 true。
  var isNarrow: Bool {
    horizontalSizeClass == .compact
      && (UIDevice.current.userInterfaceIdiom == .pad
        || UIDevice.current.userInterfaceIdiom == .mac)
  }

  /// 是否为私有转发
  ///
  /// 当帖子可见性为私有且是当前用户发布时返回 true。
  /// 私有帖子只能转发给关注者。
  ///
  /// - Returns: 是否为私有转发
  func privateBoost() -> Bool {
    viewModel.status.visibility == .priv
      && viewModel.status.account.id == currentAccount.account?.id
  }

  /// 操作按钮数组
  ///
  /// 根据用户配置的次要操作类型返回不同的按钮组合。
  ///
  /// - 分享模式：回复、转发、点赞、分享、菜单
  /// - 书签模式：回复、转发、点赞、书签、菜单
  var actions: [Action] {
    switch theme.statusActionSecondary {
    case .share:
      return [.respond, .boost, .favorite, .share, .menu]
    case .bookmark:
      return [.respond, .boost, .favorite, .bookmark, .menu]
    }
  }

  /// 操作类型枚举
  ///
  /// 定义所有可用的帖子操作类型。
  @MainActor
  enum Action {
    /// 回复
    case respond
    /// 转发（Boost）
    case boost
    /// 引用（Quote）
    case quote
    /// 点赞
    case favorite
    /// 书签
    case bookmark
    /// 分享
    case share
    /// 更多菜单
    case menu

    /// 获取操作的图标
    ///
    /// 根据操作类型和当前状态返回对应的 SF Symbol 图标。
    ///
    /// - Parameters:
    ///   - dataController: 帖子数据控制器
    ///   - privateBoost: 是否为私有转发
    /// - Returns: 图标
    func image(dataController: StatusDataController, privateBoost: Bool = false) -> Image {
      switch self {
      case .respond:
        return Image(systemName: "arrowshape.turn.up.left")
      case .boost:
        if privateBoost {
          if dataController.isReblogged {
            return Image(systemName: "arrow.2.squarepath")
          } else {
            return Image(systemName: "lock.rotation")
          }
        }
        return Image(systemName: "arrow.2.squarepath")
      case .favorite:
        return Image(systemName: dataController.isFavorited ? "star.fill" : "star")
      case .bookmark:
        return Image(systemName: dataController.isBookmarked ? "bookmark.fill" : "bookmark")
      case .share:
        return Image(systemName: "square.and.arrow.up")
      case .quote:
        return Image(systemName: "quote.bubble")
      case .menu:
        return Image(systemName: "ellipsis")
      }
    }

    /// 获取无障碍标签
    ///
    /// 根据操作类型和当前状态返回本地化的无障碍标签。
    ///
    /// - Parameters:
    ///   - dataController: 帖子数据控制器
    ///   - privateBoost: 是否为私有转发
    /// - Returns: 本地化字符串键
    func accessibilityLabel(dataController: StatusDataController, privateBoost: Bool = false)
      -> LocalizedStringKey
    {
      switch self {
      case .respond:
        return "status.action.reply"
      case .boost:
        if dataController.isReblogged {
          return "status.action.unboost"
        }
        return privateBoost
          ? "status.action.boost-to-followers"
          : "status.action.boost"
      case .favorite:
        return dataController.isFavorited
          ? "status.action.unfavorite"
          : "status.action.favorite"
      case .bookmark:
        return dataController.isBookmarked
          ? "status.action.unbookmark"
          : "status.action.bookmark"
      case .share:
        return "status.action.share"
      case .menu:
        return "status.context.menu"
      case .quote:
        return "Quote"
      }
    }

    /// 获取操作计数
    ///
    /// 根据操作类型返回对应的计数（回复数、点赞数、转发数）。
    /// 如果主题设置为离散显示且帖子未聚焦，则不显示计数。
    ///
    /// - Parameters:
    ///   - dataController: 帖子数据控制器
    ///   - isFocused: 帖子是否聚焦
    ///   - theme: 主题设置
    /// - Returns: 计数值（nil 表示不显示）
    func count(dataController: StatusDataController, isFocused: Bool, theme: Theme) -> Int? {
      if theme.statusActionsDisplay == .discret, !isFocused {
        return nil
      }
      switch self {
      case .respond:
        return dataController.repliesCount
      case .favorite:
        return dataController.favoritesCount
      case .boost, .quote:
        return dataController.reblogsCount + dataController.quotesCount
      case .share, .bookmark, .menu:
        return nil
      }
    }

    /// 获取操作的色调颜色
    ///
    /// 返回操作按钮激活时的色调颜色。
    ///
    /// - Parameter theme: 主题设置
    /// - Returns: 色调颜色（nil 表示使用默认颜色）
    func tintColor(theme: Theme) -> Color? {
      switch self {
      case .respond, .share, .menu, .quote:
        nil
      case .favorite:
        .yellow
      case .bookmark:
        .pink
      case .boost:
        theme.tintColor
      }
    }

    /// 检查操作是否处于激活状态
    ///
    /// 返回按钮是否应该显示为激活状态（例如已点赞、已转发）。
    ///
    /// - Parameter dataController: 帖子数据控制器
    /// - Returns: 是否激活
    func isOn(dataController: StatusDataController) -> Bool {
      switch self {
      case .respond, .share, .menu, .quote: false
      case .favorite: dataController.isFavorited
      case .bookmark: dataController.isBookmarked
      case .boost: dataController.isReblogged
      }
    }
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 12) {
      actionsRow
    }
    .fixedSize(horizontal: false, vertical: true)
    .sheet(isPresented: $showTextForSelection, content: makeSelectableTextSheet)
    .sheet(isPresented: $isShareAsImageSheetPresented, content: makeShareAsImageSheet)
  }

  // MARK: - 视图组件

  /// 操作按钮行
  ///
  /// 水平排列所有操作按钮。
  private var actionsRow: some View {
    HStack {
      ForEach(actions, id: \.self) { action in
        actionView(for: action)
      }
    }
  }

  /// 根据操作类型创建对应的视图
  ///
  /// - Parameter action: 操作类型
  /// - Returns: 操作视图
  @ViewBuilder
  private func actionView(for action: Action) -> some View {
    switch action {
    case .share:
      shareActionView(for: action)
    case .menu:
      menuActionView()
    default:
      actionButton(action: action)
    }
  }

  /// 创建分享操作视图
  ///
  /// 使用原生 ShareLink 创建分享按钮。
  ///
  /// - Parameter action: 分享操作
  /// - Returns: 分享视图
  @ViewBuilder
  private func shareActionView(for action: Action) -> some View {
    if let urlString = viewModel.finalStatus.url,
      let url = URL(string: urlString)
    {
      HStack {
        shareLink(for: url, action: action)
        Spacer()
      }
    } else {
      EmptyView()
    }
  }

  /// 创建菜单操作视图
  ///
  /// 显示上下文菜单，包含更多操作选项。
  ///
  /// - Returns: 菜单视图
  @ViewBuilder
  private func menuActionView() -> some View {
    Menu {
      StatusRowContextMenu(
        viewModel: viewModel,
        showTextForSelection: $showTextForSelection,
        isBlockConfirmationPresented: $isBlockConfirmationPresented,
        isShareAsImageSheetPresented: $isShareAsImageSheetPresented
      )
      .onAppear {
        Task {
          await viewModel.loadAuthorRelationship()
        }
      }
    } label: {
      Label("", systemImage: "ellipsis")
        .padding(.vertical, 6)
    }
    .menuStyle(.button)
    .buttonStyle(.borderless)
    .foregroundStyle(.secondary)
    .tint(.primary)
    .contentShape(Rectangle())
    .accessibilityLabel("status.action.context-menu")
  }

  /// 创建分享链接
  ///
  /// 根据用户偏好设置创建不同类型的分享链接：
  /// - linkOnly: 仅分享链接
  /// - linkAndText: 分享链接和文本内容
  ///
  /// - Parameters:
  ///   - url: 帖子 URL
  ///   - action: 分享操作
  /// - Returns: 分享链接视图
  @ViewBuilder
  private func shareLink(for url: URL, action: Action) -> some View {
    switch userPreferences.shareButtonBehavior {
    case .linkOnly:
      shareLinkView(
        ShareLink(item: url) {
          shareButtonLabel(for: action)
        }
      )
    case .linkAndText:
      shareLinkView(
        ShareLink(
          item: url,
          subject: Text(viewModel.finalStatus.account.safeDisplayName),
          message: Text(viewModel.finalStatus.content.asRawText)
        ) {
          shareButtonLabel(for: action)
        }
      )
    }
  }

  /// 创建分享链接视图包装器
  ///
  /// 统一处理分享链接的样式和无障碍属性。
  ///
  /// - Parameter view: 分享链接视图
  /// - Returns: 包装后的视图
  @ViewBuilder
  private func shareLinkView<V: View>(_ view: V) -> some View {
    view
      .buttonStyle(.borderless)
      #if !os(visionOS)
        .offset(x: -8)
      #endif
      .accessibilityElement(children: .combine)
      .accessibilityLabel("status.action.share-link")
  }

  /// 创建分享按钮标签
  ///
  /// - Parameter action: 分享操作
  /// - Returns: 按钮标签视图
  private func shareButtonLabel(for action: Action) -> some View {
    action
      .image(dataController: statusDataController)
      .foregroundColor(Color(UIColor.secondaryLabel))
      .padding(.vertical, 6)
      .padding(.horizontal, 8)
      .contentShape(Rectangle())
      #if targetEnvironment(macCatalyst)
        .font(.scaledBody)
      #else
        .font(.body)
        .dynamicTypeSize(.large)
      #endif
  }

  /// 创建可选文本弹窗
  ///
  /// 显示帖子的纯文本内容，支持文本选择和复制。
  ///
  /// - Returns: 可选文本视图
  private func makeSelectableTextSheet() -> some View {
    let content =
      viewModel.status.reblog?.content.asSafeMarkdownAttributedString
      ?? viewModel.status.content.asSafeMarkdownAttributedString
    return StatusRowSelectableTextView(content: content)
      .tint(theme.tintColor)
  }

  /// 创建分享为图片弹窗
  ///
  /// 将帖子渲染为图片并提供分享选项。
  ///
  /// - Returns: 分享为图片视图
  private func makeShareAsImageSheet() -> some View {
    let renderer = ImageRenderer(content: AnyView(shareCaptureView))
    renderer.isOpaque = true
    renderer.scale = 3.0
    return StatusRowShareAsImageView(
      viewModel: viewModel,
      renderer: renderer
    )
    .tint(theme.tintColor)
  }

  /// 分享捕获视图
  ///
  /// 用于渲染成图片的帖子视图，包含完整的环境配置。
  private var shareCaptureView: some View {
    HStack {
      StatusRowView(viewModel: viewModel, context: .timeline)
        .padding(8)
    }
    .environment(\.isInCaptureMode, true)
    .environment(RouterPath())
    .environment(QuickLook.shared)
    .environment(theme)
    .environment(client)
    .environment(sceneDelegate)
    .environment(UserPreferences.shared)
    .environment(CurrentAccount.shared)
    .environment(CurrentInstance.shared)
    .environment(statusDataController)
    .preferredColorScheme(theme.selectedScheme == .dark ? .dark : .light)
    .foregroundColor(theme.labelColor)
    .background(theme.primaryBackgroundColor)
    .frame(width: sceneDelegate.windowWidth - 12)
    .tint(theme.tintColor)
  }

  // MARK: - 操作处理

  /// 创建操作按钮
  ///
  /// 根据操作类型和帖子状态创建对应的操作按钮。
  ///
  /// 按钮禁用逻辑：
  /// - 私有/私信帖子：禁用转发
  /// - 引用不可用：禁用引用
  ///
  /// - Parameter action: 操作类型
  /// - Returns: 操作按钮视图
  @ViewBuilder
  private func actionButton(action: Action) -> some View {
    let configuration = configuration(for: action)
    let finalStatus = viewModel.finalStatus
    let isQuoteUnavailable =
      (finalStatus.visibility == .priv || finalStatus.visibility == .direct)
      || finalStatus.quoteApproval?.currentUser == .denied
    let shouldDisableAction =
      (configuration.trigger == .boost
        && (finalStatus.visibility == .priv || finalStatus.visibility == .direct))
      || (configuration.trigger == .quote && isQuoteUnavailable)

    StatusActionButton(
      configuration: configuration,
      statusDataController: statusDataController,
      status: viewModel.status,
      quoteStatus: finalStatus,
      theme: theme,
      isFocused: isFocused,
      isNarrow: isNarrow,
      isRemoteStatus: viewModel.isRemote,
      privateBoost: privateBoost(),
      isDisabled: shouldDisableAction,
      handleAction: handleAction(action:)
    )
  }

  /// 获取操作按钮配置
  ///
  /// 根据用户的转发按钮行为偏好返回对应的按钮配置。
  ///
  /// 配置选项：
  /// - both: 转发 + 菜单（包含引用选项）
  /// - boostOnly: 仅转发
  /// - quoteOnly: 仅引用
  ///
  /// - Parameter action: 操作类型
  /// - Returns: 按钮配置
  private func configuration(for action: Action) -> ActionButtonConfiguration {
    guard action == .boost else {
      return .init(display: action, trigger: action, showsMenu: false)
    }

    switch userPreferences.boostButtonBehavior {
    case .both:
      return .init(display: .boost, trigger: .boost, showsMenu: true)
    case .boostOnly:
      return .init(display: .boost, trigger: .boost, showsMenu: false)
    case .quoteOnly:
      return .init(display: .quote, trigger: .quote, showsMenu: false)
    }
  }

  /// 处理操作执行
  ///
  /// 执行用户触发的操作，流程包括：
  /// 1. 检查是否为远程帖子，如需拉取本地副本
  /// 2. 播放触觉和声音反馈
  /// 3. 执行具体操作（回复、点赞、转发等）
  /// 4. 更新 UI 状态（乐观更新）
  ///
  /// 操作类型：
  /// - respond: 打开回复编辑器
  /// - favorite: 切换点赞状态
  /// - bookmark: 切换书签状态
  /// - boost: 切换转发状态
  /// - quote: 打开引用编辑器
  ///
  /// - Parameter action: 要执行的操作
  private func handleAction(action: Action) {
    Task {
      // 1. 处理远程帖子
      if viewModel.isRemote, viewModel.localStatusId == nil || viewModel.localStatus == nil {
        guard await viewModel.fetchRemoteStatus() else {
          return
        }
      }

      // 2. 触觉反馈
      HapticManager.shared.fireHaptic(.notification(.success))

      // 3. 执行具体操作
      switch action {
      case .respond:
        SoundEffectManager.shared.playSound(.share)
        #if targetEnvironment(macCatalyst) || os(visionOS)
          openWindow(
            value: WindowDestinationEditor.replyToStatusEditor(
              status: viewModel.localStatus ?? viewModel.status))
        #else
          viewModel.routerPath.presentedSheet = .replyToStatusEditor(
            status: viewModel.localStatus ?? viewModel.status)
        #endif
      case .favorite:
        SoundEffectManager.shared.playSound(.favorite)
        await statusDataController.toggleFavorite(remoteStatus: viewModel.localStatusId)
      case .bookmark:
        SoundEffectManager.shared.playSound(.bookmark)
        await statusDataController.toggleBookmark(remoteStatus: viewModel.localStatusId)
      case .boost:
        SoundEffectManager.shared.playSound(.boost)
        await statusDataController.toggleReblog(remoteStatus: viewModel.localStatusId)
      case .quote:
        SoundEffectManager.shared.playSound(.boost)
        #if targetEnvironment(macCatalyst) || os(visionOS)
          openWindow(value: WindowDestinationEditor.quoteStatusEditor(status: viewModel.status))
        #else
          viewModel.routerPath.presentedSheet = .quoteStatusEditor(status: viewModel.status)
        #endif
      default:
        break
      }
    }
  }
}
