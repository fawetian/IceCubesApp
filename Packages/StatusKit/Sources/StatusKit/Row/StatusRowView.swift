// 文件功能：帖子行视图 - StatusKit 包的核心 UI 组件
//
// 核心职责：
// - 在时间线中显示单条帖子
// - 处理帖子的所有用户交互（点赞、转发、回复等）
// - 管理帖子的展开/折叠状态
// - 处理过滤和内容警告
// - 提供无障碍访问支持
// - 支持上下文菜单和滑动操作
//
// 技术要点：
// - @MainActor：确保所有 UI 更新在主线程
// - 环境对象：使用多个 @Environment 注入依赖
// - StatusRowViewModel：管理帖子的状态和业务逻辑
// - 条件渲染：根据上下文（时间线/详情）显示不同内容
// - 无障碍：完整的 VoiceOver 支持
// - 性能优化：延迟加载嵌入内容
//
// 视图层次：
// - HStack（缩进线 + 主内容）
//   - 缩进指示器（对话串）
//   - VStack（帖子内容）
//     - 标签视图（置顶、转发、回复标记）
//     - HStack（头像 + 内容）
//       - 头像（可选，根据主题位置）
//       - VStack（帖子主体）
//         - 头部（用户信息、时间）
//         - 内容（文本、媒体、投票等）
//         - 操作按钮（点赞、转发、回复等）
//         - 详情（仅在聚焦时显示）
//
// 交互功能：
// - 点击：导航到帖子详情
// - 长按：显示上下文菜单
// - 滑动：快速操作（点赞、转发等）
// - 拖拽：分享帖子链接
//
// 使用场景：
// - 主时间线：显示关注用户的帖子
// - 本地/联邦时间线：显示公共帖子
// - 通知：显示相关帖子
// - 用户资料：显示用户的帖子
// - 帖子详情：显示单条帖子及其回复
// - 搜索结果：显示匹配的帖子
//
// 依赖关系：
// - 依赖：Models（Status）、Env（Router、Theme）、DesignSystem、NetworkClient
// - 被依赖：TimelineView、NotificationsView、AccountView 等所有显示帖子的地方
//
// 性能考虑：
// - 使用 .onAppear 延迟加载嵌入内容
// - 使用 .redactionReasons 支持占位符模式
// - 避免在滚动时执行昂贵操作
// - 使用 StatusRowViewModel 缓存计算结果

import DesignSystem
import EmojiText
import Env
import Foundation
import Models
import NetworkClient
import SwiftUI

/// 帖子行视图 - 显示单条 Mastodon 帖子的核心 UI 组件
///
/// StatusRowView 是整个应用最重要的 UI 组件之一，负责在各种场景下显示帖子。
///
/// 主要功能：
/// - **内容显示**：显示帖子的文本、媒体、投票、卡片等内容
/// - **用户交互**：处理点赞、转发、回复、书签等操作
/// - **状态管理**：管理展开/折叠、过滤、翻译等状态
/// - **无障碍**：完整的 VoiceOver 和辅助功能支持
/// - **性能优化**：延迟加载和智能渲染
///
/// 显示上下文：
/// - **时间线模式**：在列表中显示，紧凑布局
/// - **详情模式**：单独显示，展开所有内容
///
/// 视图组成：
/// ```
/// StatusRowView
/// ├── 缩进线（对话串）
/// ├── 标签（置顶、转发、回复）
/// ├── 头像（根据主题位置）
/// ├── 头部（用户信息、时间）
/// ├── 内容（文本、媒体、投票）
/// ├── 操作按钮（点赞、转发、回复）
/// └── 详情（统计、时间戳）
/// ```
///
/// 使用示例：
/// ```swift
/// // 在时间线中显示帖子
/// List(statuses) { status in
///     StatusRowView(
///         viewModel: StatusRowViewModel(
///             status: status,
///             client: client,
///             routerPath: routerPath
///         ),
///         context: .timeline
///     )
/// }
///
/// // 在详情页显示帖子
/// StatusRowView(
///     viewModel: viewModel,
///     context: .detail
/// )
/// .environment(\.isStatusFocused, true)
/// ```
///
/// 环境依赖：
/// - **Router**：导航到其他页面
/// - **Theme**：主题和样式配置
/// - **Client**：执行 API 操作
/// - **QuickLook**：媒体预览
///
/// 性能优化：
/// - 使用 `@MainActor` 确保 UI 更新在主线程
/// - 延迟加载嵌入内容（引用的帖子）
/// - 支持占位符模式（skeleton loading）
/// - 避免在滚动时执行网络请求
///
/// 无障碍支持：
/// - 完整的 VoiceOver 标签
/// - 自定义辅助功能操作
/// - 键盘导航支持
/// - 动态字体支持
///
/// - Note: 这是一个复杂的视图，包含 400+ 行代码。理解它的结构对理解整个应用至关重要。
/// - Important: 所有 UI 更新必须在主线程执行（@MainActor）
/// - SeeAlso: `StatusRowViewModel` - 管理帖子的业务逻辑和状态
@MainActor
public struct StatusRowView: View {
  // MARK: - 环境变量

  /// 打开新窗口的操作（macOS/iPadOS）
  ///
  /// 用于在新窗口中打开媒体查看器等内容。
  @Environment(\.openWindow) private var openWindow

  /// 是否处于截图模式
  ///
  /// 在截图模式下，某些 UI 元素（如操作按钮）会被隐藏。
  @Environment(\.isInCaptureMode) private var isInCaptureMode: Bool

  /// 视图的遮罩原因
  ///
  /// 用于支持占位符模式（skeleton loading）。
  /// 当包含 .placeholder 时，显示占位符而不是实际内容。
  @Environment(\.redactionReasons) private var reasons

  /// 是否使用紧凑布局
  ///
  /// 在紧凑模式下（如小屏幕设备），某些元素会被隐藏或简化。
  @Environment(\.isCompact) private var isCompact: Bool

  /// VoiceOver 是否启用
  ///
  /// 用于为视障用户提供更好的辅助功能体验。
  /// 启用时，会禁用滑动操作（避免与 VoiceOver 手势冲突）。
  @Environment(\.accessibilityVoiceOverEnabled) private var accessibilityVoiceOverEnabled

  /// 当前帖子是否处于聚焦状态
  ///
  /// 在详情页面，聚焦的帖子会显示更多信息（统计、详细时间等）。
  @Environment(\.isStatusFocused) private var isFocused

  /// 缩进级别（对话串深度）
  ///
  /// 用于在对话串中显示缩进线，表示回复的层级关系。
  /// 0 = 顶级帖子，1+ = 回复
  @Environment(\.indentationLevel) private var indentationLevel

  /// 是否在主时间线中
  ///
  /// 主时间线可能有特殊的显示逻辑或优化。
  @Environment(\.isHomeTimeline) private var isHomeTimeline

  /// 路由路径
  ///
  /// 用于导航到其他页面（用户资料、帖子详情等）。
  @Environment(RouterPath.self) private var routerPath: RouterPath

  /// 快速预览
  ///
  /// 用于显示媒体附件的全屏预览。
  @Environment(QuickLook.self) private var quickLook

  /// 主题
  ///
  /// 提供颜色、字体、布局等主题配置。
  @Environment(Theme.self) private var theme

  /// Mastodon 客户端
  ///
  /// 用于执行 API 操作（点赞、转发、屏蔽等）。
  @Environment(MastodonClient.self) private var client

  // MARK: - 状态属性

  /// 是否显示可选择文本的 Sheet
  ///
  /// 用于让用户复制帖子内容。
  @State private var showSelectableText: Bool = false

  /// 是否显示分享为图片的 Sheet
  ///
  /// 用于将帖子渲染为图片并分享。
  @State private var isShareAsImageSheetPresented: Bool = false

  /// 是否显示屏蔽确认对话框
  ///
  /// 屏蔽用户前需要用户确认。
  @State private var isBlockConfirmationPresented = false

  // MARK: - 公共属性

  /// 显示上下文
  ///
  /// 定义帖子的显示场景，影响布局和交互行为。
  public enum Context {
    /// 时间线模式：在列表中显示，紧凑布局
    case timeline
    /// 详情模式：单独显示，展开所有内容
    case detail
  }

  /// 视图模型
  ///
  /// 管理帖子的状态和业务逻辑。
  /// 包含帖子数据、用户关系、过滤状态等。
  @State public var viewModel: StatusRowViewModel

  /// 显示上下文
  ///
  /// 决定帖子的显示方式（时间线或详情）。
  public let context: Context

  // MARK: - 上下文菜单

  /// 长按帖子时显示的上下文菜单
  ///
  /// 提供的操作：
  /// - 复制文本
  /// - 分享为图片
  /// - 屏蔽用户
  /// - 其他帖子操作
  var contextMenu: some View {
    StatusRowContextMenu(
      viewModel: viewModel,
      showTextForSelection: $showSelectableText,
      isBlockConfirmationPresented: $isBlockConfirmationPresented,
      isShareAsImageSheetPresented: $isShareAsImageSheetPresented)
  }

  // MARK: - 视图主体

  /// 帖子行的主视图
  ///
  /// 视图结构：
  /// 1. **缩进线**：显示对话串的层级关系
  /// 2. **过滤视图**：如果帖子被过滤，显示过滤原因
  /// 3. **标签行**：显示置顶、转发、回复等标记
  /// 4. **主内容**：
  ///    - 头像（根据主题位置）
  ///    - 头部（用户信息、时间）
  ///    - 内容（文本、媒体、投票）
  ///    - 操作按钮（点赞、转发、回复）
  ///    - 详情（统计、时间戳）
  ///
  /// 交互行为：
  /// - **点击内容**：导航到帖子详情
  /// - **点击头像**：导航到用户资料
  /// - **长按**：显示上下文菜单
  /// - **左滑/右滑**：快速操作
  /// - **拖拽**：分享帖子链接
  ///
  /// 条件渲染：
  /// - 紧凑模式：隐藏某些元素
  /// - 聚焦模式：显示更多详情
  /// - 过滤模式：显示过滤警告或完全隐藏
  /// - 占位符模式：显示骨架屏
  public var body: some View {
    HStack(spacing: 0) {
      // MARK: 缩进线（对话串层级指示器）

      // 在非紧凑模式下，显示对话串的缩进线
      // 每个缩进级别显示一条竖线，最后一级高亮显示
      if !isCompact {
        HStack(spacing: 3) {
          ForEach(0..<indentationLevel, id: \.self) { level in
            Rectangle()
              .fill(theme.tintColor)
              .frame(width: 2)
              .accessibilityHidden(true)
              // 最后一级缩进线完全不透明，其他级别半透明
              .opacity((indentationLevel == level + 1) ? 1 : 0.15)
          }
        }
        // 缩进线和内容之间的间距
        if indentationLevel > 0 {
          Spacer(minLength: 8)
        }
      }

      // MARK: 主内容区域

      VStack(alignment: .leading, spacing: .statusComponentSpacing) {
        // MARK: 过滤状态处理

        // 如果帖子被过滤器匹配，根据过滤动作显示不同内容
        if viewModel.isFiltered, let filter = viewModel.filter {
          switch filter.filter.filterAction {
          case .warn:
            // 警告模式：显示过滤原因，但允许用户查看
            makeFilterView(filter: filter.filter)
          case .hide:
            // 隐藏模式：完全不显示内容
            EmptyView()
          }
        } else {
          // MARK: 正常显示模式
          // MARK: 标签行（置顶、转发、回复标记）

          // 在非紧凑模式和非详情页显示标签
          // 标签包括：置顶标记、转发标记、回复标记
          if !isCompact && context != .detail {
            Group {
              StatusRowTagView(viewModel: viewModel)  // 置顶标记
              StatusRowReblogView(viewModel: viewModel)  // 转发标记
              StatusRowReplyView(viewModel: viewModel)  // 回复标记
            }
            .padding(
              .leading,
              // 如果头像在顶部，标签不需要缩进
              // 如果头像在左侧，标签需要缩进以对齐内容
              theme.avatarPosition == .top
                ? 0 : AvatarView.FrameConfig.status.width + .statusColumnsSpacing)
          }

          // MARK: 主内容行（头像 + 内容）

          HStack(alignment: .top, spacing: .statusColumnsSpacing) {
            // MARK: 头像（左侧位置）

            // 如果主题设置头像在左侧，且不是紧凑模式，显示头像
            if !isCompact,
              theme.avatarPosition == .leading
            {
              AvatarView(viewModel.finalStatus.account.avatar)
                .accessibility(addTraits: .isButton)  // 标记为可点击按钮
                .contentShape(Circle())  // 点击区域为圆形
                .hoverEffect()  // 鼠标悬停效果
                .onTapGesture {
                  // 点击头像导航到用户资料页
                  viewModel.navigateToAccountDetail(account: viewModel.finalStatus.account)
                }
            }

            // MARK: 内容列（头部 + 内容 + 操作 + 详情）

            VStack(alignment: .leading, spacing: .statusComponentSpacing) {
              // MARK: 头部（用户信息、时间）

              // 在非紧凑模式下显示头部
              if !isCompact {
                StatusRowHeaderView(viewModel: viewModel)
              }

              // MARK: 帖子内容（文本、媒体、投票、卡片）

              StatusRowContentView(viewModel: viewModel)
                .contentShape(Rectangle())  // 整个内容区域可点击
                .onTapGesture {
                  // 如果不是聚焦状态，点击导航到详情页
                  guard !isFocused else { return }
                  viewModel.navigateToDetail()
                }
                .accessibilityActions {
                  // 在聚焦状态下，添加辅助功能操作
                  if isFocused, viewModel.showActions {
                    accessibilityActions
                  }
                }

              // MARK: 操作按钮（点赞、转发、回复、书签）

              // 显示条件：
              // 1. 不是占位符模式
              // 2. 允许显示操作
              // 3. 聚焦状态或主题设置显示操作
              // 4. 不在截图模式
              if !reasons.contains(.placeholder),
                viewModel.showActions, isFocused || theme.statusActionsDisplay != .none,
                !isInCaptureMode
              {
                StatusRowActionsView(
                  isBlockConfirmationPresented: $isBlockConfirmationPresented,
                  viewModel: viewModel
                )
                // 聚焦时使用主题色，否则使用灰色
                .tint(isFocused ? theme.tintColor : .gray)
              }

              // MARK: 详情（统计、详细时间）

              // 仅在聚焦且非紧凑模式下显示
              if isFocused, !isCompact {
                StatusRowDetailView(viewModel: viewModel)
              }
            }
          }
        }
      }
      // 根据模式和状态调整内边距
      .padding(.init(top: isCompact ? 6 : 12, leading: 0, bottom: isFocused ? 12 : 6, trailing: 0))
    }
    // MARK: - 生命周期和交互

    .onAppear {
      // 视图出现时的初始化逻辑

      // 只在非占位符模式下执行
      if !reasons.contains(.placeholder) {
        // 在非紧凑模式下，延迟加载嵌入的帖子（引用、转发）
        // 这是一个性能优化：避免在滚动时加载所有嵌入内容
        if !isCompact, viewModel.embeddedStatus == nil {
          Task {
            await viewModel.loadEmbeddedStatus()
          }
        }
      }
    }
    // 如果帖子有 URL，支持拖拽分享
    .if(viewModel.url != nil) { $0.draggable(viewModel.url!) }

    // MARK: 上下文菜单（长按）

    .contextMenu {
      contextMenu
        .tint(.primary)
        .onAppear {
          // 显示上下文菜单时，加载作者关系
          // 这样可以显示"已关注"、"已屏蔽"等状态
          Task {
            await viewModel.loadAuthorRelationship()
          }
        }
    }

    // MARK: 滑动操作

    // 右滑操作（从右向左滑动）
    .swipeActions(edge: .trailing) {
      // 注意：滑动操作会自动添加到辅助功能操作中，无法移除
      // 因此在 VoiceOver 启用时禁用滑动，避免重复
      if !isCompact, accessibilityVoiceOverEnabled == false {
        StatusRowSwipeView(viewModel: viewModel, mode: .trailing)
      }
    }
    // 左滑操作（从左向右滑动）
    .swipeActions(edge: .leading) {
      // 注意：滑动操作会自动添加到辅助功能操作中，无法移除
      // 因此在 VoiceOver 启用时禁用滑动，避免重复
      if !isCompact, accessibilityVoiceOverEnabled == false {
        StatusRowSwipeView(viewModel: viewModel, mode: .leading)
      }
    }
    // MARK: - 列表样式

    #if os(visionOS)
      // visionOS 特殊样式：圆角背景 + 悬停效果
      .listRowBackground(
        RoundedRectangle(cornerRadius: 8)
          .foregroundStyle(.background).hoverEffect()
      )
      .listRowHoverEffectDisabled()
    #else
      // 其他平台：使用视图模型提供的背景色
      // 背景色可能根据帖子状态变化（如：已读/未读）
      .listRowBackground(viewModel.backgroundColor)
    #endif
    // 列表行的内边距
    .listRowInsets(
      .init(
        top: 0,
        leading: .layoutPadding,
        bottom: 0,
        trailing: .layoutPadding)
    )

    // MARK: - 无障碍支持

    // 辅助功能元素配置
    // 聚焦时：包含所有子元素（可以单独访问）
    // 非聚焦时：合并为单个元素（整体朗读）
    .accessibilityElement(children: isFocused ? .contain : .combine)

    // 辅助功能标签
    // 在非聚焦且 VoiceOver 启用时，提供完整的帖子描述
    .accessibilityLabel(
      isFocused == false && accessibilityVoiceOverEnabled
        ? StatusRowAccessibilityLabel(viewModel: viewModel).finalLabel() : Text("")
    )

    // 如果帖子被完全隐藏，对辅助功能也隐藏
    .accessibilityHidden(viewModel.filter?.filter.filterAction == .hide)

    // 默认辅助功能操作：导航到详情
    .accessibilityAction {
      guard !isFocused else { return }
      viewModel.navigateToDetail()
    }

    // 自定义辅助功能操作（回复、引用、查看媒体等）
    .accessibilityActions {
      if !isFocused, viewModel.showActions, accessibilityVoiceOverEnabled {
        accessibilityActions
      }
    }

    // MARK: - 背景点击区域

    // 扩展点击区域到整个背景
    // 这样用户可以点击帖子的任何空白区域来查看详情
    .background {
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          guard !isFocused else { return }
          viewModel.navigateToDetail()
        }
    }
    // MARK: - 覆盖层和对话框

    // 加载远程内容时的覆盖层
    // 当从其他实例获取完整帖子内容时显示
    .overlay {
      if viewModel.isLoadingRemoteContent {
        remoteContentLoadingView
      }
    }

    // MARK: 删除确认对话框

    .alert(
      isPresented: $viewModel.showDeleteAlert,
      content: {
        Alert(
          title: Text("status.action.delete.confirm.title"),
          message: Text("status.action.delete.confirm.message"),
          primaryButton: .destructive(
            Text("status.action.delete")
          ) {
            Task {
              await viewModel.delete()
            }
          },
          secondaryButton: .cancel()
        )
      }
    )

    // MARK: 屏蔽确认对话框

    .confirmationDialog(
      "",
      isPresented: $isBlockConfirmationPresented
    ) {
      Button("account.action.block", role: .destructive) {
        Task {
          do {
            // 确定要屏蔽的账户（可能是转发者或原作者）
            let operationAccount = viewModel.status.reblog?.account ?? viewModel.status.account
            // 执行屏蔽操作并更新关系状态
            viewModel.authorRelationship = try await client.post(
              endpoint: Accounts.block(id: operationAccount.id))
          } catch {}
        }
      }
    }

    // MARK: - 列表分隔线配置

    // 调整列表分隔线的位置（向左偏移，隐藏分隔线）
    .alignmentGuide(.listRowSeparatorLeading) { _ in
      -100
    }

    // MARK: - Sheet 和环境

    // 可选择文本的 Sheet
    // 允许用户复制帖子内容
    .sheet(isPresented: $showSelectableText) {
      let content =
        viewModel.status.reblog?.content.asSafeMarkdownAttributedString
        ?? viewModel.status.content.asSafeMarkdownAttributedString
      StatusRowSelectableTextView(content: content)
    }

    // 注入状态数据控制器
    // 用于管理帖子的状态（点赞、转发等）
    .environment(
      StatusDataControllerProvider.shared.dataController(
        for: viewModel.finalStatus,
        client: viewModel.client)
    )

    // MARK: - 翻译错误提示

    // DeepL 翻译错误提示
    .alert(
      "DeepL couldn't be reached!\nIs the API Key correct?",
      isPresented: $viewModel.deeplTranslationError
    ) {
      Button("alert.button.ok", role: .cancel) {}
      Button("settings.general.translate") {
        // 跳转到翻译设置页面
        RouterPath.settingsStartingPoint = .translation
        routerPath.presentedSheet = .settings
      }
    }

    // 实例翻译服务错误提示
    .alert(
      "The Translation Service of your Instance couldn't be reached!",
      isPresented: $viewModel.instanceTranslationError
    ) {
      Button("alert.button.ok", role: .cancel) {}
      Button("settings.general.translate") {
        // 跳转到翻译设置页面
        RouterPath.settingsStartingPoint = .translation
        routerPath.presentedSheet = .settings
      }
    }

    // MARK: - Apple 翻译（iOS 18+）

    #if canImport(_Translation_SwiftUI)
      // 使用 Apple 的系统翻译功能
      .addTranslateView(
        isPresented: $viewModel.showAppleTranslation, text: viewModel.finalStatus.content.asRawText)
    #endif
  }

  // MARK: - 辅助功能操作

  /// 为 VoiceOver 用户提供的自定义操作
  ///
  /// 这些操作在 VoiceOver 启用时可用，提供快速访问常用功能。
  ///
  /// 包含的操作：
  /// - **回复**：回复这条帖子
  /// - **引用**：引用这条帖子
  /// - **查看媒体**：打开媒体查看器
  /// - **展开/折叠**：切换内容警告
  /// - **查看用户**：导航到用户资料
  /// - **查看链接**：打开帖子中的链接
  ///
  /// - Note: 这些操作补充了滑动操作，因为滑动操作在 VoiceOver 启用时被禁用
  @ViewBuilder
  private var accessibilityActions: some View {
    // MARK: 基本操作

    // 回复操作
    // 注意：这个操作在滑动手势被移除时会丢失，所以在这里添加
    Button("status.action.reply") {
      HapticManager.shared.fireHaptic(.notification(.success))
      viewModel.routerPath.presentedSheet = .replyToStatusEditor(status: viewModel.status)
    }

    // 引用操作
    // 注意：这个操作在滑动手势被移除时会丢失，所以在这里添加
    Button("settings.swipeactions.status.action.quote") {
      HapticManager.shared.fireHaptic(.notification(.success))
      viewModel.routerPath.presentedSheet = .quoteStatusEditor(status: viewModel.status)
    }
    // 私信和仅关注者可见的帖子不能引用
    .disabled(viewModel.status.visibility == .direct || viewModel.status.visibility == .priv)

    // MARK: 媒体查看

    // 如果帖子包含媒体附件，提供查看媒体的操作
    if viewModel.finalStatus.mediaAttachments.isEmpty == false {
      Button("accessibility.status.media-viewer-action.label") {
        HapticManager.shared.fireHaptic(.notification(.success))
        let attachments = viewModel.finalStatus.mediaAttachments
        #if targetEnvironment(macCatalyst) || os(visionOS)
          // macOS 和 visionOS：在新窗口中打开
          openWindow(
            value: WindowDestinationMedia.mediaViewer(
              attachments: attachments,
              selectedAttachment: attachments[0]
            ))
        #else
          // iOS/iPadOS：使用 QuickLook 预览
          quickLook.prepareFor(
            selectedMediaAttachment: attachments[0], mediaAttachments: attachments)
        #endif
      }
    }

    // MARK: 内容警告切换

    // 展开或折叠内容警告
    Button(viewModel.displaySpoiler ? "status.show-more" : "status.show-less") {
      withAnimation {
        viewModel.displaySpoiler.toggle()
      }
    }

    // MARK: 用户导航

    // 导航到帖子作者的资料页
    Button("@\(viewModel.status.account.username)") {
      HapticManager.shared.fireHaptic(.notification(.success))
      viewModel.routerPath.navigate(to: .accountDetail(id: viewModel.status.account.id))
    }

    // 如果是转发，添加原作者的导航
    // 例如：Alice 转发了 Bob 的帖子，这里添加 Bob 的链接
    if viewModel.status.account != viewModel.finalStatus.account {
      Button("@\(viewModel.finalStatus.account.username)") {
        HapticManager.shared.fireHaptic(.notification(.success))
        viewModel.routerPath.navigate(to: .accountDetail(id: viewModel.finalStatus.account.id))
      }
    }

    // MARK: 内容链接

    // 为帖子内容中检测到的每个链接添加操作
    ForEach(viewModel.finalStatus.content.links) { link in
      switch link.type {
      case .url:
        // 普通 URL 链接
        if UIApplication.shared.canOpenURL(link.url) {
          Button("accessibility.tabs.timeline.content-link-\(link.title)") {
            HapticManager.shared.fireHaptic(.notification(.success))
            _ = viewModel.routerPath.handle(url: link.url)
          }
        }
      case .hashtag:
        // 话题标签
        Button("accessibility.tabs.timeline.content-hashtag-\(link.title)") {
          HapticManager.shared.fireHaptic(.notification(.success))
          _ = viewModel.routerPath.handle(url: link.url)
        }
      case .mention:
        // 用户提及
        Button("\(link.title)") {
          HapticManager.shared.fireHaptic(.notification(.success))
          _ = viewModel.routerPath.handle(url: link.url)
        }
      }
    }
  }

  // MARK: - 辅助方法

  /// 创建过滤警告视图
  ///
  /// 当帖子匹配过滤器且过滤动作为"警告"时显示。
  ///
  /// - Parameter filter: 匹配的过滤器
  /// - Returns: 显示过滤原因和"仍然显示"按钮的视图
  ///
  /// 功能：
  /// - 显示过滤器的标题
  /// - 提供"仍然显示"按钮
  /// - 点击任何位置都可以显示内容
  /// - 支持辅助功能操作
  private func makeFilterView(filter: Filter) -> some View {
    HStack {
      // 显示过滤原因
      Text("status.filter.filtered-by-\(filter.title)")

      // "仍然显示"按钮
      Button {
        withAnimation {
          viewModel.isFiltered = false
        }
      } label: {
        Text("status.filter.show-anyway")
          .foregroundStyle(theme.tintColor)
      }
      .buttonStyle(.plain)
    }
    // 点击整个区域都可以显示内容
    .onTapGesture {
      withAnimation {
        viewModel.isFiltered = false
      }
    }
    // 辅助功能操作
    .accessibilityAction {
      viewModel.isFiltered = false
    }
  }

  /// 远程内容加载视图
  ///
  /// 当从其他实例获取完整帖子内容时显示的加载指示器。
  ///
  /// 显示场景：
  /// - 点击来自其他实例的帖子链接
  /// - 需要获取完整的帖子数据
  ///
  /// 视觉效果：
  /// - 半透明黑色背景
  /// - 居中的加载指示器
  /// - 淡入淡出动画
  private var remoteContentLoadingView: some View {
    ZStack(alignment: .center) {
      VStack {
        Spacer()
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
        Spacer()
      }
    }
    .background(Color.black.opacity(0.40))
    .transition(.opacity)
  }
}

// MARK: - SwiftUI 预览

/// StatusRowView 的预览
///
/// 显示三个占位符帖子的列表，用于在 Xcode 中预览视图效果。
///
/// 预览配置：
/// - 使用占位符数据（.placeholder()）
/// - 时间线上下文
/// - 纯列表样式
/// - 预览环境配置
/// - 共享主题
///
/// 用途：
/// - 在 Xcode 中快速查看视图效果
/// - 测试不同的布局和样式
/// - 验证响应式设计
#Preview {
  List {
    StatusRowView(
      viewModel:
        .init(
          status: .placeholder(),
          client: .init(server: ""),
          routerPath: RouterPath()),
      context: .timeline)
    StatusRowView(
      viewModel:
        .init(
          status: .placeholder(),
          client: .init(server: ""),
          routerPath: RouterPath()),
      context: .timeline)
    StatusRowView(
      viewModel:
        .init(
          status: .placeholder(),
          client: .init(server: ""),
          routerPath: RouterPath()),
      context: .timeline)
  }
  .listStyle(.plain)
  .withPreviewsEnv()
  .environment(Theme.shared)
}
