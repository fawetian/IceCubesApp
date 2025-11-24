/*
 * MediaEditView.swift
 * IceCubesApp - 媒体编辑视图
 *
 * 功能描述：
 * 编辑媒体附件的替代文本（Alt Text）
 * 支持手动输入、AI 生成和翻译功能
 *
 * 核心功能：
 * 1. Alt 文本编辑 - 添加或编辑媒体的替代文本
 * 2. AI 生成 - 使用 OpenAI 自动生成图片描述
 * 3. 翻译功能 - 翻译 Alt 文本到其他语言（iOS 17.4+）
 * 4. 媒体预览 - 显示正在编辑的媒体
 * 5. 自动聚焦 - 打开时自动聚焦到输入框
 * 6. 保存状态 - 显示保存进度
 * 7. 实例支持检查 - 检查实例是否支持编辑 Alt 文本
 * 8. 导航栏 - 完成和取消按钮
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @Environment - 环境依赖注入
 * 3. @State - 本地状态管理
 * 4. @FocusState - 输入框焦点管理
 * 5. NavigationStack - 导航容器
 * 6. Form - 表单布局
 * 7. AsyncImage - 异步加载图片
 * 8. TextField - 多行文本输入
 * 9. 条件编译 - iOS 17.4+ 翻译功能
 * 10. async/await - 异步操作
 *
 * 视图层次：
 * - NavigationStack
 *   - Form
 *     - Section（输入区域）
 *       - TextField（Alt 文本输入）
 *       - generateButton（AI 生成按钮）
 *       - translateButton（翻译按钮）
 *     - Section（预览区域）
 *       - AsyncImage（媒体预览）
 *
 * AI 生成流程：
 * 1. 点击生成按钮
 * 2. 调用 OpenAI API
 * 3. 传入媒体 URL
 * 4. 获取生成的描述
 * 5. 填充到输入框
 *
 * 保存流程：
 * 1. 点击完成按钮
 * 2. 检查实例是否支持编辑
 * 3. 调用相应的 API（编辑或添加）
 * 4. 更新 ViewModel
 * 5. 关闭视图
 *
 * 使用场景：
 * - 为新上传的媒体添加 Alt 文本
 * - 编辑已有的 Alt 文本
 * - 使用 AI 生成图片描述
 * - 翻译 Alt 文本
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 环境对象
 * - Models: 数据模型
 * - NetworkClient: OpenAI 客户端
 */

import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

extension StatusEditor {
  /// 媒体编辑视图
  ///
  /// 编辑媒体附件的替代文本。
  ///
  /// 主要功能：
  /// - **Alt 文本编辑**：添加或编辑媒体的替代文本
  /// - **AI 生成**：使用 OpenAI 自动生成图片描述
  /// - **翻译功能**：翻译 Alt 文本到其他语言
  /// - **媒体预览**：显示正在编辑的媒体
  ///
  /// 使用示例：
  /// ```swift
  /// MediaEditView(
  ///     viewModel: viewModel,
  ///     container: mediaContainer
  /// )
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: AI 生成功能需要配置 OpenAI API
  @MainActor
  struct MediaEditView: View {
    /// 关闭视图的环境变量
    @Environment(\.dismiss) private var dismiss
    /// 主题设置
    @Environment(Theme.self) private var theme
    /// 当前实例信息
    @Environment(CurrentInstance.self) private var currentInstance
    /// 用户偏好设置
    @Environment(UserPreferences.self) private var preferences

    /// 编辑器 ViewModel
    var viewModel: ViewModel
    /// 要编辑的媒体容器
    let container: StatusEditor.MediaContainer

    /// 图片描述文本
    @State private var imageDescription: String = ""
    /// 输入框是否聚焦
    @FocusState private var isFieldFocused: Bool

    /// 是否正在更新
    @State private var isUpdating: Bool = false

    /// 是否已经出现过（用于初始化）
    @State private var didAppear: Bool = false
    /// 是否正在生成描述
    @State private var isGeneratingDescription: Bool = false

    /// 是否显示翻译视图
    @State private var showTranslateView: Bool = false
    /// 是否正在翻译
    @State private var isTranslating: Bool = false

    var body: some View {
      NavigationStack {
        Form {
          Section {
            TextField(
              "status.editor.media.image-description",
              text: $imageDescription,
              axis: .vertical
            )
            .focused($isFieldFocused)
            if imageDescription.isEmpty {
              generateButton
            }
            #if canImport(_Translation_SwiftUI)
              if #available(iOS 17.4, *), !imageDescription.isEmpty {
                translateButton
              }
            #endif
          }
          .listRowBackground(theme.primaryBackgroundColor)
          Section {
            if let url = container.mediaAttachment?.url {
              AsyncImage(
                url: url,
                content: { image in
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .cornerRadius(8)
                    .padding(8)
                },
                placeholder: {
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray)
                    .frame(height: 200)
                }
              )
            }
          }
          .listRowBackground(theme.primaryBackgroundColor)
        }
        .scrollContentBackground(.hidden)
        .background(theme.secondaryBackgroundColor)
        .onAppear {
          if !didAppear {
            imageDescription = container.mediaAttachment?.description ?? ""
            isFieldFocused = true
            didAppear = true
          }
        }
        .navigationTitle("status.editor.media.edit-image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              if !imageDescription.isEmpty {
                isUpdating = true
                if currentInstance.isEditAltTextSupported, viewModel.mode.isEditing {
                  Task {
                    await viewModel.editDescription(
                      container: container, description: imageDescription)
                    dismiss()
                    isUpdating = false
                  }
                } else {
                  Task {
                    await viewModel.addDescription(
                      container: container, description: imageDescription)
                    dismiss()
                    isUpdating = false
                  }
                }
              }
            } label: {
              if isUpdating {
                ProgressView()
              } else {
                Text("action.done")
              }
            }
          }

          CancelToolbarItem()
        }
        .preferredColorScheme(theme.selectedScheme == .dark ? .dark : .light)
      }
    }

    /// AI 生成按钮
    ///
    /// 使用 OpenAI 生成图片描述。
    @ViewBuilder
    private var generateButton: some View {
      if let url = container.mediaAttachment?.url {
        Button {
          Task {
            if let description = await generateDescription(url: url) {
              imageDescription = description
            }
          }
        } label: {
          if isGeneratingDescription {
            ProgressView()
          } else {
            Text("status.editor.media.generate-description")
          }
        }
      }
    }

    /// 翻译按钮
    ///
    /// 翻译 Alt 文本到其他语言（iOS 17.4+）。
    @ViewBuilder
    private var translateButton: some View {
      Button {
        showTranslateView = true
      } label: {
        if isTranslating {
          ProgressView()
        } else {
          Text("status.action.translate")
        }
      }
      #if canImport(_Translation_SwiftUI)
        .addTranslateView(isPresented: $showTranslateView, text: imageDescription)
      #endif
    }

    /// 生成图片描述
    ///
    /// 调用 OpenAI API 生成图片的描述文本。
    ///
    /// - Parameter url: 图片 URL
    /// - Returns: 生成的描述文本，失败返回 nil
    private func generateDescription(url: URL) async -> String? {
      isGeneratingDescription = true
      let client = OpenAIClient()
      let response = try? await client.request(.imageDescription(image: url))
      isGeneratingDescription = false
      return response?.trimmedText
    }
  }
}
