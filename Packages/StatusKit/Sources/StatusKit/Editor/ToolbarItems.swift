/*
 * ToolbarItems.swift
 * IceCubesApp - 编辑器工具栏项
 *
 * 功能描述：
 * 定义状态编辑器的工具栏按钮和操作
 * 包括发送、关闭、草稿管理等核心功能
 *
 * 核心功能：
 * 1. 发送按钮 - 发布帖子或帖子串
 * 2. 关闭按钮 - 关闭编辑器，可选保存草稿
 * 3. 草稿按钮 - 打开草稿列表
 * 4. 语言确认 - 自动检测语言并确认
 * 5. iOS 26 适配 - 使用 Liquid Glass 按钮样式
 * 6. 键盘快捷键 - Cmd+Return 发送，Esc 关闭
 * 7. 评分请求 - 发送后请求 App Store 评分
 * 8. 音效反馈 - 发送成功播放音效
 * 9. 多帖子发送 - 支持帖子串的顺序发送
 * 10. 状态验证 - 检查是否可以发送
 *
 * 技术点：
 * 1. ToolbarContent - SwiftUI 工具栏协议
 * 2. @MainActor - 确保 UI 操作在主线程
 * 3. @State - 本地状态管理
 * 4. @Environment - 环境依赖注入
 * 5. 条件编译 - macCatalyst 和 iOS 的不同处理
 * 6. async/await - 异步发送操作
 * 7. confirmationDialog - 确认对话框
 * 8. sheet - 模态视图
 * 9. keyboardShortcut - 键盘快捷键
 * 10. StoreKit - App Store 评分请求
 *
 * 工具栏布局：
 * - 左侧：关闭按钮（红色 X）
 * - 右侧：草稿按钮、发送按钮
 * - iOS 26+：使用 ToolbarSpacer 和 glassProminent 样式
 *
 * 发送流程：
 * 1. 验证是否可以发送
 * 2. 检测帖子语言
 * 3. 如果启用自动检测，显示语言确认对话框
 * 4. 发送主帖子
 * 5. 依次发送后续帖子（帖子串）
 * 6. 播放音效，关闭编辑器
 * 7. 请求 App Store 评分（首次）
 *
 * 关闭流程：
 * 1. 检查是否有未保存的内容
 * 2. 如果有，显示确认对话框
 * 3. 用户可选择：删除、保存为草稿、取消
 * 4. 执行相应操作并关闭编辑器
 *
 * 草稿管理：
 * - 点击草稿按钮打开草稿列表
 * - 选择草稿后插入到当前编辑器
 * - 支持保存当前内容为草稿
 *
 * 语言确认：
 * - 自动检测帖子语言
 * - 如果检测结果与选择不同，显示确认对话框
 * - 用户可选择使用检测的语言或保持选择的语言
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 用户偏好设置
 * - Models: 数据模型
 * - StoreKit: App Store 评分
 */

import DesignSystem
import Env
import Models
import StoreKit
import SwiftUI

extension StatusEditor {
  /// 编辑器工具栏项
  ///
  /// 提供编辑器顶部工具栏的所有按钮和操作。
  ///
  /// 主要功能：
  /// - **发送按钮**：发布帖子或帖子串
  /// - **关闭按钮**：关闭编辑器，可选保存草稿
  /// - **草稿按钮**：打开草稿列表
  /// - **语言确认**：自动检测语言并确认
  ///
  /// 使用示例：
  /// ```swift
  /// .toolbar {
  ///     ToolbarItems(
  ///         mainSEVM: mainViewModel,
  ///         focusedSEVM: focusedViewModel,
  ///         followUpSEVMs: followUpViewModels
  ///     )
  /// }
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: 支持键盘快捷键：Cmd+Return 发送，Esc 关闭
  @MainActor
  struct ToolbarItems: ToolbarContent {
    /// 是否显示语言确认对话框
    @State private var isLanguageConfirmPresented = false
    /// 是否显示关闭确认对话框
    @State private var isDismissAlertPresented: Bool = false
    /// 是否显示草稿列表
    @State private var isDraftsSheetDisplayed: Bool = false

    /// 主 ViewModel（第一条帖子）
    let mainSEVM: ViewModel
    /// 当前聚焦的 ViewModel
    let focusedSEVM: ViewModel
    /// 后续 ViewModel 列表（帖子串）
    let followUpSEVMs: [ViewModel]

    /// SwiftData 上下文，用于保存草稿
    @Environment(\.modelContext) private var context
    /// 用户偏好设置
    @Environment(UserPreferences.self) private var preferences
    /// 主题设置
    @Environment(Theme.self) private var theme

    #if targetEnvironment(macCatalyst)
      @Environment(\.dismissWindow) private var dismissWindow
    #else
      @Environment(\.dismiss) private var dismiss
    #endif

    /// 是否禁用发送按钮
    ///
    /// 当帖子无法发送或正在发送时返回 true。
    var isSendingDisabled: Bool {
      !mainSEVM.canPost || mainSEVM.isPosting
    }

    var body: some ToolbarContent {
      // 草稿按钮 - 右上角
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          isDraftsSheetDisplayed = true
        } label: {
          Image(systemName: "pencil.and.list.clipboard")
        }
        .tint(.label)
        .accessibilityLabel("accessibility.editor.button.drafts")
        .sheet(isPresented: $isDraftsSheetDisplayed) {
          if UIDevice.current.userInterfaceIdiom == .phone {
            draftsListView
          } else {
            draftsListView
          }
        }
      }

      // iOS 26+ 使用 Liquid Glass 样式
      if #available(iOS 26, *) {
        ToolbarSpacer(placement: .topBarTrailing)
        ToolbarItem(placement: .navigationBarTrailing) {
          sendButton
            .buttonStyle(.glassProminent)
            .tint(theme.tintColor)
        }
      } else {
        // 旧版本使用标准突出样式
        ToolbarItem(placement: .navigationBarTrailing) {
          sendButton
            .buttonStyle(.borderedProminent)
            .tint(theme.tintColor)
        }
      }

      // 关闭按钮 - 左上角
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          // 检查是否需要显示关闭警告
          if mainSEVM.shouldDisplayDismissWarning {
            isDismissAlertPresented = true
          } else {
            close()
            NotificationCenter.default.post(
              name: .shareSheetClose,
              object: nil)
          }
        } label: {
          Image(systemName: "xmark")
        }
        .tint(.red)
        .keyboardShortcut(.cancelAction)
        .confirmationDialog(
          "",
          isPresented: $isDismissAlertPresented,
          actions: {
            // 删除草稿并关闭
            Button("status.draft.delete", role: .destructive) {
              close()
              NotificationCenter.default.post(
                name: .shareSheetClose,
                object: nil)
            }
            // 保存为草稿并关闭
            Button("status.draft.save") {
              context.insert(Draft(content: mainSEVM.statusText.string))
              close()
              NotificationCenter.default.post(
                name: .shareSheetClose,
                object: nil)
            }
            // 取消关闭操作
            Button("action.cancel", role: .cancel) {}
          }
        )
      }
    }

    /// 发送按钮视图
    ///
    /// 显示纸飞机图标，点击后发送帖子。
    /// 支持键盘快捷键 Cmd+Return。
    private var sendButton: some View {
      Button {
        Task {
          // 检查是否可以发送
          guard !isSendingDisabled else { return }
          // 评估帖子语言
          mainSEVM.evaluateLanguages()
          // 如果启用自动检测且检测到语言差异，显示确认对话框
          if preferences.autoDetectPostLanguage,
            mainSEVM.languageConfirmationDialogLanguages != nil
          {
            isLanguageConfirmPresented = true
          } else {
            // 直接发送所有帖子
            await postAllStatus()
          }
        }
      } label: {
        Image(systemName: "paperplane")
          .symbolVariant(isSendingDisabled ? .none : .fill)
          .foregroundStyle(.white)
          .bold()
      }
      .buttonBorderShape(.circle)
      .keyboardShortcut(.return, modifiers: .command)
      .confirmationDialog(
        "", isPresented: $isLanguageConfirmPresented,
        actions: {
          languageConfirmationDialog
        })
    }

    /// 发送单条帖子
    ///
    /// 调用 ViewModel 的 postStatus 方法发送帖子。
    /// 如果是主帖子且发送成功，播放音效并关闭编辑器。
    ///
    /// - Parameters:
    ///   - model: 要发送的 ViewModel
    ///   - isMainPost: 是否是主帖子（第一条）
    /// - Returns: 发送成功的 Status 对象，失败返回 nil
    @discardableResult
    private func postStatus(with model: ViewModel, isMainPost: Bool) async -> Status? {
      let status = await model.postStatus()
      if status != nil, isMainPost {
        close()
        SoundEffectManager.shared.playSound(.tootSent)
        NotificationCenter.default.post(name: .shareSheetClose, object: nil)
        #if !targetEnvironment(macCatalyst)
          // 首次发送成功后请求 App Store 评分
          if !mainSEVM.mode.isInShareExtension, !preferences.requestedReview {
            if let scene = UIApplication.shared.connectedScenes.first(where: {
              $0.activationState == .foregroundActive
            }) as? UIWindowScene {
              AppStore.requestReview(in: scene)
            }
            preferences.requestedReview = true
          }
        #endif
      }

      return status
    }

    /// 发送所有帖子（主帖子 + 后续帖子串）
    ///
    /// 先发送主帖子，然后依次发送后续帖子。
    /// 每条后续帖子都作为前一条的回复。
    private func postAllStatus() async {
      // 发送主帖子
      guard var latestPost = await postStatus(with: mainSEVM, isMainPost: true) else { return }
      // 依次发送后续帖子
      for p in followUpSEVMs {
        p.mode = .replyTo(status: latestPost)
        guard let post = await postStatus(with: p, isMainPost: false) else {
          break
        }
        latestPost = post
      }
    }

    #if targetEnvironment(macCatalyst)
      /// 关闭编辑器（macCatalyst）
      private func close() { dismissWindow() }
    #else
      /// 关闭编辑器（iOS）
      private func close() { dismiss() }
    #endif

    /// 语言确认对话框
    ///
    /// 当自动检测的语言与用户选择的语言不同时显示。
    /// 用户可以选择使用检测的语言或保持选择的语言。
    @ViewBuilder
    private var languageConfirmationDialog: some View {
      if let (detected: detected, selected: selected) = mainSEVM
        .languageConfirmationDialogLanguages,
        let detectedLong = Locale.current.localizedString(forLanguageCode: detected),
        let selectedLong = Locale.current.localizedString(forLanguageCode: selected)
      {
        // 使用检测到的语言
        Button("status.editor.language-select.confirmation.detected-\(detectedLong)") {
          mainSEVM.selectedLanguage = detected
          Task { await postAllStatus() }
        }
        // 使用选择的语言
        Button("status.editor.language-select.confirmation.selected-\(selectedLong)") {
          mainSEVM.selectedLanguage = selected
          Task { await postAllStatus() }
        }
        // 取消发送
        Button("action.cancel", role: .cancel) {
          mainSEVM.languageConfirmationDialogLanguages = nil
        }
      } else {
        EmptyView()
      }
    }

    /// 草稿列表视图
    ///
    /// 显示所有保存的草稿，选择后插入到当前编辑器。
    private var draftsListView: some View {
      DraftsListView(
        selectedDraft: .init(
          get: {
            nil
          },
          set: { draft in
            if let draft {
              // 将选中的草稿插入到当前聚焦的编辑器
              focusedSEVM.insertStatusText(text: draft.content)
            }
          }))
    }
  }
}
