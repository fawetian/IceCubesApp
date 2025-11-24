/*
 * RecentTagsView.swift
 * IceCubesApp - 最近标签视图
 *
 * 功能描述：
 * 显示最近使用的标签建议
 * 在自动完成中提供快速访问常用标签
 *
 * 核心功能：
 * 1. 最近标签 - 显示最近使用的标签列表
 * 2. 使用时间 - 显示标签最后使用时间
 * 3. 快速选择 - 点击标签快速插入
 * 4. 时间更新 - 自动更新标签使用时间
 * 5. 自动收起 - 选择后自动收起展开视图
 *
 * 视图层次：
 * - ForEach（标签列表）
 *   - Button（标签按钮）
 *     - VStack
 *       - Text（标签名称）
 *       - Text（最后使用时间）
 *
 * 技术点：
 * 1. @Environment - 主题环境注入
 * 2. @Binding - 双向绑定展开状态
 * 3. @Query - SwiftData 查询最近标签
 * 4. withAnimation - 动画效果
 *
 * 使用场景：
 * - 用户输入 # 符号
 * - 显示最近使用的标签
 * - 快速重用常用标签
 *
 * 依赖关系：
 * - DesignSystem: 主题
 * - Models: 标签模型
 * - SwiftData: 数据持久化
 */

import DesignSystem
import EmojiText
import Foundation
import Models
import SwiftData
import SwiftUI

extension StatusEditor.AutoCompleteView {
  /// 最近标签视图
  ///
  /// 显示最近使用的标签建议。
  ///
  /// 主要功能：
  /// - **最近标签**：显示最近使用的标签列表
  /// - **使用时间**：显示标签最后使用时间
  /// - **快速选择**：点击标签快速插入
  /// - **时间更新**：自动更新标签使用时间
  ///
  /// 使用示例：
  /// ```swift
  /// RecentTagsView(
  ///   viewModel: viewModel,
  ///   isTagSuggestionExpanded: $isExpanded
  /// )
  /// ```
  ///
  /// - Note: 标签按最后使用时间倒序排列
  struct RecentTagsView: View {
    /// 主题环境
    @Environment(Theme.self) private var theme

    /// 编辑器 ViewModel
    var viewModel: StatusEditor.ViewModel

    /// 展开状态绑定
    @Binding var isTagSuggestionExpanded: Bool

    /// 最近使用的标签查询
    ///
    /// 按最后使用时间倒序排列。
    @Query(sort: \RecentTag.lastUse, order: .reverse) var recentTags: [RecentTag]

    var body: some View {
      // 遍历最近使用的标签
      ForEach(recentTags) { tag in
        Button {
          withAnimation {
            // 收起展开视图
            isTagSuggestionExpanded = false
            // 插入标签到编辑器
            viewModel.selectHashtagSuggestion(tag: tag.title)
          }
          // 更新标签使用时间
          tag.lastUse = Date()
        } label: {
          VStack(alignment: .leading) {
            // 标签名称
            Text("#\(tag.title)")
              .font(.scaledFootnote)
              .fontWeight(.bold)
              .foregroundColor(theme.labelColor)

            // 最后使用时间（格式化显示）
            Text(tag.formattedDate)
              .font(.scaledFootnote)
              .foregroundStyle(theme.tintColor)
          }
        }
      }
    }
  }
}
