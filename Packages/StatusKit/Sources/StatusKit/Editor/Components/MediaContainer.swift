/*
 * MediaContainer.swift
 * IceCubesApp - 媒体容器数据模型
 *
 * 功能描述：
 * 定义编辑器中媒体附件的数据结构和状态管理
 * 支持图片、视频、GIF 的上传和状态跟踪
 *
 * 核心功能：
 * 1. 媒体状态管理 - 待处理、上传中、已上传、失败
 * 2. 媒体类型支持 - 图片、视频、GIF
 * 3. 进度跟踪 - 上传进度监控
 * 4. 错误处理 - 详细的错误类型和描述
 * 5. 预览图片 - 所有媒体类型的预览
 * 6. 向后兼容 - 便捷访问器
 * 7. 工厂方法 - 简化容器创建
 * 8. Sendable 支持 - 并发安全
 *
 * 技术点：
 * 1. Identifiable - 唯一标识符协议
 * 2. Sendable - 并发安全协议
 * 3. 枚举关联值 - 携带不同类型数据
 * 4. 嵌套枚举 - 组织相关类型
 * 5. 计算属性 - 派生状态
 * 6. 工厂方法 - 静态构造函数
 * 7. 模式匹配 - switch 语句
 * 8. 可选值处理 - 安全解包
 * 9. Error 协议 - 错误类型定义
 * 10. LocalizedError - 本地化错误描述
 *
 * 状态流转：
 * pending -> uploading -> uploaded (成功)
 *        -> uploading -> failed (失败)
 *        -> failed (直接失败)
 *
 * 媒体类型：
 * - image: 静态图片（JPEG、PNG 等）
 * - video: 视频文件（MP4、MOV 等）
 * - gif: 动图文件（GIF）
 *
 * 错误类型：
 * - compressionFailed: 压缩失败
 * - uploadFailed: 上传失败
 * - invalidFormat: 格式无效
 * - sizeLimitExceeded: 超过大小限制
 *
 * 使用场景：
 * - 编辑器中添加媒体附件
 * - 跟踪媒体上传进度
 * - 显示媒体预览
 * - 处理上传错误
 * - 编辑媒体描述（Alt 文本）
 *
 * 依赖关系：
 * - Models: MediaAttachment、ServerError
 * - PhotosUI: 照片选择
 * - UIKit: UIImage
 */

import Foundation
import Models
import PhotosUI
import SwiftUI
import UIKit

extension StatusEditor {
  /// 媒体容器
  ///
  /// 封装媒体附件的状态和内容。
  ///
  /// 主要功能：
  /// - **状态管理**：跟踪媒体从待处理到上传完成的整个生命周期
  /// - **类型支持**：支持图片、视频、GIF 三种媒体类型
  /// - **进度跟踪**：监控上传进度
  /// - **错误处理**：详细的错误信息和恢复选项
  ///
  /// 使用示例：
  /// ```swift
  /// // 创建待处理的图片容器
  /// let container = MediaContainer.pending(id: UUID().uuidString, image: uiImage)
  ///
  /// // 更新为上传中状态
  /// let uploading = MediaContainer.uploading(
  ///     id: container.id,
  ///     content: .image(uiImage),
  ///     progress: 0.5
  /// )
  ///
  /// // 更新为已上传状态
  /// let uploaded = MediaContainer.uploaded(
  ///     id: container.id,
  ///     attachment: mediaAttachment,
  ///     originalImage: uiImage
  /// )
  /// ```
  struct MediaContainer: Identifiable, Sendable {
    /// 唯一标识符
    let id: String
    /// 当前状态
    let state: MediaState

    /// 媒体状态枚举
    ///
    /// 定义媒体附件的四种可能状态。
    enum MediaState: Sendable {
      /// 待处理 - 等待上传
      case pending(content: MediaContent)
      /// 上传中 - 正在上传，包含进度
      case uploading(content: MediaContent, progress: Double)
      /// 已上传 - 上传成功，包含服务器返回的附件信息
      case uploaded(attachment: MediaAttachment, originalImage: UIImage?)
      /// 失败 - 上传失败，包含错误信息
      case failed(content: MediaContent, error: MediaError)
    }

    /// 媒体内容枚举
    ///
    /// 定义三种支持的媒体类型。
    enum MediaContent: Sendable {
      /// 图片
      case image(UIImage)
      /// 视频（包含可选预览图）
      case video(MovieFileTranseferable, previewImage: UIImage?)
      /// GIF（包含可选预览图）
      case gif(GifFileTranseferable, previewImage: UIImage?)

      /// 获取预览图片
      ///
      /// 对于图片类型，返回图片本身；
      /// 对于视频和 GIF，返回预览图（如果有）。
      var previewImage: UIImage? {
        switch self {
        case .image(let image):
          return image
        case .video(_, let preview):
          return preview
        case .gif(_, let preview):
          return preview
        }
      }
    }

    /// 媒体错误枚举
    ///
    /// 定义可能发生的错误类型。
    enum MediaError: Error, LocalizedError, Sendable {
      /// 压缩失败
      case compressionFailed
      /// 上传失败（包含服务器错误）
      case uploadFailed(ServerError)
      /// 格式无效
      case invalidFormat
      /// 超过大小限制
      case sizeLimitExceeded

      /// 错误描述
      var errorDescription: String? {
        switch self {
        case .compressionFailed:
          return "Failed to compress media"
        case .uploadFailed(let error):
          return error.localizedDescription
        case .invalidFormat:
          return "Invalid media format"
        case .sizeLimitExceeded:
          return "Media size exceeds limit"
        }
      }
    }

    // MARK: - 便捷访问器（向后兼容）

    /// 获取图片
    ///
    /// 根据当前状态返回相应的图片。
    var image: UIImage? {
      switch state {
      case .pending(let content), .uploading(let content, _), .failed(let content, _):
        return content.previewImage
      case .uploaded(_, let originalImage):
        return originalImage
      }
    }

    /// 获取视频传输对象
    ///
    /// 如果内容是视频，返回传输对象。
    var movieTransferable: MovieFileTranseferable? {
      switch state {
      case .pending(let content), .uploading(let content, _), .failed(let content, _):
        if case .video(let transferable, _) = content {
          return transferable
        }
      case .uploaded:
        break
      }
      return nil
    }

    /// 获取 GIF 传输对象
    ///
    /// 如果内容是 GIF，返回传输对象。
    var gifTransferable: GifFileTranseferable? {
      switch state {
      case .pending(let content), .uploading(let content, _), .failed(let content, _):
        if case .gif(let transferable, _) = content {
          return transferable
        }
      case .uploaded:
        break
      }
      return nil
    }

    /// 获取媒体附件
    ///
    /// 如果已上传，返回服务器返回的附件信息。
    var mediaAttachment: MediaAttachment? {
      if case .uploaded(let attachment, _) = state {
        return attachment
      }
      return nil
    }

    /// 获取错误信息
    ///
    /// 如果状态是失败，返回错误对象。
    var error: Error? {
      if case .failed(_, let error) = state {
        return error
      }
      return nil
    }

    // MARK: - 初始化方法

    /// 直接初始化方法
    ///
    /// 使用指定的 ID 和状态创建容器。
    ///
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - state: 媒体状态
    init(id: String, state: MediaState) {
      self.id = id
      self.state = state
    }

    // MARK: - 工厂方法

    /// 创建待处理的图片容器
    ///
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - image: UIImage 对象
    /// - Returns: 待处理状态的媒体容器
    static func pending(id: String, image: UIImage) -> MediaContainer {
      MediaContainer(id: id, state: .pending(content: .image(image)))
    }

    /// 创建待处理的视频容器
    ///
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - video: 视频传输对象
    ///   - preview: 可选的预览图片
    /// - Returns: 待处理状态的媒体容器
    static func pending(id: String, video: MovieFileTranseferable, preview: UIImage?)
      -> MediaContainer
    {
      MediaContainer(id: id, state: .pending(content: .video(video, previewImage: preview)))
    }

    /// 创建待处理的 GIF 容器
    ///
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - gif: GIF 传输对象
    ///   - preview: 可选的预览图片
    /// - Returns: 待处理状态的媒体容器
    static func pending(id: String, gif: GifFileTranseferable, preview: UIImage?) -> MediaContainer
    {
      MediaContainer(id: id, state: .pending(content: .gif(gif, previewImage: preview)))
    }

    /// 创建上传中的容器
    ///
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - content: 媒体内容
    ///   - progress: 上传进度（0.0 - 1.0）
    /// - Returns: 上传中状态的媒体容器
    static func uploading(id: String, content: MediaContent, progress: Double) -> MediaContainer {
      MediaContainer(id: id, state: .uploading(content: content, progress: progress))
    }

    /// 创建已上传的容器
    ///
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - attachment: 服务器返回的媒体附件
    ///   - originalImage: 可选的原始图片
    /// - Returns: 已上传状态的媒体容器
    static func uploaded(id: String, attachment: MediaAttachment, originalImage: UIImage?)
      -> MediaContainer
    {
      MediaContainer(id: id, state: .uploaded(attachment: attachment, originalImage: originalImage))
    }

    /// 创建失败的容器
    ///
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - content: 媒体内容
    ///   - error: 错误信息
    /// - Returns: 失败状态的媒体容器
    static func failed(id: String, content: MediaContent, error: MediaError) -> MediaContainer {
      MediaContainer(id: id, state: .failed(content: content, error: error))
    }

  }
}
