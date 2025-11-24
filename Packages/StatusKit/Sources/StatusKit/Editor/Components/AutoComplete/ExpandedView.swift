/*
 * ExpandedView.swift
 * IceCubesApp - 展开标签建议视图
 *
 * 功能描述：
 * 显示完整的标签建议列表
 * 包括最近使用的标签和关注的标签
 *
 * 核心功能：
 * 1. 最近标签 - 显示最近使用的标签
 * 2. 关注标签 - 显示用户关注的标签
 * 3. 分页浏览 - 使用 TabView 切换页面
 * 4. 快速选择 - 点击标签快速插入
 * 5. 自动记录 - 更新标签使用时间
 * 6. 垂直滚动 - 支持长列表滚动
 *
 * 视图层次：
 * - TabView（分页）
 *   - 最近标签页
 *     - 标签列表（按使用时间排序）
 *   - 关注标签页
 *     - 标签列表（用户关注的标签）
 *
 * 技术点：
 * 1. @MainActor - 主线程操作
 * 2. @Environment - 环境对象注入
 * 3. @Binding - 双向绑定展开状态
 * 4. @Query - SwiftData 查询
 * 5. TabView - 分页视图
 * 6. LazyVStack - 延迟加载垂直堆栈
 * 7. ScrollView - 滚动视图
 *
 * 使用场景：
 * - 用户点击展开按钮
 * - 浏览更多标签建议
 * - 快速选择常用标签
 * - 查看关注的标签
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 当前账户
 * - Models: 数据模型
 * - SwiftData: 数据持久化
 */

import DesignSystem
import EmojiText
import Env
import Foundation
import Models
import SwiftData
import SwiftUI

extension StatusEditor.AutoCompleteView {
  /// 展开标签建议视图
  ///
  /// 显示完整的标签建议列表。
  ///
  /// 主要功能：
  /// - **最近标签**：显示最近使用的标签
  /// - **关注标签**：显示用户关注的标签
  /// - **分页浏览**：使用 TabView 切换页面
  /// - **快速选择**：点击标签快速插入
  ///
  /// 使用示例：
  /// ```swift
  /// ExpandedView(
  ///   viewModel: viewModel,
  ///   isTagSuggestionExpanded: $isExpanded
  /// )
  /// ```
  ///
  /// - Note: 高度固定为 200 点
  @MainActor
  struct ExpandedView: View {
    /// 模型上下文（SwiftData）
    @Environment(\.modelContext) private var context

    /// 主题环境
    @Environment(Theme.self) private var theme

    /// 当前账户环境
    @Environment(CurrentAccount.self) private var currentAccount

    /// 编辑器 ViewModel
    var viewModel: StatusEditor.ViewModel

    /// 展开状态绑定
    @Binding var isTagSuggestionExpanded: Bool

    /// 最近使用的标签查询
    ///
    /// 按最后使用时间倒序排列。
    @Query(sort: \RecentTag.lastUse, order: .reverse) var recentTags: [RecentTag]

    var body: some View {
      // 分页视图（最近标签 + 关注标签）
      TabView {
        recentTagsPage
        followedTagsPage
      }
      .tabViewStyle(.page(indexDisplayMode: .always))
      .frame(height: 200)
    }

    /// 最近标签页
    ///
    /// 显示最近使用的标签列表。
    ///
    /// 功能：
    /// - 显示标签名称和最后使用时间
    /// - 点击标签插入到编辑器
    /// - 自动更新使用时间
    /// - 自动收起展开视图
    private var recentTagsPage: some View {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 12) {
          // 标题
          Text("status.editor.language-select.recently-used")
            .font(.scaledSubheadline)
            .foregroundStyle(theme.labelColor)
            .fontWeight(.bold)

          // 最近标签列表
          ForEach(recentTags) { tag in
            HStack {
              Button {
                // 更新使用时间
                tag.lastUse = Date()
                withAnimation {
                  // 收起展开视图
                  isTagSuggestionExpanded = false
                  // 插入标签到编辑器
                  viewModel.selectHashtagSuggestion(tag: tag.title)
                }
              } label: {
                VStack(alignment: .leading) {
                  // 标签名称
                  Text("#\(tag.title)")
                    .font(.scaledFootnote)
                    .fontWeight(.bold)
                    .foregroundColor(theme.labelColor)
                  // 最后使用时间
                  Text(tag.formattedDate)
                    .font(.scaledFootnote)
                    .foregroundStyle(theme.tintColor)
                }
              }
              Spacer()
            }
          }
        }
        .padding(.horizontal, .layoutPadding)
      }
    }

    /// 关注标签页
    ///
    /// 显示用户关注的标签列表。
    ///
    /// 功能：
    /// - 显示关注的标签
    /// - 点击标签插入到编辑器
    /// - 自动记录到最近使用
    /// - 自动收起展开视图
    private var followedTagsPage: some View {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 12) {
          // 标题
          Text("timeline.filter.tags")
            .font(.scaledSubheadline)
            .foregroundStyle(theme.labelColor)
            .fontWeight(.bold)

          // 关注标签列表
          ForEach(currentAccount.tags) { tag in
            HStack {
              Button {
                // 检查是否已在最近使用中
                if let index = recentTags.firstIndex(where: {
                  $0.title.lowercased() == tag.name.lowercased()
                }) {
                  // 更新使用时间
                  recentTags[index].lastUse = Date()
                } else {
                  // 添加到最近使用
                  context.insert(RecentTag(title: tag.name))
                }
                withAnimation {
                  // 收起展开视图
                  isTagSuggestionExpanded = false
                  // 插入标签到编辑器
                  viewModel.selectHashtagSuggestion(tag: tag.name)
                }
              } label: {
                VStack(alignment: .leading) {
                  // 标签名称
                  Text("#\(tag.name)")
                    .font(.scaledFootnote)
                    .fontWeight(.bold)
                    .foregroundColor(theme.labelColor)
                }
              }
              Spacer()
            }
          }
        }
        .padding(.horizontal, .layoutPadding)
      }
    }
  }
}
