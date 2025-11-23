// 文件功能：快速查看管理器，管理媒体附件的预览状态，为QuickLook框架提供数据支持。
// 相关技术点：
// - QuickLook框架：iOS系统的文件预览功能。
// - @Observable：SwiftUI响应式状态管理。
// - 单例模式：shared实例提供全局访问。
// - 媒体预览：处理图片、视频等媒体附件的查看。
// - @MainActor：确保UI操作在主线程执行。
// - 状态管理：selectedMediaAttachment和mediaAttachments的状态控制。
// - 数据准备：prepareFor方法设置预览数据。
// - 媒体集合：支持多个媒体附件的批量预览。
//
// 技术点详解：
// 1. QuickLook框架：系统级文件和媒体预览服务。
// 2. @Observable：新的SwiftUI状态管理机制。
// 3. MediaAttachment：Mastodon媒体附件数据模型。
// 4. 单例模式：确保全应用只有一个QuickLook实例。
// 5. @MainActor：保证状态更新的线程安全。
// 6. 可选类型：selectedMediaAttachment支持无选择状态。
// 7. 数组状态：mediaAttachments管理多个媒体项。
// 8. 状态同步：prepareFor方法同时设置选中项和列表。
// 导入Combine框架，响应式编程支持
import Combine
// 导入数据模型，MediaAttachment媒体附件
import Models
// 导入QuickLook框架，系统文件预览
import QuickLook
import SwiftUI

// 快速查看管理器，主线程安全的媒体预览状态管理
@MainActor
@Observable public class QuickLook {
  // 当前选中的媒体附件
  public var selectedMediaAttachment: MediaAttachment?
  // 媒体附件列表
  public var mediaAttachments: [MediaAttachment] = []
  
  @ObservationIgnored
  public var namespace: Namespace.ID?

  // 单例实例，全局访问快速查看服务
  public static let shared = QuickLook()

  // 私有初始化器，确保单例模式
  private init() {}

  // 为快速查看准备媒体数据
  public func prepareFor(
    selectedMediaAttachment: MediaAttachment, mediaAttachments: [MediaAttachment]
  ) {
    // 设置当前选中的媒体附件
    self.selectedMediaAttachment = selectedMediaAttachment
    // 设置媒体附件列表
    self.mediaAttachments = mediaAttachments
  }
}
