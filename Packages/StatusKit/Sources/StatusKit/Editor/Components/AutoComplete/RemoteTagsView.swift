/*
 * RemoteTagsView.swift
 * IceCubesApp - 远程标签视图
 *
 * 功能描述：
 * 显示从服务器获取的标签建议
 * 根据用户输入实时搜索匹配的标签
 *
 * 核心功能：
 * 1. 远程搜索 - 从服务器搜索匹配的标签
 * 2. 使用统计 - 显示标签的使用次数
 * 3. 快速选择 - 点击标签快速插入
 * 4. 自动记录 - 记录到最近使用列表
 * 5. 时间更新 - 更新已存在标签的使用时间
 *
 * 视图层次：
 * - ForEach（标签列表）
 *   - Button（标签按钮）
 *     - VStack
 *       - Text（标签名称）
 *       - Text（使用次数）
 *
 * 技术点：
 * 1. @Environment - 环境对象注入
 * 2. @Binding - 双向绑定展开状态
 * 3. @Query - SwiftData 查询最近标签
 * 4. withAnimation - 动画效果
 * 5. SwiftData - 数据插入和更新
 *
 * 使用场景：
 * - 用户输入 # 符号后继续输入
 * - 显示服务器上匹配的标签
 * - 发现新的热门标签
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
  /// 远程标签视图
  ///
  /// 显示从服务器获取的标签建议。
  ///
  /// 主要功能：
  /// - **远程搜索**：从服务器搜索匹配的标签
  /// - **使用统计**：显示标签的使用次数
  /// - **快速选择**：点击标签快速插入
  /// - **自动记录**：记录到最近使用列表
  ///
  /// 使用示例：
  /// ```swift
  /// RemoteTagsView(
  ///   viewModel: viewModel,
  ///   isTagSuggestionExpanded: $isExpanded
  /// )
  /// ```
  ///
  /// - Note: 标签来自服务器实时搜索结果
  struct RemoteTagsView: View {
    /// 模型上下文（SwiftData）
    @Environment(\.modelContext) private var context

    /// 主题环境
    @Environment(Theme.self) private var theme

    /// 编辑器 ViewModel
    var viewModel: StatusEditor.ViewModel

    /// 展开状态绑定
    @Binding var isTagSuggestionExpanded: Bool

    /// 最近使用的标签查询
    ///
    /// 用于检查标签是否已在最近使用列表中。
    @Query(sort: \RecentTag.lastUse, order: .reverse) var recentTags: [RecentTag]

    var body: some View {
      // 遍历远程标签建议
      ForEach(viewModel.tagsSuggestions) { tag in
        Button {
          withAnimation {
            // 收起展开视图
            isTagSuggestionExpanded = false
            // 插入标签到编辑器
            viewModel.selectHashtagSuggestion(tag: tag.name)
          }

          // 检查标签是否已在最近使用列表中
          if let index = recentTags.firstIndex(where: {
            $0.title.lowercased() == tag.name.lowercased()
          }) {
            // 更新已存在标签的使用时间
            recentTags[index].lastUse = Date()
          } else {
            // 添加新标签到最近使用列表
            context.insert(RecentTag(title: tag.name))
          }
        } label: {
          VStack(alignment: .leading) {
            // 标签名称
            Text("#\(tag.name)")
              .font(.scaledFootnote)
              .fontWeight(.bold)
              .foregroundColor(theme.labelColor)

            // 标签使用次数统计
            Text("tag.suggested.mentions-\(tag.totalUses)")
              .font(.scaledFootnote)
              .foregroundStyle(theme.tintColor)
          }
        }
      }
    }
  }
}
