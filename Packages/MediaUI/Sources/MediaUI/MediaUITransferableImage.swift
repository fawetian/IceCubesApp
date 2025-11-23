/*
 * MediaUITransferableImage.swift
 * IceCubesApp - 可传输媒体图片
 *
 * 功能描述：
 * 定义可传输的媒体图片结构，实现 CoreTransferable 协议，支持在系统分享和拖拽操作中传输图片数据
 * 提供异步数据获取和 JPEG 格式导出功能，集成现代数据传输框架
 *
 * 技术点：
 * 1. CoreTransferable 协议 - iOS 16+ 的现代数据传输协议
 * 2. Transferable 协议 - 支持拖拽和分享的数据传输
 * 3. Codable 协议 - 支持数据的编码和解码
 * 4. URLSession 网络请求 - 异步下载图片数据
 * 5. 错误处理 - do-catch 异常处理机制
 * 6. async/await 异步编程 - 非阻塞的数据获取
 * 7. DataRepresentation - 定义数据的传输表示形式
 * 8. UTType 统一类型标识符 - 指定数据的内容类型
 * 9. 泛型传输表示 - some TransferRepresentation 语法
 * 10. 数据类型转换 - 将 URL 数据转换为 JPEG 格式
 *
 * 技术点详解：
 * - CoreTransferable：iOS 16 引入的现代数据传输框架，替代旧的剪贴板和拖拽 API
 * - Transferable：标准协议，让类型可以参与系统级的数据传输操作
 * - Codable：使结构体可以序列化，便于存储和传输
 * - URLSession：使用系统网络库异步下载远程图片数据
 * - 错误处理：使用 do-catch 捕获网络异常，返回空数据作为备选
 * - async/await：避免阻塞主线程，提供流畅的用户体验
 * - DataRepresentation：定义数据在传输时的具体格式和获取方式
 * - UTType：使用统一类型标识符系统指定 JPEG 图片格式
 * - 泛型语法：使用 some 关键字简化复杂的泛型类型声明
 * - 格式转换：将网络图片数据统一导出为 JPEG 格式
 */

// 导入 CoreTransferable 框架，提供现代数据传输功能
import CoreTransferable
// 导入 SwiftUI 框架，提供基础类型支持
import SwiftUI
// 导入 UIKit 框架，提供图片相关功能
import UIKit

// 可传输的媒体图片结构，支持系统级数据传输
public struct MediaUIImageTransferable: Codable, Transferable {
  // 图片的源 URL
  public let url: URL

  // 公共初始化器
  public init(url: URL) {
    self.url = url
  }

  // 异步获取图片数据
  public func fetchData() async -> Data {
    do {
      // 尝试从网络下载图片数据
      return try await URLSession.shared.data(from: url).0
    } catch {
      // 如果下载失败，返回空数据
      return Data()
    }
  }

  // 定义传输表示形式，指定如何在系统间传输数据
  public static var transferRepresentation: some TransferRepresentation {
    // 使用数据表示形式，导出为 JPEG 格式
    DataRepresentation(exportedContentType: .jpeg) { transferable in
      // 异步获取可传输对象的数据
      await transferable.fetchData()
    }
  }
}
