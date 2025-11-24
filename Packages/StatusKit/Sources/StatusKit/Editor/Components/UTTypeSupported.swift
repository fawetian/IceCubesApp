/*
 * UTTypeSupported.swift
 * IceCubesApp - 统一类型标识符支持
 *
 * 功能描述：
 * 处理不同类型的媒体文件加载和传输
 * 支持图片、视频、GIF 等多种格式
 *
 * 核心功能：
 * 1. 类型识别 - 识别文件的 UTType
 * 2. 内容加载 - 从 NSItemProvider 加载内容
 * 3. 可传输协议 - 实现 Transferable 协议
 * 4. 格式转换 - 处理不同格式的媒体
 * 5. 安全访问 - 管理安全作用域资源
 * 6. MIME 类型 - 获取文件的 MIME 类型
 * 7. 图片调整 - 调整图片尺寸
 *
 * 支持的类型：
 * - 图片：.image（JPEG、PNG 等）
 * - 视频：.movie、.video（MP4、MOV 等）
 * - GIF：.gif（动图）
 *
 * 技术点：
 * 1. @MainActor - 主线程操作
 * 2. Transferable - 可传输协议
 * 3. NSItemProvider - 项目提供者
 * 4. UniformTypeIdentifiers - 统一类型标识符
 * 5. FileRepresentation - 文件表示
 * 6. Security-Scoped Resource - 安全作用域资源
 * 7. async/await - 异步操作
 *
 * 使用场景：
 * - 从照片库选择媒体
 * - 从剪贴板粘贴内容
 * - 拖放操作
 * - 分享扩展
 *
 * 依赖关系：
 * - AVFoundation: 视频处理
 * - PhotosUI: 照片选择
 * - UIKit: 图片处理
 * - UniformTypeIdentifiers: 类型识别
 */

import AVFoundation
@preconcurrency import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension StatusEditor {
  /// 统一类型标识符支持
  ///
  /// 处理不同类型的媒体文件加载和传输。
  ///
  /// 主要功能：
  /// - **类型识别**：识别文件的 UTType
  /// - **内容加载**：从 NSItemProvider 加载内容
  /// - **格式转换**：处理不同格式的媒体
  ///
  /// 使用示例：
  /// ```swift
  /// let utType = UTTypeSupported(value: "public.image")
  /// let content = try await utType.loadItemContent(item: provider)
  /// ```
  ///
  /// - Note: 在主线程上操作
  @MainActor
  struct UTTypeSupported {
    /// UTType 标识符字符串
    let value: String

    /// 加载项目内容
    ///
    /// 从 NSItemProvider 加载内容，支持多种类型。
    ///
    /// 加载顺序：
    /// 1. 尝试加载视频（MovieFileTranseferable）
    /// 2. 尝试加载 GIF（GifFileTranseferable）
    /// 3. 尝试加载图片（ImageFileTranseferable）
    /// 4. 回退到通用加载（URL、String、UIImage）
    ///
    /// - Parameter item: NSItemProvider 实例
    /// - Returns: 加载的内容（URL、String、UIImage 或 Transferable）
    /// - Throws: 加载失败时抛出错误
    ///
    /// - Note: 使用 Transferable 协议优先加载
    func loadItemContent(item: NSItemProvider) async throws -> Any? {
      // 优先尝试使用 Transferable 协议加载
      if let transferable = await getVideoTransferable(item: item) {
        return transferable
      } else if let transferable = await getGifTransferable(item: item) {
        return transferable
      } else if let transferable = await getImageTansferable(item: item) {
        return transferable
      } else {
        // 回退到通用加载方式
        return await withCheckedContinuation { continuation in
          item.loadItem(forTypeIdentifier: value) { result, error in
            if let url = result as? URL {
              continuation.resume(returning: url.absoluteString)
            } else if let text = result as? String {
              continuation.resume(returning: text)
            } else if let image = result as? UIImage {
              continuation.resume(returning: image)
            } else {
              continuation.resume(returning: nil)
            }
          }
        }
      }
    }

    /// 获取视频可传输对象
    ///
    /// 尝试将项目加载为视频文件。
    ///
    /// - Parameter item: NSItemProvider 实例
    /// - Returns: 视频可传输对象，失败返回 nil
    private func getVideoTransferable(item: NSItemProvider) async -> MovieFileTranseferable? {
      await withCheckedContinuation { continuation in
        _ = item.loadTransferable(type: MovieFileTranseferable.self) { result in
          switch result {
          case .success(let success):
            continuation.resume(with: .success(success))
          case .failure:
            continuation.resume(with: .success(nil))
          }
        }
      }
    }

    /// 获取 GIF 可传输对象
    ///
    /// 尝试将项目加载为 GIF 文件。
    ///
    /// - Parameter item: NSItemProvider 实例
    /// - Returns: GIF 可传输对象，失败返回 nil
    private func getGifTransferable(item: NSItemProvider) async -> GifFileTranseferable? {
      await withCheckedContinuation { continuation in
        _ = item.loadTransferable(type: GifFileTranseferable.self) { result in
          switch result {
          case .success(let success):
            continuation.resume(with: .success(success))
          case .failure:
            continuation.resume(with: .success(nil))
          }
        }
      }
    }

    /// 获取图片可传输对象
    ///
    /// 尝试将项目加载为图片文件。
    ///
    /// - Parameter item: NSItemProvider 实例
    /// - Returns: 图片可传输对象，失败返回 nil
    private func getImageTansferable(item: NSItemProvider) async -> ImageFileTranseferable? {
      await withCheckedContinuation { continuation in
        _ = item.loadTransferable(type: ImageFileTranseferable.self) { result in
          switch result {
          case .success(let success):
            continuation.resume(with: .success(success))
          case .failure:
            continuation.resume(with: .success(nil))
          }
        }
      }
    }
  }
}

extension StatusEditor {
  /// 视频文件可传输对象
  ///
  /// 实现 Transferable 协议，用于传输视频文件。
  ///
  /// 主要功能：
  /// - **安全访问**：管理安全作用域资源
  /// - **自动清理**：deinit 时停止访问
  /// - **多格式支持**：支持 .movie 和 .video 类型
  ///
  /// - Note: 使用 final class 确保不被继承
  /// - Important: 自动管理安全作用域资源的生命周期
  final class MovieFileTranseferable: Transferable, Sendable {
    /// 视频文件 URL
    let url: URL

    /// 初始化视频可传输对象
    ///
    /// 开始访问安全作用域资源。
    ///
    /// - Parameter url: 视频文件 URL
    init(url: URL) {
      self.url = url
      _ = url.startAccessingSecurityScopedResource()
    }

    /// 析构函数
    ///
    /// 停止访问安全作用域资源。
    deinit {
      url.stopAccessingSecurityScopedResource()
    }

    /// 传输表示
    ///
    /// 定义如何传输视频文件。
    /// 支持 .movie 和 .video 两种类型。
    static var transferRepresentation: some TransferRepresentation {
      FileRepresentation(importedContentType: .movie) { receivedTransferrable in
        MovieFileTranseferable(url: receivedTransferrable.localURL)
      }
      FileRepresentation(importedContentType: .video) { receivedTransferrable in
        MovieFileTranseferable(url: receivedTransferrable.localURL)
      }
    }
  }

  /// GIF 文件可传输对象
  ///
  /// 实现 Transferable 协议，用于传输 GIF 文件。
  ///
  /// 主要功能：
  /// - **安全访问**：管理安全作用域资源
  /// - **数据访问**：提供 Data 属性读取文件内容
  /// - **自动清理**：deinit 时停止访问
  ///
  /// - Note: GIF 文件通常较小，可以直接读取为 Data
  final class GifFileTranseferable: Transferable, Sendable {
    /// GIF 文件 URL
    let url: URL

    /// 初始化 GIF 可传输对象
    ///
    /// 开始访问安全作用域资源。
    ///
    /// - Parameter url: GIF 文件 URL
    init(url: URL) {
      self.url = url
      _ = url.startAccessingSecurityScopedResource()
    }

    /// 析构函数
    ///
    /// 停止访问安全作用域资源。
    deinit {
      url.stopAccessingSecurityScopedResource()
    }

    /// GIF 文件数据
    ///
    /// 读取 GIF 文件的完整数据。
    ///
    /// - Returns: 文件数据，失败返回 nil
    var data: Data? {
      try? Data(contentsOf: url)
    }

    /// 传输表示
    ///
    /// 定义如何传输 GIF 文件。
    static var transferRepresentation: some TransferRepresentation {
      FileRepresentation(importedContentType: .gif) { receivedTransferrable in
        GifFileTranseferable(url: receivedTransferrable.localURL)
      }
    }
  }
}

extension StatusEditor {
  /// 图片文件可传输对象
  ///
  /// 实现 Transferable 协议，用于传输图片文件。
  ///
  /// 主要功能：
  /// - **安全访问**：管理安全作用域资源
  /// - **自动清理**：deinit 时停止访问
  /// - **多格式支持**：支持所有 .image 类型
  ///
  /// - Note: 公开类，可在包外使用
  public final class ImageFileTranseferable: Transferable, Sendable {
    /// 图片文件 URL
    public let url: URL

    /// 初始化图片可传输对象
    ///
    /// 开始访问安全作用域资源。
    ///
    /// - Parameter url: 图片文件 URL
    init(url: URL) {
      self.url = url
      _ = url.startAccessingSecurityScopedResource()
    }

    /// 析构函数
    ///
    /// 停止访问安全作用域资源。
    deinit {
      url.stopAccessingSecurityScopedResource()
    }

    /// 传输表示
    ///
    /// 定义如何传输图片文件。
    public static var transferRepresentation: some TransferRepresentation {
      FileRepresentation(importedContentType: .image) { receivedTransferrable in
        ImageFileTranseferable(url: receivedTransferrable.localURL)
      }
    }
  }
}

/// ReceivedTransferredFile 扩展
///
/// 提供本地 URL 访问功能。
extension ReceivedTransferredFile {
  /// 本地 URL
  ///
  /// 如果是原始文件则直接返回，否则复制到临时目录。
  ///
  /// - Returns: 本地文件 URL
  ///
  /// - Note: 非原始文件会被复制到临时目录
  public var localURL: URL {
    if isOriginalFile {
      return file
    }
    let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(file.pathExtension)")
    try? FileManager.default.copyItem(at: file, to: copy)
    return copy
  }
}

/// URL 扩展
///
/// 提供 MIME 类型获取功能。
extension URL {
  /// 获取文件的 MIME 类型
  ///
  /// 根据文件扩展名确定 MIME 类型。
  ///
  /// - Returns: MIME 类型字符串，未知类型返回 "application/octet-stream"
  ///
  /// - Note: 使用 UniformTypeIdentifiers 框架
  public func mimeType() -> String {
    if let mimeType = UTType(filenameExtension: pathExtension)?.preferredMIMEType {
      mimeType
    } else {
      "application/octet-stream"
    }
  }
}

/// UIImage 扩展
///
/// 提供图片尺寸调整功能。
extension UIImage {
  /// 调整图片尺寸
  ///
  /// 使用 UIGraphicsImageRenderer 重新绘制图片。
  ///
  /// - Parameter size: 目标尺寸
  /// - Returns: 调整后的图片
  ///
  /// - Note: 使用 UIGraphicsImageRenderer 确保正确的颜色空间
  func resized(to size: CGSize) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
