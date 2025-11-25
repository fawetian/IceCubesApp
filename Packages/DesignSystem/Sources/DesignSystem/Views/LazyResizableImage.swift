/*
 * LazyResizableImage.swift
 * IceCubesApp - 可调整大小的懒加载图片组件
 *
 * 文件功能：
 * 提供一个性能优化的图片加载组件，使用 GeometryReader 自动检测容器尺寸并调整图片处理器。
 *
 * 核心职责：
 * - 根据容器大小动态调整图片加载尺寸
 * - 使用防抖技术避免频繁的图片处理器更新
 * - 优化列表中的图片加载性能
 * - 支持平滑的尺寸变化
 *
 * 技术要点：
 * - GeometryReader 检测视图尺寸
 * - Nuke ImageProcessors.Resize 处理器
 * - Task 防抖延迟更新（200ms）
 * - @State 管理处理器和防抖任务
 * - @ViewBuilder 泛型内容构建
 *
 * 使用场景：
 * - 时间线列表中的媒体图片
 * - 需要自适应容器尺寸的图片
 * - 性能敏感的图片列表
 *
 * 依赖关系：
 * - Nuke: 图片加载和处理
 * - NukeUI: SwiftUI 集成
 *
 * 创建者：Hugo Saynac
 * 创建时间：2023-10-28
 */

import Nuke
import NukeUI
import SwiftUI

/// 可调整大小的懒加载图片组件。
///
/// 使用 GeometryReader 监听容器尺寸变化，并通过防抖机制优化图片处理器更新，
/// 提升列表滚动性能。
public struct LazyResizableImage<Content: View>: View {
  /// 初始化方法。
  ///
  /// - Parameters:
  ///   - url: 图片 URL。
  ///   - content: 自定义内容构建器，接收图片加载状态。
  public init(url: URL?, @ViewBuilder content: @escaping (LazyImageState) -> Content) {
    imageURL = url
    self.content = content
  }

  /// 图片 URL。
  let imageURL: URL?
  /// 当前使用的调整大小处理器。
  @State private var resizeProcessor: ImageProcessors.Resize?
  /// 防抖任务（用于延迟更新处理器）。
  @State private var debouncedTask: Task<Void, Never>?

  /// 自定义内容构建器。
  @ViewBuilder
  private var content: (LazyImageState) -> Content

  /// 视图主体。
  public var body: some View {
    GeometryReader { proxy in
      LazyImage(url: imageURL) { state in
        content(state)
      }
      .processors([resizeProcessor == nil ? .resize(size: proxy.size) : resizeProcessor!])
      .onChange(of: proxy.size, initial: true) { oldValue, newValue in
        guard oldValue != newValue else { return }
        updateResizing(with: newValue)
      }
    }
  }

  /// 更新图片处理器（使用防抖避免频繁更新）。
  ///
  /// - Parameter newSize: 新的容器尺寸。
  private func updateResizing(with newSize: CGSize) {
    debouncedTask?.cancel()
    debouncedTask = Task {
      do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
      await MainActor.run {
        resizeProcessor = .resize(size: newSize)
      }
    }
  }
}
