/*
 * MediaView.swift
 * IceCubesApp - 媒体视图组件
 *
 * 功能描述：
 * 在编辑器中显示和管理媒体附件（图片、视频、GIF）
 * 支持媒体预览、上传进度、错误处理和编辑操作
 *
 * 核心功能：
 * 1. 媒体显示 - 横向滚动显示所有媒体附件
 * 2. 状态展示 - 根据媒体状态显示不同的视图
 * 3. 上传进度 - 显示媒体上传的实时进度
 * 4. 错误处理 - 显示上传失败的错误信息
 * 5. Alt 文本 - 添加和编辑媒体的替代文本
 * 6. 删除操作 - 移除不需要的媒体附件
 * 7. 重试上传 - 失败后可以重新上传
 * 8. 自动滚动 - 添加新媒体时自动滚动到最后
 * 9. iOS 26 适配 - 使用 Liquid Glass 按钮样式
 * 10. 上下文菜单 - 长按显示操作菜单
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @Environment - 环境依赖注入
 * 3. @Binding - 双向数据绑定
 * 4. @State - 本地状态管理
 * 5. @Namespace - 动画命名空间
 * 6. ScrollView - 横向滚动容器
 * 7. LazyImage - 延迟加载图片（Nuke）
 * 8. AVKit - 视频播放
 * 9. 条件编译 - macCatalyst 和 iOS 的不同处理
 * 10. 动画 - spring 和 bouncy 动画
 *
 * 视图层次：
 * - ScrollView（横向滚动）
 *   - HStack（媒体布局）
 *     - ForEach（遍历媒体容器）
 *       - RoundedRectangle（媒体项容器）
 *         - 媒体内容（根据状态显示）
 *         - Alt 文本标记（右下角）
 *         - 删除按钮（右上角）
 *
 * 媒体状态视图：
 * - pending: 本地媒体视图（模糊预览 + 进度指示器）
 * - uploading: 上传中视图（模糊预览 + 进度条）
 * - uploaded: 远程媒体视图（完整图片/视频）
 * - failed: 错误视图（模糊预览 + 错误图标）
 *
 * 上下文菜单操作：
 * - uploaded: 添加/编辑 Alt 文本
 * - failed: 查看错误详情
 * - pending: 重试上传
 * - 所有状态: 删除媒体
 *
 * 使用场景：
 * - 编辑器中显示已添加的媒体
 * - 显示媒体上传进度
 * - 编辑媒体的 Alt 文本
 * - 删除不需要的媒体
 * - 处理上传失败的情况
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 环境对象
 * - MediaUI: 视频播放组件
 * - Models: 数据模型
 * - NukeUI: 图片加载库
 */

import AVKit
import DesignSystem
import Env
import MediaUI
import Models
import NukeUI
import SwiftUI

extension StatusEditor {
  /// 媒体视图
  ///
  /// 在编辑器中显示和管理媒体附件。
  ///
  /// 主要功能：
  /// - **媒体显示**：横向滚动显示所有媒体附件
  /// - **状态展示**：根据媒体状态显示不同的视图
  /// - **上传进度**：显示媒体上传的实时进度
  /// - **Alt 文本**：添加和编辑媒体的替代文本
  /// - **删除操作**：移除不需要的媒体附件
  ///
  /// 使用示例：
  /// ```swift
  /// MediaView(
  ///     viewModel: viewModel,
  ///     editingMediaContainer: $editingMediaContainer
  /// )
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: 支持图片、视频、GIF 三种媒体类型
  @MainActor
  struct MediaView: View {
    /// 主题设置
    @Environment(Theme.self) private var theme
    /// 当前实例信息
    @Environment(CurrentInstance.self) private var currentInstance
    /// 编辑器 ViewModel
    var viewModel: ViewModel
    /// 正在编辑的媒体容器（用于 Alt 文本编辑）
    @Binding var editingMediaContainer: MediaContainer?

    /// 是否显示错误提示
    @State private var isErrorDisplayed: Bool = false

    /// 动画命名空间
    @Namespace var mediaSpace
    /// 滚动位置 ID
    @State private var scrollID: String?

    var body: some View {
      ScrollView(.horizontal, showsIndicators: showsScrollIndicators) {
        mediaLayout
      }
      .scrollPosition(id: $scrollID, anchor: .trailing)
      .scrollClipDisabled()
      .padding(.horizontal, .layoutPadding)
      .frame(height: viewModel.mediaContainers.count > 0 ? containerHeight : 0)
      .animation(.spring(duration: 0.3), value: viewModel.mediaContainers.count)
      .onChange(of: viewModel.mediaPickers.count) { oldValue, newValue in
        if oldValue < newValue {
          Task {
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.bouncy(duration: 0.5)) {
              scrollID = containers.last?.id
            }
          }
        }
      }
    }

    /// 媒体容器列表
    private var containers: [MediaContainer] { viewModel.mediaContainers }
    /// 容器高度
    private let containerHeight: CGFloat = 300
    /// 容器宽度（高度的 2/3）
    private var containerWidth: CGFloat { containerHeight / 1.5 }

    #if targetEnvironment(macCatalyst)
      /// 滚动底部内边距（macCatalyst）
      private var scrollBottomPadding: CGFloat?
    #else
      /// 滚动底部内边距（iOS）
      private var scrollBottomPadding: CGFloat? = 0
    #endif

    /// 是否显示滚动指示器
    private var showsScrollIndicators: Bool = false

    /// 初始化方法
    ///
    /// - Parameters:
    ///   - viewModel: 编辑器 ViewModel
    ///   - editingMediaContainer: 正在编辑的媒体容器绑定
    init(viewModel: ViewModel, editingMediaContainer: Binding<StatusEditor.MediaContainer?>) {
      self.viewModel = viewModel
      _editingMediaContainer = editingMediaContainer
    }

    /// 媒体布局视图
    ///
    /// 横向排列所有媒体容器。
    private var mediaLayout: some View {
      HStack(alignment: .center, spacing: 8) {
        ForEach(Array(viewModel.mediaContainers.enumerated()), id: \.offset) { index, container in
          makeMediaItem(container)
            .containerRelativeFrame(
              .horizontal,
              count: viewModel.mediaContainers.count == 1 ? 1 : 2,
              span: 1,
              spacing: 0,
              alignment: .leading)
        }
      }
      .padding(.bottom, scrollBottomPadding)
      .scrollTargetLayout()
    }

    /// 创建媒体项视图
    ///
    /// 根据媒体容器的状态显示不同的视图。
    ///
    /// - Parameter container: 媒体容器
    /// - Returns: 媒体项视图
    private func makeMediaItem(_ container: MediaContainer) -> some View {
      RoundedRectangle(cornerRadius: 8)
        .fill(.clear)
        .overlay {
          switch container.state {
          case .pending(let content):
            makeLocalMediaView(content: content)
          case .uploading(let content, let progress):
            makeUploadingView(content: content, progress: progress)
          case .uploaded(let attachment, _):
            makeRemoteMediaView(mediaAttachement: attachment)
          case .failed(let content, let error):
            makeErrorView(content: content, error: error)
          }
        }
        .contentShape(Rectangle())
        .contextMenu {
          makeImageMenu(container: container)
        }
        .alert("alert.error", isPresented: $isErrorDisplayed) {
          Button("Ok", action: {})
        } message: {
          Text(container.error?.localizedDescription ?? "")
        }
        .overlay(alignment: .bottomTrailing) {
          makeAltMarker(container: container)
        }
        .overlay(alignment: .topTrailing) {
          makeDiscardMarker(container: container)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .id(container.id)
    }

    /// 创建本地媒体视图（待处理状态）
    ///
    /// 显示模糊的预览图和进度指示器。
    ///
    /// - Parameter content: 媒体内容
    /// - Returns: 本地媒体视图
    private func makeLocalMediaView(content: MediaContainer.MediaContent) -> some View {
      ZStack(alignment: .center) {
        if let image = content.previewImage {
          Image(uiImage: image)
            .resizable()
            .blur(radius: 20)
            .scaledToFill()
            .cornerRadius(8)
        } else {
          placeholderView
        }
        ProgressView()
      }
    }

    /// 创建上传中视图
    ///
    /// 显示模糊的预览图和上传进度条。
    ///
    /// - Parameters:
    ///   - content: 媒体内容
    ///   - progress: 上传进度（0.0 - 1.0）
    /// - Returns: 上传中视图
    private func makeUploadingView(content: MediaContainer.MediaContent, progress: Double)
      -> some View
    {
      ZStack(alignment: .center) {
        if let image = content.previewImage {
          Image(uiImage: image)
            .resizable()
            .blur(radius: 10)
            .scaledToFill()
            .cornerRadius(8)
        } else {
          placeholderView
        }
        VStack {
          if progress > 0 && progress < 1 {
            ProgressView(value: progress)
              .progressViewStyle(.linear)
              .padding(.horizontal)
          } else {
            ProgressView()
              .progressViewStyle(.circular)
          }
        }
        .transition(.identity)
        .animation(.bouncy, value: progress)
      }
    }

    /// 创建远程媒体视图（已上传状态）
    ///
    /// 根据媒体类型显示完整的图片或视频。
    ///
    /// - Parameter mediaAttachement: 媒体附件
    /// - Returns: 远程媒体视图
    private func makeRemoteMediaView(mediaAttachement: MediaAttachment) -> some View {
      ZStack(alignment: .center) {
        switch mediaAttachement.supportedType {
        case .gifv, .video, .audio:
          if let url = mediaAttachement.url {
            MediaUIAttachmentVideoView(viewModel: .init(url: url, forceAutoPlay: true))
          } else {
            placeholderView
          }
        case .image:
          if let url = mediaAttachement.url ?? mediaAttachement.previewUrl {
            LazyImage(url: url) { state in
              if let image = state.image {
                image
                  .resizable()
                  .scaledToFill()
                  .clipped()
                  .allowsHitTesting(false)
              } else {
                placeholderView
              }
            }
          }
        case .none:
          EmptyView()
        }
      }
      .cornerRadius(8)
    }

    /// 创建媒体上下文菜单
    ///
    /// 根据媒体状态显示不同的操作选项。
    ///
    /// - Parameter container: 媒体容器
    /// - Returns: 上下文菜单视图
    @ViewBuilder
    private func makeImageMenu(container: MediaContainer) -> some View {
      switch container.state {
      case .uploaded(let attachment, _):
        if attachment.url != nil {
          if currentInstance.isEditAltTextSupported || !viewModel.mode.isEditing {
            Button {
              editingMediaContainer = container
            } label: {
              Label(
                attachment.description?.isEmpty == false
                  ? "status.editor.description.edit" : "status.editor.description.add",
                systemImage: "pencil.line")
            }
          }
        }
      case .failed:
        Button {
          isErrorDisplayed = true
        } label: {
          Label("action.view.error", systemImage: "exclamationmark.triangle")
        }
      case .pending:
        Button {
          Task {
            await viewModel.upload(container: container)
          }
        } label: {
          Label("Retry Upload", systemImage: "arrow.clockwise")
        }
      case .uploading:
        EmptyView()
      }

      Button(role: .destructive) {
        deleteAction(container: container)
      } label: {
        Label("action.delete", systemImage: "trash")
      }
    }

    /// 创建错误视图（失败状态）
    ///
    /// 显示模糊的预览图和错误图标。
    ///
    /// - Parameters:
    ///   - content: 媒体内容
    ///   - error: 错误信息
    /// - Returns: 错误视图
    private func makeErrorView(
      content: MediaContainer.MediaContent, error: MediaContainer.MediaError
    ) -> some View {
      ZStack {
        if let image = content.previewImage {
          Image(uiImage: image)
            .resizable()
            .blur(radius: 5)
            .scaledToFill()
            .cornerRadius(8)
            .opacity(0.5)
        } else {
          placeholderView
        }
        VStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
          Text("status.editor.error.upload")
            .font(.caption)
        }
      }
    }

    /// 创建 Alt 文本标记按钮
    ///
    /// 显示在媒体右下角，用于添加或编辑 Alt 文本。
    /// iOS 26+ 使用 Liquid Glass 样式。
    ///
    /// - Parameter container: 媒体容器
    /// - Returns: Alt 文本标记视图
    @ViewBuilder
    private func makeAltMarker(container: MediaContainer) -> some View {
      if #available(iOS 26.0, *) {
        Button {
          editingMediaContainer = container
        } label: {
          Text("status.image.alt-text.abbreviation")
            .font(.caption2)
            .padding(4)
        }
        .buttonStyle(.glass)
        .padding()
      } else {
        Button {
          editingMediaContainer = container
        } label: {
          Text("status.image.alt-text.abbreviation")
            .font(.caption2)
        }
        .padding(8)
        .background(.thinMaterial)
        .cornerRadius(8)
        .padding(4)
      }
    }

    /// 创建删除按钮
    ///
    /// 显示在媒体右上角，用于删除媒体。
    /// iOS 26+ 使用 Liquid Glass 样式。
    ///
    /// - Parameter container: 媒体容器
    /// - Returns: 删除按钮视图
    @ViewBuilder
    private func makeDiscardMarker(container: MediaContainer) -> some View {
      if #available(iOS 26.0, *) {
        Button(role: .destructive) {
          deleteAction(container: container)
        } label: {
          Image(systemName: "xmark")
            .font(.caption2)
            .padding(4)
        }
        .buttonStyle(.glass)
        .padding()
      } else {
        Button(role: .destructive) {
          deleteAction(container: container)
        } label: {
          Image(systemName: "xmark")
            .font(.caption2)
            .foregroundStyle(.tint)
            .padding(8)
            .background(Circle().fill(.thinMaterial))
        }
        .padding(4)
      }
    }

    /// 删除媒体操作
    ///
    /// 从媒体选择器和容器列表中移除指定的媒体。
    ///
    /// - Parameter container: 要删除的媒体容器
    private func deleteAction(container: MediaContainer) {
      viewModel.mediaPickers.removeAll(where: {
        if let id = $0.itemIdentifier {
          return id == container.id
        }
        return false
      })
      viewModel.mediaContainers.removeAll {
        $0.id == container.id
      }
    }

    /// 占位符视图
    ///
    /// 在媒体加载时显示的占位符。
    private var placeholderView: some View {
      ZStack(alignment: .center) {
        Rectangle()
          .foregroundColor(theme.secondaryBackgroundColor)
          .accessibilityHidden(true)
        ProgressView()
      }
      .cornerRadius(8)
    }
  }
}
