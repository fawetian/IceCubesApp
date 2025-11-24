/*
 * AccessoryView.swift
 * IceCubesApp - 编辑器附件视图
 *
 * 功能描述：
 * 编辑器底部的附件工具栏，提供各种快捷操作
 * 支持添加媒体、表情、提及、标签等功能
 *
 * 核心功能：
 * 1. 媒体添加 - 照片库、相机、文件浏览器
 * 2. 后续帖子 - 添加帖子串的后续帖子
 * 3. 自定义表情 - 打开表情选择器
 * 4. AI 助手 - AI 辅助写作（iOS 26+）
 * 5. 快捷插入 - @ 提及和 # 标签
 * 6. 动态布局 - 根据空间自适应布局
 * 7. iOS 26 适配 - 使用 Liquid Glass 效果
 * 8. visionOS 适配 - 垂直布局
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @Environment - 环境依赖注入
 * 3. @State - 本地状态管理
 * 4. @Binding - 双向数据绑定
 * 5. @Bindable - 绑定 ViewModel
 * 6. ViewThatFits - 自适应布局
 * 7. PhotosPicker - 照片选择器
 * 8. fileImporter - 文件导入器
 * 9. fullScreenCover - 全屏相机
 * 10. 条件编译 - iOS 26+、visionOS、macCatalyst
 *
 * 视图层次：
 * - HStack/VStack（根据平台）
 *   - actionsView（操作按钮）
 *     - Menu（媒体菜单）
 *     - Button（后续帖子）
 *     - Button（自定义表情）
 *     - Menu（AI 助手）
 *     - Button（@ 提及）
 *     - Button（# 标签）
 *
 * 媒体添加选项：
 * - 照片库：从相册选择照片/视频
 * - 相机：拍摄新照片（非 macCatalyst）
 * - 文件浏览器：从文件系统选择
 *
 * AI 助手功能（iOS 26+）：
 * - 改写语气：专业、友好、简洁等
 * - 修正语法
 * - 翻译
 * - 总结
 * - 恢复之前的文本
 *
 * 后续帖子限制：
 * - 最多 5 条后续帖子
 * - 当前帖子必须有内容
 * - 最后一条后续帖子必须有内容
 *
 * 使用场景：
 * - 添加媒体附件
 * - 创建帖子串
 * - 插入自定义表情
 * - 使用 AI 辅助写作
 * - 快速插入 @ 和 #
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 环境对象
 * - Models: 数据模型
 * - PhotosUI: 照片选择器
 */

import DesignSystem
import Env
import Models
import NukeUI
import PhotosUI
import SwiftUI

extension StatusEditor {
  /// 编辑器附件视图
  ///
  /// 编辑器底部的附件工具栏。
  ///
  /// 主要功能：
  /// - **媒体添加**：照片库、相机、文件浏览器
  /// - **后续帖子**：添加帖子串的后续帖子
  /// - **自定义表情**：打开表情选择器
  /// - **AI 助手**：AI 辅助写作（iOS 26+）
  /// - **快捷插入**：@ 提及和 # 标签
  ///
  /// 使用示例：
  /// ```swift
  /// AccessoryView(
  ///     focusedSEVM: focusedViewModel,
  ///     followUpSEVMs: $followUpViewModels
  /// )
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: 根据平台和 iOS 版本使用不同的布局和样式
  @MainActor
  struct AccessoryView: View {
    /// 用户偏好设置
    @Environment(UserPreferences.self) private var preferences
    /// 主题设置
    @Environment(Theme.self) private var theme
    /// 当前实例信息
    @Environment(CurrentInstance.self) private var currentInstance
    /// 颜色方案
    @Environment(\.colorScheme) private var colorScheme

    /// 当前聚焦的 ViewModel
    let focusedSEVM: ViewModel
    /// 后续 ViewModel 列表
    @Binding var followUpSEVMs: [ViewModel]

    /// 是否显示自定义表情面板
    @State private var isCustomEmojisSheetDisplay: Bool = false
    /// 是否正在加载 AI 请求
    @State private var isLoadingAIRequest: Bool = false
    /// 是否显示照片选择器
    @State private var isPhotosPickerPresented: Bool = false
    /// 是否显示文件导入器
    @State private var isFileImporterPresented: Bool = false
    /// 是否显示相机选择器
    @State private var isCameraPickerPresented: Bool = false

    var body: some View {
      @Bindable var viewModel = focusedSEVM
      #if os(visionOS)
        HStack {
          contentView
            .buttonStyle(.borderless)
        }
        .frame(width: 32)
        .padding(16)
        .glassBackgroundEffect()
        .cornerRadius(8)
        .padding(.trailing, 78)
      #else
        if #available(iOS 26, *) {
          contentView
            .padding(.vertical, 16)
            .glassEffect(.regular)
            .background(theme.primaryBackgroundColor.opacity(0.2))
            .padding(.horizontal, 16)
        } else {
          Divider()
          HStack {
            contentView
          }
          .frame(height: 20)
          .padding(.vertical, 12)
          .background(.ultraThickMaterial)
        }
      #endif
    }

    /// 内容视图
    ///
    /// 根据平台使用不同的布局。
    @ViewBuilder
    private var contentView: some View {
      #if os(visionOS)
        VStack(spacing: 8) {
          actionsView
        }
      #else
        ViewThatFits {
          HStack(alignment: .center, spacing: 16) {
            actionsView
          }
          .padding(.horizontal, .layoutPadding)

          ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: 16) {
              actionsView
            }
            .padding(.horizontal, .layoutPadding)
          }
          .scrollIndicators(.hidden)
        }
      #endif
    }

    /// 操作按钮视图
    ///
    /// 包含所有的操作按钮。
    @ViewBuilder
    private var actionsView: some View {
      @Bindable var viewModel = focusedSEVM
      Menu {
        Button {
          isPhotosPickerPresented = true
        } label: {
          Label("status.editor.photo-library", systemImage: "photo")
            .frame(width: 25, height: 25)
            .contentShape(Rectangle())
        }
        #if !targetEnvironment(macCatalyst)
          Button {
            isCameraPickerPresented = true
          } label: {
            Label("status.editor.camera-picker", systemImage: "camera")
          }
        #endif
        Button {
          isFileImporterPresented = true
        } label: {
          Label("status.editor.browse-file", systemImage: "folder")
        }
      } label: {
        if viewModel.isMediasLoading {
          ProgressView()
        } else {
          Image(systemName: "photo.on.rectangle.angled")
            .frame(width: 25, height: 25)
            .contentShape(Rectangle())
            .foregroundStyle(theme.tintColor)
        }
      }
      .buttonStyle(.plain)
      .photosPicker(
        isPresented: $isPhotosPickerPresented,
        selection: $viewModel.mediaPickers,
        maxSelectionCount: currentInstance.instance?.configuration?.statuses.maxMediaAttachments
          ?? 4,
        matching: .any(of: [.images, .videos]),
        photoLibrary: .shared()
      )
      .fileImporter(
        isPresented: $isFileImporterPresented,
        allowedContentTypes: [.image, .video, .movie],
        allowsMultipleSelection: true
      ) { result in
        if let urls = try? result.get() {
          viewModel.processURLs(urls: urls)
        }
      }
      .fullScreenCover(
        isPresented: $isCameraPickerPresented,
        content: {
          CameraPickerView(
            selectedImage: .init(
              get: {
                nil
              },
              set: { image in
                if let image {
                  viewModel.processCameraPhoto(image: image)
                }
              })
          )
          .background(.black)
        }
      )
      .accessibilityLabel("accessibility.editor.button.attach-photo")
      .disabled(viewModel.showPoll)

      Button {
        // all SEVM have the same visibility value
        followUpSEVMs.append(ViewModel(mode: .new(text: nil, visibility: focusedSEVM.visibility)))
      } label: {
        Image(systemName: "arrowshape.turn.up.left.circle.fill")
          .frame(width: 25, height: 25)
          .contentShape(Rectangle())
      }
      .disabled(!canAddNewSEVM)

      if !viewModel.customEmojiContainer.isEmpty {
        Button {
          isCustomEmojisSheetDisplay = true
        } label: {
          // This is a workaround for an apparent bug in the `face.smiling` SF Symbol.
          // See https://github.com/Dimillian/IceCubesApp/issues/1193
          let customEmojiSheetIconName =
            colorScheme == .light ? "face.smiling" : "face.smiling.inverse"
          Image(systemName: customEmojiSheetIconName)
            .frame(width: 25, height: 25)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("accessibility.editor.button.custom-emojis")
        .sheet(isPresented: $isCustomEmojisSheetDisplay) {
          CustomEmojisView(viewModel: focusedSEVM)
            .environment(theme)
        }
      }

      if #available(iOS 26, *), Assistant.isAvailable {
        AssistantMenu.disabled(!viewModel.canPost)
      }

      Spacer()

      Button {
        viewModel.insertStatusText(text: "@")
      } label: {
        Image(systemName: "at")
          .frame(width: 25, height: 25)
          .contentShape(Rectangle())
      }

      Button {
        viewModel.insertStatusText(text: "#")
      } label: {
        Image(systemName: "number")
          .frame(width: 25, height: 25)
          .contentShape(Rectangle())
      }
    }

    /// 是否可以添加新的后续帖子
    ///
    /// 检查是否满足添加后续帖子的条件。
    private var canAddNewSEVM: Bool {
      guard followUpSEVMs.count < 5 else { return false }

      if followUpSEVMs.isEmpty,  // there is only mainSEVM on the editor
        !focusedSEVM.statusText.string.isEmpty  // focusedSEVM is also mainSEVM
      {
        return true
      }

      if let lastSEVMs = followUpSEVMs.last,
        !lastSEVMs.statusText.string.isEmpty
      {
        return true
      }

      return false
    }

    /// AI 助手菜单（iOS 26+）
    ///
    /// 提供 AI 辅助写作功能。
    @available(iOS 26, *)
    private var AssistantMenu: some View {
      Menu {
        ForEach(AIPrompt.allCases, id: \.self) { prompt in
          if case AIPrompt.rewriteWithTone = prompt {
            Menu {
              ForEach(Assistant.Tone.allCases, id: \.self) { tone in
                Button {
                  isLoadingAIRequest = true
                  Task {
                    await focusedSEVM.runAssistant(prompt: prompt)
                    isLoadingAIRequest = false
                  }
                } label: {
                  tone.label
                }
              }
            } label: {
              prompt.label
            }
          } else {
            Button {
              isLoadingAIRequest = true
              Task {
                await focusedSEVM.runAssistant(prompt: prompt)
                isLoadingAIRequest = false
              }
            } label: {
              prompt.label
            }
          }
        }
        if let backup = focusedSEVM.backupStatusText {
          Button {
            focusedSEVM.replaceTextWith(text: backup.string)
            focusedSEVM.backupStatusText = nil
          } label: {
            Label("status.editor.restore-previous", systemImage: "arrow.uturn.right")
          }
        }
      } label: {
        if isLoadingAIRequest {
          ProgressView()
        } else {
          Image(systemName: "faxmachine")
            .accessibilityLabel("accessibility.editor.button.ai-prompt")
            .foregroundStyle(focusedSEVM.canPost ? theme.tintColor : .secondary)
            .frame(width: 25, height: 25)
            .contentShape(Rectangle())
        }
      }
      .buttonStyle(.plain)
    }
  }
}
