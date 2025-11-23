/*
 * EmojiText.swift
 * IceCubesApp - 表情文本视图组件
 *
 * 功能描述：
 * 提供一个支持自定义表情符号渲染的文本视图组件，将 HTML 标记转换为 SwiftUI Text
 * 集成第三方 EmojiText 库，支持 Mastodon 自定义表情的显示和多语言文本方向处理
 *
 * 技术点：
 * 1. EmojiText 库集成 - 第三方表情文本渲染库
 * 2. CustomEmoji 协议 - 自定义表情符号协议
 * 3. HTMLString 处理 - HTML 到 Markdown 的转换
 * 4. 多语言支持 - RTL（从右到左）文本方向检测
 * 5. @Sendable 闭包 - 并发安全的文本追加功能
 * 6. 条件渲染 - 根据表情数量选择不同渲染方式
 * 7. Environment 系统 - layoutDirection 环境值设置
 * 8. @MainActor 并发 - 确保 UI 更新在主线程
 * 9. RemoteEmoji 适配器 - Emoji 到 CustomEmoji 的转换
 *
 * 技术点详解：
 * - EmojiText 库：第三方库，用于在 SwiftUI 中渲染包含自定义表情符号的文本
 * - CustomEmoji 协议：定义自定义表情符号的接口，包含短代码和 URL
 * - HTMLString 处理：将 Mastodon API 返回的 HTML 内容转换为可显示的 Markdown
 * - 多语言支持：检测阿拉伯语、希伯来语等 RTL 语言，设置正确的文本方向
 * - @Sendable 闭包：确保传递的文本追加闭包在并发环境中安全使用
 * - 条件渲染：当没有自定义表情时使用系统 Text，有表情时使用 EmojiText
 * - Environment 系统：通过环境值设置文本布局方向，影响子视图的渲染
 * - @MainActor 并发：确保所有 UI 相关操作都在主线程执行
 * - RemoteEmoji 适配器：将 Emoji 模型转换为 EmojiText 库所需的格式
 */

// 导入 EmojiText 第三方库，提供自定义表情文本渲染功能
import EmojiText
// 导入 Foundation 框架，提供基础数据类型和字符串处理
import Foundation
// 导入 Models 模块，提供数据模型定义
import Models
// 导入 SwiftUI 框架，提供视图构建功能
import SwiftUI

// 使用 @MainActor 确保表情文本视图在主线程上运行
@MainActor
// 定义公共的表情文本应用视图，用于渲染包含自定义表情的文本
public struct EmojiTextApp: View {
  // 存储 HTML 格式的文本内容
  private let markdown: HTMLString
  // 存储自定义表情符号数组
  private let emojis: [any CustomEmoji]
  // 存储文本语言代码，用于确定文本方向
  private let language: String?
  // 存储可选的文本追加闭包，用于在文本末尾添加额外内容
  private let append: (@Sendable () -> Text)?
  // 存储行数限制，用于控制文本显示的最大行数
  private let lineLimit: Int?

  // 公共初始化方法，创建表情文本视图实例
  public init(
    _ markdown: HTMLString, emojis: [Emoji], language: String? = nil, lineLimit: Int? = nil,
    append: (@Sendable () -> Text)? = nil
  ) {
    // 设置 HTML 文本内容
    self.markdown = markdown
    // 将 Emoji 模型转换为 CustomEmoji 协议类型
    self.emojis = emojis.map { RemoteEmoji(shortcode: $0.shortcode, url: $0.url) }
    // 设置语言代码
    self.language = language
    // 设置行数限制
    self.lineLimit = lineLimit
    // 设置文本追加闭包
    self.append = append
  }

  // 视图主体，定义表情文本的 UI 结构
  public var body: some View {
    // 检查是否有文本追加闭包
    if let append {
      // 有追加内容时，使用 EmojiText 并追加文本
      EmojiText(markdown: markdown.asMarkdown, emojis: emojis)
        // 追加额外的文本内容
        .append(text: append)
        // 设置行数限制
        .lineLimit(lineLimit)
    } else if emojis.isEmpty {
      // 没有自定义表情时，使用系统 Text 组件
      Text(markdown.asSafeMarkdownAttributedString)
        // 设置行数限制
        .lineLimit(lineLimit)
        // 设置文本布局方向
        .environment(\.layoutDirection, isRTL() ? .rightToLeft : .leftToRight)
    } else {
      // 有自定义表情时，使用 EmojiText 组件
      EmojiText(markdown: markdown.asMarkdown, emojis: emojis)
        // 设置行数限制
        .lineLimit(lineLimit)
        // 设置文本布局方向
        .environment(\.layoutDirection, isRTL() ? .rightToLeft : .leftToRight)
    }
  }

  // 私有方法：检测是否为从右到左（RTL）语言
  private func isRTL() -> Bool {
    // 检查语言代码是否为 RTL 语言：阿拉伯语、希伯来语、波斯语、乌尔都语、库尔德语、阿塞拜疆语、迪维希语
    ["ar", "he", "fa", "ur", "ku", "az", "dv"].contains(language)
  }
}
