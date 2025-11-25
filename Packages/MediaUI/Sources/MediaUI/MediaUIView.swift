/*
 * MediaUIView.swift
 * IceCubesApp - 媒体全屏查看器
 *
 * 功能描述：
 * 提供媒体附件的全屏查看和交互功能
 * 支持图片、视频、GIF 的横向滑动浏览
 *
 * 核心功能：
 * 1. 全屏显示 - 全屏查看媒体内容
 * 2. 横向滑动 - 支持多个媒体之间的横向滑动切换
 * 3. 键盘导航 - 支持左右箭头键切换
 * 4. 工具栏 - 提供关闭、快速查看、Alt 文本、保存、分享等操作
 * 5. Alt 文本 - 显示和查看媒体的替代文本
 * 6. 保存图片 - 保存图片到相册（需要权限）
 * 7. 快速查看 - 使用系统 QuickLook 查看
 * 8. 分享 - 分享媒体文件
 * 9. 自动聚焦 - 自动聚焦以启用键盘导航
 * 10. 滚动定位 - 自动滚动到初始选中的媒体
 *
 * 技术点：
 * 1. NavigationStack - 导航容器
 * 2. ScrollView - 横向滚动
 * 3. LazyHStack - 延迟加载水平布局
 * 4. FocusState - 焦点状态管理
 * 5. scrollPosition - iOS 17+ 滚动定位
 * 6. onKeyPress - 键盘事件处理
 * 7. Toolbar - 工具栏
 * 8. Photos - 相册访问
 * 9. QuickLook - 快速查看
 * 10. Sendable - 并发安全（@unchecked）
 *
 * 视图层次：
 * - NavigationStack
 *   - ScrollView（横向）
 *     - LazyHStack
 *       - ForEach（媒体项）
 *         - DisplayView（图片/视频）
 *   - Toolbar
 *     - DismissToolbarItem（关闭按钮）
 *     - QuickLookToolbarItem（快速查看）
 *     - AltTextToolbarItem（Alt 文本）
 *     - SavePhotoToolbarItem（保存图片）
 *     - ShareToolbarItem（分享）
 *
 * 工具栏按钮：
 * - 关闭：退出全屏查看
 * - 快速查看：使用系统 QuickLook
 * - Alt 文本：显示替代文本（如果有）
 * - 保存：保存图片到相册（仅图片）
 * - 分享：分享媒体文件
 *
 * 键盘快捷键：
 * - 左箭头：切换到上一个媒体
 * - 右箭头：切换到下一个媒体
 * - Esc（关闭按钮）：退出全屏
 *
 * 使用场景：
 * - 帖子中点击媒体查看
 * - 浏览帖子的所有媒体附件
 * - 保存和分享媒体内容
 *
 * 依赖关系：
 * - Models: MediaAttachment
 * - Nuke: 图片缓存和加载
 * - Photos: 相册访问
 * - QuickLook: 快速查看
 */

import AVFoundation
import Models
import Nuke
import Photos
import QuickLook
import SwiftUI

/// 媒体全屏查看器
///
/// 提供媒体附件的全屏浏览和交互功能。
///
/// 主要功能：
/// - **全屏显示**：全屏查看图片、视频、GIF
/// - **横向滑动**：支持多个媒体之间的滑动切换
/// - **工具栏操作**：关闭、快速查看、Alt 文本、保存、分享
/// - **键盘导航**：支持左右箭头键切换
///
/// 使用示例：
/// ```swift
/// MediaUIView(
///     selectedAttachment: selectedAttachment,
///     attachments: allAttachments
/// )
/// ```
///
/// - Note: 使用 @unchecked Sendable 以支持并发环境
/// - Important: 保存图片需要相册访问权限
public struct MediaUIView: View, @unchecked Sendable {
  /// 媒体数据数组
  private let data: [DisplayData]
  /// 初始选中的媒体项
  private let initialItem: DisplayData?
  /// 当前滚动到的媒体项
  @State private var scrolledItem: DisplayData?
  /// 是否聚焦（用于键盘导航）
  @FocusState private var isFocused: Bool

  public var body: some View {
    NavigationStack {
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack {
          ForEach(data) {
            DisplayView(data: $0)
              .containerRelativeFrame([.horizontal, .vertical])
              .id($0)
          }
        }
        .scrollTargetLayout()
      }
      .focusable()
      .focused($isFocused)
      .focusEffectDisabled()
      .onKeyPress(
        .leftArrow,
        action: {
          scrollToPrevious()
          return .handled
        }
      )
      .onKeyPress(
        .rightArrow,
        action: {
          scrollToNext()
          return .handled
        }
      )
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $scrolledItem)
      .toolbar {
        if let item = scrolledItem {
          MediaToolBar(data: item)
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
          scrolledItem = initialItem
          isFocused = true
        }
      }
    }
  }

  /// 初始化方法
  ///
  /// 根据选中的媒体附件和所有附件创建查看器。
  ///
  /// - Parameters:
  ///   - selectedAttachment: 初始选中的媒体附件
  ///   - attachments: 所有媒体附件数组
  public init(selectedAttachment: MediaAttachment, attachments: [MediaAttachment]) {
    data = attachments.compactMap { DisplayData(from: $0) }
    initialItem = DisplayData(from: selectedAttachment)
  }

  /// 滚动到上一个媒体
  ///
  /// 使用动画切换到上一个媒体项。
  private func scrollToPrevious() {
    if let scrolledItem, let index = data.firstIndex(of: scrolledItem), index > 0 {
      withAnimation {
        self.scrolledItem = data[index - 1]
      }
    }
  }

  /// 滚动到下一个媒体
  ///
  /// 使用动画切换到下一个媒体项。
  private func scrollToNext() {
    if let scrolledItem, let index = data.firstIndex(of: scrolledItem), index < data.count - 1 {
      withAnimation {
        self.scrolledItem = data[index + 1]
      }
    }
  }
}

/// 媒体工具栏
///
/// 提供媒体查看器的工具栏按钮。
private struct MediaToolBar: ToolbarContent {
  /// 媒体数据
  let data: DisplayData

  var body: some ToolbarContent {
    #if !targetEnvironment(macCatalyst)
      DismissToolbarItem()
    #endif
    QuickLookToolbarItem(itemUrl: data.url)
    AltTextToolbarItem(alt: data.description)
    SavePhotoToolbarItem(url: data.url, type: data.type)
    ShareToolbarItem(url: data.url, type: data.type)
  }
}

/// 关闭按钮工具栏项
///
/// 显示在左上角，点击关闭全屏查看器。
/// macCatalyst 不显示此按钮（使用系统关闭）。
private struct DismissToolbarItem: ToolbarContent {
  @Environment(\.dismiss) private var dismiss

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark.circle")
      }
      .keyboardShortcut(.cancelAction)
    }
  }
}

/// Alt 文本工具栏项
///
/// 显示媒体的替代文本（如果有）。
/// 点击按钮弹出 Alert 显示完整的 Alt 文本。
private struct AltTextToolbarItem: ToolbarContent {
  /// 替代文本
  let alt: String?
  /// 是否显示 Alert
  @State private var isAlertDisplayed = false

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      if let alt {
        Button {
          isAlertDisplayed = true
        } label: {
          Text("status.image.alt-text.abbreviation")
        }
        .alert(
          "status.editor.media.image-description",
          isPresented: $isAlertDisplayed
        ) {
          Button("alert.button.ok", action: {})
        } message: {
          Text(alt)
        }
      } else {
        EmptyView()
      }
    }
  }
}

/// 保存图片工具栏项
///
/// 提供保存图片到相册的功能。
/// 仅对图片类型显示，视频不显示此按钮。
private struct SavePhotoToolbarItem: ToolbarContent, @unchecked Sendable {
  /// 媒体 URL
  let url: URL
  /// 媒体类型
  let type: DisplayType
  /// 保存状态
  @State private var state = SavingState.unsaved

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      if type == .image {
        Button {
          Task {
            state = .saving
            if await saveImage(url: url) {
              withAnimation {
                state = .saved
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                  state = .unsaved
                }
              }
            } else {
              state = .unsaved
            }
          }
        } label: {
          switch state {
          case .unsaved: Image(systemName: "arrow.down.circle")
          case .saving: ProgressView()
          case .saved: Image(systemName: "checkmark.circle.fill")
          }
        }
      } else {
        EmptyView()
      }
    }
  }

  /// 保存状态枚举
  private enum SavingState {
    /// 未保存
    case unsaved
    /// 保存中
    case saving
    /// 已保存
    case saved
  }

  /// 获取图片数据
  ///
  /// 优先从 Nuke 缓存读取，如果没有则从网络下载。
  ///
  /// - Parameter url: 图片 URL
  /// - Returns: 图片数据
  private func imageData(_ url: URL) async -> Data? {
    var data = ImagePipeline.shared.cache.cachedData(for: .init(url: url))
    if data == nil {
      data = try? await URLSession.shared.data(from: url).0
    }
    return data
  }

  /// 将 URL 转换为 UIImage
  ///
  /// - Parameter url: 图片 URL
  /// - Returns: UIImage 对象
  /// - Throws: 转换失败时抛出错误
  private func uiimageFor(url: URL) async throws -> UIImage? {
    let data = await imageData(url)
    if let data {
      return UIImage(data: data)
    }
    return nil
  }

  /// 保存图片到相册
  ///
  /// 请求相册访问权限后保存图片。
  ///
  /// - Parameter url: 图片 URL
  /// - Returns: 是否保存成功
  private func saveImage(url: URL) async -> Bool {
    guard let image = try? await uiimageFor(url: url) else { return false }

    var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

    if status != .authorized {
      await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    if status == .authorized {
      UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
      return true
    }
    return false
  }
}

/// 媒体显示数据
///
/// 从 MediaAttachment 提取用于显示的核心数据。
private struct DisplayData: Identifiable, Hashable {
  /// 唯一标识符
  let id: String
  /// 媒体 URL
  let url: URL
  /// 替代文本描述
  let description: String?
  /// 媒体类型
  let type: DisplayType

  /// 从 MediaAttachment 创建 DisplayData
  ///
  /// - Parameter attachment: 媒体附件
  /// - Returns: DisplayData 对象，如果附件无效则返回 nil
  init?(from attachment: MediaAttachment) {
    guard let url = attachment.url else { return nil }
    guard let type = attachment.supportedType else { return nil }

    id = attachment.id
    self.url = url
    description = attachment.description
    self.type = DisplayType(from: type)
  }
}

/// 媒体显示视图
///
/// 根据媒体类型显示图片或视频。
private struct DisplayView: View {
  /// 媒体数据
  let data: DisplayData

  var body: some View {
    switch data.type {
    case .image:
      MediaUIAttachmentImageView(url: data.url)
    case .av:
      MediaUIAttachmentVideoView(viewModel: .init(url: data.url, forceAutoPlay: true))
        .ignoresSafeArea()
    }
  }
}
