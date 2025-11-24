/*
 * CategorizedEmojiContainer.swift
 * IceCubesApp - 分类表情容器
 *
 * 功能描述：
 * 用于组织和管理自定义表情的分类容器
 * 将表情按类别分组，便于在表情选择器中展示
 *
 * 核心功能：
 * 1. 表情分类 - 按类别名称组织表情
 * 2. 唯一标识 - 每个容器有唯一 ID
 * 3. 可识别 - 实现 Identifiable 协议
 * 4. 可比较 - 实现 Equatable 协议
 *
 * 数据结构：
 * - id: 唯一标识符（UUID 字符串）
 * - categoryName: 类别名称（如"动物"、"食物"等）
 * - emojis: 该类别下的表情数组
 *
 * 使用场景：
 * - 在表情选择器中按类别展示表情
 * - 组织服务器的自定义表情
 * - 提供分类浏览功能
 *
 * 技术点：
 * 1. Identifiable - 提供唯一标识
 * 2. Equatable - 支持相等性比较
 * 3. UUID - 生成唯一 ID
 * 4. struct - 值类型，线程安全
 *
 * 依赖关系：
 * - Models: 表情模型
 */

import Foundation
import Models

extension StatusEditor {
  /// 分类表情容器
  ///
  /// 用于组织和管理自定义表情的分类容器。
  /// 将表情按类别分组，便于在表情选择器中展示。
  ///
  /// 使用示例：
  /// ```swift
  /// let container = CategorizedEmojiContainer(
  ///   categoryName: "Animals",
  ///   emojis: [emoji1, emoji2, emoji3]
  /// )
  /// ```
  ///
  /// - Note: 每个容器自动生成唯一 ID
  struct CategorizedEmojiContainer: Identifiable, Equatable {
    /// 唯一标识符
    ///
    /// 自动生成的 UUID 字符串，用于在列表中识别容器。
    let id = UUID().uuidString

    /// 类别名称
    ///
    /// 表情类别的名称，如"动物"、"食物"、"活动"等。
    let categoryName: String

    /// 表情数组
    ///
    /// 该类别下的所有自定义表情。
    var emojis: [Emoji]
  }
}
