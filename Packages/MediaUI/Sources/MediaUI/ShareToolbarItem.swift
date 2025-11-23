/*
 * ShareToolbarItem.swift
 * IceCubesApp - 分享工具栏项组件
 *
 * 功能描述：
 * 定义分享工具栏项组件，为媒体查看器提供分享功能，封装媒体分享链接组件
 * 支持在工具栏中显示分享按钮，提供统一的分享操作体验
 *
 * 技术点：
 * 1. ToolbarContent 协议 - SwiftUI 工具栏内容定义
 * 2. @unchecked Sendable - 并发安全标记
 * 3. 组件封装 - 将复杂的分享功能封装为简单的工具栏项
 * 4. 类型传递 - 传递媒体类型信息给子组件
 * 5. URL 处理 - 处理媒体文件的 URL
 * 6. 工具栏布局 - 控制按钮在工具栏中的位置
 * 7. 组件组合 - 使用其他组件构建工具栏项
 * 8. 简单结构体 - 轻量级的包装组件
 * 9. 属性传递 - 将外部属性传递给内部组件
 * 10. UI 层次结构 - 构建清晰的视图层次
 *
 * 技术点详解：
 * - ToolbarContent 协议：定义可在 SwiftUI 工具栏中显示的内容类型
 * - @unchecked Sendable：标记为并发安全，允许在不同 actor 间传递
 * - 组件封装：将 MediaUIShareLink 包装为工具栏项，简化使用
 * - 类型传递：保持媒体类型信息的传递链
 * - URL 处理：确保媒体文件 URL 的正确传递
 * - 工具栏布局：使用 topBarTrailing 位置放置分享按钮
 * - 组件组合：通过组合现有组件实现新功能
 * - 简单结构体：保持组件的轻量级和高性能
 * - 属性传递：确保所需数据在组件间正确流动
 * - UI 层次：维护清晰的视图组织结构
 */

// 导入 SwiftUI 框架，提供工具栏和视图组件
import SwiftUI

// 分享工具栏项组件，封装媒体分享功能
struct ShareToolbarItem: ToolbarContent, @unchecked Sendable {
  // 要分享的媒体文件 URL
  let url: URL
  // 媒体显示类型（图片、视频等）
  let type: DisplayType

  // 工具栏内容主体
  var body: some ToolbarContent {
    // 在工具栏尾部放置分享组件
    ToolbarItem(placement: .topBarTrailing) {
      // 使用媒体分享链接组件
      MediaUIShareLink(url: url, type: type)
    }
  }
}
