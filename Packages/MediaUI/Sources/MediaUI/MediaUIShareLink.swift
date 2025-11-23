/*
 * MediaUIShareLink.swift
 * IceCubesApp - 媒体分享链接组件
 *
 * 功能描述：
 * 定义媒体分享链接组件，根据媒体类型提供不同的分享体验（图片vs链接）
 * 为图片类型提供 Transferable 对象分享，为其他类型提供直接 URL 分享
 *
 * 技术点：
 * 1. ShareLink - iOS 16+ 的系统分享组件
 * 2. @unchecked Sendable - 并发安全标记
 * 3. 条件渲染 - 根据媒体类型选择不同的分享方式
 * 4. Transferable 协议 - 自定义数据传输格式
 * 5. SharePreview - 分享预览配置
 * 6. 本地化字符串 - 支持多语言的分享标题
 * 7. 类型区分 - 图片使用 Transferable，其他使用 URL
 * 8. 组件化设计 - 封装分享逻辑为可复用组件
 * 9. 枚举比较 - 使用 == 操作符进行类型匹配
 * 10. 视图协议 - 实现 SwiftUI View 协议
 *
 * 技术点详解：
 * - ShareLink：iOS 16+ 引入的系统级分享功能组件
 * - @unchecked Sendable：手动标记并发安全性，绕过编译器检查
 * - 条件渲染：if-else 控制不同的视图渲染路径
 * - Transferable：定义如何在应用间传输数据的现代协议
 * - SharePreview：自定义分享时的预览显示内容和图标
 * - 本地化：多语言支持的字符串资源管理
 * - 类型匹配：使用 == 操作符比较枚举值
 * - 组件化：将复杂功能封装为简单易用的组件
 * - URL vs Transferable：不同数据类型的分享策略选择
 * - View 协议：SwiftUI 视图系统的基础协议
 */

// 导入 SwiftUI 框架，提供 ShareLink 等组件
import SwiftUI

// 媒体分享链接组件，根据媒体类型提供适配的分享体验
public struct MediaUIShareLink: View, @unchecked Sendable {
  // 媒体的 URL 地址
  let url: URL
  // 媒体的显示类型
  let type: DisplayType

  // 初始化分享链接组件
  public init(url: URL, type: DisplayType) {
    self.url = url
    self.type = type
  }

  // 视图主体，根据媒体类型渲染不同的分享方式
  public var body: some View {
    // 判断是否为图片类型
    if type == .image {
      // 为图片创建可传输对象
      let transferable = MediaUIImageTransferable(url: url)
      // 使用图片预览的分享链接
      ShareLink(
        item: transferable,
        preview: .init(
          "status.media.contextmenu.share",
          image: transferable))
    } else {
      // 非图片类型直接分享 URL
      ShareLink(item: url)
    }
  }
}
