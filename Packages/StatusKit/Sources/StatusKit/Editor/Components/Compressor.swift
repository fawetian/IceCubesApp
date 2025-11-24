/*
 * Compressor.swift
 * IceCubesApp - 媒体压缩器
 *
 * 功能描述：
 * 负责压缩图片和视频，以满足上传大小限制
 * 使用 actor 确保线程安全的异步压缩操作
 *
 * 核心功能：
 * 1. 图片压缩 - 从 URL 压缩图片
 * 2. 上传压缩 - 为上传准备压缩图片
 * 3. 视频压缩 - 压缩视频文件
 * 4. 尺寸调整 - 调整图片尺寸
 * 5. 质量控制 - 动态调整压缩质量
 * 6. 格式转换 - 转换为 JPEG/MP4 格式
 *
 * 压缩策略：
 * - 图片：降采样 + JPEG 压缩
 * - 视频：转码为 MP4 + 分辨率调整
 * - 扩展：使用更小的尺寸限制
 *
 * 技术点：
 * 1. actor - 确保线程安全
 * 2. async/await - 异步操作
 * 3. CGImageSource - 图片源处理
 * 4. CGImageDestination - 图片目标处理
 * 5. AVAssetExportSession - 视频导出
 * 6. withCheckedContinuation - 桥接回调
 *
 * 使用场景：
 * - 上传图片前压缩
 * - 上传视频前转码
 * - 减少网络传输大小
 * - 满足服务器大小限制
 *
 * 依赖关系：
 * - AVFoundation: 视频处理
 * - UIKit: 图片处理
 */

import AVFoundation
import Foundation
import UIKit

extension StatusEditor {
  /// 媒体压缩器
  ///
  /// 使用 actor 确保线程安全的异步压缩操作。
  ///
  /// 主要功能：
  /// - **图片压缩**：降采样和 JPEG 压缩
  /// - **视频压缩**：转码为 MP4 格式
  /// - **尺寸调整**：调整图片尺寸以满足限制
  /// - **质量控制**：动态调整压缩质量
  ///
  /// 使用示例：
  /// ```swift
  /// let compressor = Compressor()
  /// let data = await compressor.compressImageFrom(url: imageURL)
  /// ```
  ///
  /// - Note: 使用 actor 确保并发安全
  /// - Important: 扩展中使用更小的尺寸限制
  public actor Compressor {
    /// 初始化压缩器
    public init() {}

    /// 压缩器错误
    ///
    /// 定义压缩过程中可能出现的错误。
    enum CompressorError: Error {
      /// 无数据错误
      ///
      /// 当无法生成压缩数据时抛出。
      case noData
    }

    /// 从 URL 压缩图片
    ///
    /// 使用降采样技术压缩图片，减少内存使用。
    ///
    /// 压缩策略：
    /// 1. 创建图片源（不缓存）
    /// 2. 降采样到最大像素尺寸
    /// 3. 转换为 JPEG 格式
    /// 4. 应用压缩质量（PNG: 1.0, 其他: 0.75）
    ///
    /// 最大像素尺寸：
    /// - 扩展：1536 像素
    /// - 主应用：4096 像素
    ///
    /// - Parameter url: 图片文件 URL
    /// - Returns: 压缩后的图片数据，失败返回 nil
    ///
    /// - Note: 使用 CGImageSource 降采样，避免加载完整图片
    public func compressImageFrom(url: URL) async -> Data? {
      await withCheckedContinuation { continuation in
        // 创建图片源（不缓存）
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
          continuation.resume(returning: nil)
          return
        }

        // 根据运行环境确定最大像素尺寸
        let maxPixelSize: Int =
          if Bundle.main.bundlePath.hasSuffix(".appex") {
            1536  // 扩展中使用较小尺寸
          } else {
            4096  // 主应用使用较大尺寸
          }

        // 降采样选项
        let downsampleOptions =
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,  // 总是创建缩略图
            kCGImageSourceCreateThumbnailWithTransform: true,  // 应用方向变换
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,  // 最大像素尺寸
          ] as [CFString: Any] as CFDictionary

        // 创建降采样后的图片
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
          continuation.resume(returning: nil)
          return
        }

        // 创建目标数据
        let data = NSMutableData()
        guard
          let imageDestination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil)
        else {
          continuation.resume(returning: nil)
          return
        }

        // 检查是否为 PNG 格式
        let isPNG: Bool = {
          guard let utType = cgImage.utType else { return false }
          return (utType as String) == UTType.png.identifier
        }()

        // 设置压缩质量（PNG 使用无损，其他使用 0.75）
        let destinationProperties =
          [
            kCGImageDestinationLossyCompressionQuality: isPNG ? 1.0 : 0.75
          ] as CFDictionary

        // 添加图片并完成
        CGImageDestinationAddImage(imageDestination, cgImage, destinationProperties)
        CGImageDestinationFinalize(imageDestination)

        continuation.resume(returning: data as Data)
      }
    }

    /// 为上传压缩图片
    ///
    /// 调整图片尺寸并压缩，以满足上传大小限制。
    ///
    /// 压缩策略：
    /// 1. 检查尺寸，超过限制则缩小
    /// 2. 转换为 JPEG 格式（初始质量 0.8）
    /// 3. 如果仍超过大小限制，逐步降低质量
    /// 4. 质量降到 0 仍超限则抛出错误
    ///
    /// - Parameters:
    ///   - image: 要压缩的图片
    ///   - maxSize: 最大文件大小（字节），默认 10MB
    ///   - maxHeight: 最大高度（像素），默认 5000
    ///   - maxWidth: 最大宽度（像素），默认 5000
    /// - Returns: 压缩后的图片数据
    /// - Throws: CompressorError.noData 如果无法生成数据
    ///
    /// - Note: 使用 JPEG 格式以获得更好的压缩率
    public func compressImageForUpload(
      _ image: UIImage,
      maxSize: Int = 10 * 1024 * 1024,
      maxHeight: Double = 5000,
      maxWidth: Double = 5000
    ) async throws -> Data {
      var image = image

      // 检查并调整图片尺寸
      if image.size.height > maxHeight || image.size.width > maxWidth {
        let heightFactor = image.size.height / maxHeight
        let widthFactor = image.size.width / maxWidth
        let maxFactor = max(heightFactor, widthFactor)

        // 按比例缩小图片
        image = image.resized(
          to: .init(
            width: image.size.width / maxFactor,
            height: image.size.height / maxFactor))
      }

      // 初始压缩（质量 0.8）
      guard var imageData = image.jpegData(compressionQuality: 0.8) else {
        throw CompressorError.noData
      }

      // 如果仍超过大小限制，逐步降低质量
      var compressionQualityFactor: CGFloat = 0.8
      if imageData.count > maxSize {
        while imageData.count > maxSize && compressionQualityFactor >= 0 {
          guard let compressedImage = UIImage(data: imageData),
            let compressedData = compressedImage.jpegData(
              compressionQuality: compressionQualityFactor)
          else {
            throw CompressorError.noData
          }

          imageData = compressedData
          compressionQualityFactor -= 0.1  // 每次降低 10%
        }
      }

      // 质量降到 0 仍超限则失败
      if imageData.count > maxSize && compressionQualityFactor <= 0 {
        throw CompressorError.noData
      }

      return imageData
    }

    /// 压缩视频
    ///
    /// 将视频转码为 MP4 格式并调整分辨率。
    ///
    /// 压缩策略：
    /// 1. 创建 AVAssetExportSession
    /// 2. 选择预设分辨率（扩展: 720p, 主应用: 1080p）
    /// 3. 导出为 MP4 格式
    /// 4. 优化网络传输
    ///
    /// 分辨率预设：
    /// - 扩展：1280x720
    /// - 主应用：1920x1080
    ///
    /// - Parameter url: 视频文件 URL
    /// - Returns: 压缩后的视频 URL，失败返回 nil
    ///
    /// - Note: 输出文件保存在临时目录
    func compressVideo(_ url: URL) async -> URL? {
      // 创建视频资源
      let urlAsset = AVURLAsset(url: url, options: nil)

      // 根据运行环境选择分辨率预设
      let presetName: String =
        if Bundle.main.bundlePath.hasSuffix(".appex") {
          AVAssetExportPreset1280x720  // 扩展使用 720p
        } else {
          AVAssetExportPreset1920x1080  // 主应用使用 1080p
        }

      // 创建导出会话
      guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: presetName)
      else {
        return nil
      }

      // 设置输出 URL（临时目录）
      let outputURL = URL.temporaryDirectory.appending(
        path: "\(UUID().uuidString).\(url.pathExtension)")
      exportSession.outputURL = outputURL
      exportSession.outputFileType = .mp4
      exportSession.shouldOptimizeForNetworkUse = true  // 优化网络传输

      // 执行导出
      do {
        try await exportSession.export(to: outputURL, as: .mp4)
        return outputURL
      } catch {
        return nil
      }
    }
  }
}
