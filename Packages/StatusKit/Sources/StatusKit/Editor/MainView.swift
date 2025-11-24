// 文件功能：帖子编辑器主视图 - StatusEditor 的核心 UI 容器
//
// 核心职责：
// - 提供帖子编辑的主界面
// - 管理主帖子和后续帖子（帖子串）
// - 处理编辑器的焦点状态
// - 管理媒体编辑容器
// - 控制展示模式（sheet 的高度）
// - 协调多个编辑器视图的状态
//
// 技术要点：
// - @MainActor：确保所有 UI 更新在主线程
// - @State：管理编辑器的本地状态
// - @FocusState：管理输入焦点
// - NavigationStack：提供导航容器
// - ScrollView：支持滚动和多帖子编辑
// - PresentationDetent：控制 sheet 的展示高度
//
// 视图层次：
// - NavigationStack
//   - ZStack
//     - 背景色
//     - ScrollView
//       - VStack
//         - EditorView（主帖子）
//         - EditorView（后续帖子 1）
//         - EditorView（后续帖子 2）
//         - ...
//     - 工具栏
//
// 编辑模式：
// - 新建帖子：创建全新的帖子
// - 回复：回复其他用户的帖子
// - 编辑：编辑已发布的帖子
// - 引用：引用其他帖子
// - 提及：提及特定用户
// - 分享扩展：从其他应用分享内容
//
// 帖子串功能：
// - 支持创建多条连续的帖子（thread）
// - 每条帖子有独立的编辑器
// - 可以添加或删除后续帖子
// - 按顺序发布所有帖子
//
// 焦点管理：
// - 主帖子焦点：.main
// - 后续帖子焦点：.followUp(index)
// - 自动切换焦点到活动编辑器
//
// 使用场景：
// - 从时间线点击"发帖"按钮
// - 点击"回复"按钮回复帖子
// - 编辑已发布的帖子
// - 从分享扩展分享内容
//
// 依赖关系：
// - 依赖：Models、Env、DesignSystem、NetworkClient
// - 被依赖：StatusEditor（公共接口）
//
// 性能考虑：
// - 使用 @State 而非 @StateObject 减少重建
// - 延迟加载媒体预览
// - 智能管理焦点状态

import AppAccount
import DesignSystem
import EmojiText
import Env
import Models
import NetworkClient
import NukeUI
import PhotosUI
import StoreKit
import SwiftUI
import UIKit

extension StatusEditor {
  /// 帖子编辑器主视图
  ///
  /// MainView 是 StatusEditor 的核心容器，负责管理整个编辑界面。
  ///
  /// 主要功能：
  /// - **多帖子编辑**：支持创建帖子串（thread）
  /// - **焦点管理**：智能管理多个编辑器的焦点
  /// - **状态协调**：协调主帖子和后续帖子的状态
  /// - **展示控制**：管理 sheet 的展示高度
  ///
  /// 编辑器状态：
  /// - `mainSEVM`：主帖子的 ViewModel
  /// - `followUpSEVMs`：后续帖子的 ViewModel 数组
  /// - `editorFocusState`：当前焦点状态
  /// - `editingMediaContainer`：正在编辑的媒体
  ///
  /// 使用示例：
  /// ```swift
  /// // 创建新帖子
  /// StatusEditor.MainView(mode: .new)
  ///
  /// // 回复帖子
  /// StatusEditor.MainView(mode: .replyTo(status: status))
  ///
  /// // 编辑帖子
  /// StatusEditor.MainView(mode: .edit(status: status))
  /// ```
  ///
  /// - Note: 所有 UI 更新必须在主线程执行（@MainActor）
  /// - Important: 支持创建最多 10 条连续帖子的帖子串
  @MainActor
  public struct MainView: View {
    // MARK: - 环境变量

    /// 应用账户管理器
    ///
    /// 管理所有已登录的 Mastodon 账户。
    @Environment(AppAccountsManager.self) private var appAccounts

    /// 当前账户
    ///
    /// 当前正在使用的 Mastodon 账户。
    @Environment(CurrentAccount.self) private var currentAccount

    /// 主题
    ///
    /// 提供颜色、字体等主题配置。
    @Environment(Theme.self) private var theme

    // MARK: - 状态变量

    /// 展示模式
    ///
    /// 控制 sheet 的展示高度：
    /// - `.large`：全屏或接近全屏
    /// - `.medium`：半屏
    /// - `.height(CGFloat)`：自定义高度
    ///
    /// 用户可以通过拖拽调整高度。
    @State private var presentationDetent: PresentationDetent = .large

    /// 主帖子的 ViewModel
    ///
    /// 管理主帖子（帖子串的第一条）的状态和业务逻辑。
    @State private var mainSEVM: ViewModel

    /// 后续帖子的 ViewModel 数组
    ///
    /// 管理帖子串中后续帖子的状态。
    /// 用户可以添加多条后续帖子，形成帖子串（thread）。
    @State private var followUpSEVMs: [ViewModel] = []

    /// 正在编辑的媒体容器
    ///
    /// 当用户点击媒体进行编辑时，存储该媒体的引用。
    /// 用于显示媒体编辑界面（裁剪、添加描述等）。
    @State private var editingMediaContainer: MediaContainer?

    /// 滚动目标 ID
    ///
    /// 用于滚动到特定的编辑器视图。
    @State private var scrollID: UUID?

    /// 编辑器焦点状态
    ///
    /// 跟踪当前哪个编辑器获得焦点：
    /// - `.main`：主帖子编辑器
    /// - `.followUp(index)`：后续帖子编辑器
    ///
    /// 用于管理键盘和输入焦点。
    @FocusState private var editorFocusState: EditorFocusState?

    // MARK: - 计算属性

    /// 当前获得焦点的 ViewModel
    ///
    /// 根据焦点状态返回对应的 ViewModel：
    /// - 如果焦点在后续帖子上，返回对应的 ViewModel
    /// - 否则返回主帖子的 ViewModel
    ///
    /// 用于确定当前正在编辑的帖子。
    private var focusedSEVM: ViewModel {
      if case .followUp(let id) = editorFocusState,
        let sevm = followUpSEVMs.first(where: { $0.id == id })
      {
        return sevm
      }

      return mainSEVM
    }

    /// 背景颜色视图
    ///
    /// 根据展示模式返回不同的背景：
    /// - 全屏模式（.large）：使用主题的主背景色
    /// - 其他模式：透明背景
    ///
    /// 这样可以在不同展示模式下提供更好的视觉效果。
    @ViewBuilder
    private var backgroundColor: some View {
      if presentationDetent == .large {
        theme.primaryBackgroundColor.edgesIgnoringSafeArea(.all)
      }
      Color.clear
    }

    // MARK: - 初始化

    /// 初始化编辑器主视图
    ///
    /// - Parameter mode: 编辑模式
    ///   - `.new`：创建新帖子
    ///   - `.replyTo(status)`：回复帖子
    ///   - `.edit(status)`：编辑已发布的帖子
    ///   - `.quote(status)`：引用帖子
    ///   - `.mention(account)`：提及用户
    ///   - `.shareExtension(items)`：从分享扩展创建
    ///
    /// 使用示例：
    /// ```swift
    /// // 创建新帖子
    /// let view = StatusEditor.MainView(mode: .new)
    ///
    /// // 回复帖子
    /// let view = StatusEditor.MainView(mode: .replyTo(status: status))
    /// ```
    public init(mode: ViewModel.Mode) {
      _mainSEVM = State(initialValue: ViewModel(mode: mode))
    }

    public var body: some View {
      @Bindable var focusedSEVM = focusedSEVM

      NavigationStack {
        ZStack(alignment: .top) {
          ScrollView {
            VStackLayout(spacing: 0) {
              EditorView(
                viewModel: mainSEVM,
                followUpSEVMs: $followUpSEVMs,
                editingMediaContainer: $editingMediaContainer,
                presentationDetent: $presentationDetent,
                editorFocusState: $editorFocusState,
                assignedFocusState: .main,
                isMain: true
              )
              .id(mainSEVM.id)

              ForEach(followUpSEVMs) { sevm in
                @Bindable var sevm: ViewModel = sevm

                EditorView(
                  viewModel: sevm,
                  followUpSEVMs: $followUpSEVMs,
                  editingMediaContainer: $editingMediaContainer,
                  presentationDetent: $presentationDetent,
                  editorFocusState: $editorFocusState,
                  assignedFocusState: .followUp(index: sevm.id),
                  isMain: false
                )
                .id(sevm.id)
              }
            }
            .scrollTargetLayout()
          }
          .scrollPosition(id: $scrollID, anchor: .top)
          .animation(.bouncy(duration: 0.3), value: editorFocusState)
          .animation(.bouncy(duration: 0.3), value: followUpSEVMs)
          #if !os(visionOS)
            .background(backgroundColor)
          #endif
          #if os(visionOS)
            .ornament(attachmentAnchor: .scene(.leading)) {
              AccessoryView(
                focusedSEVM: focusedSEVM,
                followUpSEVMs: $followUpSEVMs)
            }
          #else
            .safeAreaInset(edge: .bottom) {
              if presentationDetent == .large || presentationDetent == .medium {
                if #available(iOS 26.0, *) {
                  GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                      AutoCompleteView(viewModel: focusedSEVM)

                      AccessoryView(
                        focusedSEVM: focusedSEVM,
                        followUpSEVMs: $followUpSEVMs)
                    }
                  }
                  .padding(.bottom, 8)
                } else {
                  AccessoryView(
                    focusedSEVM: focusedSEVM,
                    followUpSEVMs: $followUpSEVMs)

                  AutoCompleteView(viewModel: focusedSEVM)
                }
              }
            }
          #endif
          .accessibilitySortPriority(1)  // Ensure that all elements inside the `ScrollView` occur earlier than the accessory views
          .navigationTitle(focusedSEVM.mode.title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItems(
              mainSEVM: mainSEVM,
              focusedSEVM: focusedSEVM,
              followUpSEVMs: followUpSEVMs)
          }
          .alert(
            "status.error.posting.title",
            isPresented: $focusedSEVM.showPostingErrorAlert,
            actions: {
              Button("OK") {}
            },
            message: {
              Text(mainSEVM.postingError ?? "")
            }
          )
          .interactiveDismissDisabled(mainSEVM.shouldDisplayDismissWarning)
          .onChange(of: appAccounts.currentClient) { _, newValue in
            if mainSEVM.mode.isInShareExtension {
              currentAccount.setClient(client: newValue)
              mainSEVM.client = newValue
              for post in followUpSEVMs {
                post.client = newValue
              }
            }
          }
          .onDrop(
            of: [.image, .video, .gif, .mpeg4Movie, .quickTimeMovie, .movie],
            delegate: focusedSEVM
          )
          .onChange(of: currentAccount.account?.id) {
            mainSEVM.currentAccount = currentAccount.account
            for p in followUpSEVMs {
              p.currentAccount = mainSEVM.currentAccount
            }
          }
          .onChange(of: mainSEVM.visibility) {
            for p in followUpSEVMs {
              p.visibility = mainSEVM.visibility
            }
          }
          .onChange(of: followUpSEVMs.count) { oldValue, newValue in
            if oldValue < newValue {
              Task {
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.bouncy(duration: 0.5)) {
                  scrollID = followUpSEVMs.last?.id
                }
              }
            }
          }
          if mainSEVM.isPosting {
            ProgressView(value: mainSEVM.postingProgress, total: 100.0)
          }
        }
      }
      .sheet(item: $editingMediaContainer) { container in
        StatusEditor.MediaEditView(viewModel: focusedSEVM, container: container)
      }
      .presentationDetents([.large, .height(230)], selection: $presentationDetent)
      .presentationBackgroundInteraction(.enabled)
    }
  }
}
