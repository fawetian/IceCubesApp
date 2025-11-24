/*
 * CustomEmojisView.swift
 * IceCubesApp - 自定义表情视图
 *
 * 功能描述：
 * 显示实例的自定义表情列表，用户可以选择并插入到帖子中
 * 支持分类显示、延迟加载和无障碍功能
 *
 * 核心功能：
 * 1. 表情显示 - 网格布局显示所有自定义表情
 * 2. 分类展示 - 按类别组织表情
 * 3. 延迟加载 - 使用 LazyImage 延迟加载表情图片
 * 4. 点击插入 - 点击表情插入到编辑器
 * 5. 无障碍支持 - 完整的辅助功能标签
 * 6. 导航栏 - 标题和取消按钮
 * 7. 展示模式 - 支持中等和大尺寸
 * 8. 加载状态 - 显示加载占位符
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @Environment - 环境依赖注入
 * 3. NavigationStack - 导航容器
 * 4. ScrollView - 滚动容器
 * 5. LazyVGrid - 延迟加载网格布局
 * 6. LazyImage - 延迟加载图片（Nuke）
 * 7. Section - 分组显示
 * 8. ForEach - 遍历数据
 * 9. presentationDetents - 展示尺寸
 * 10. 无障碍 - accessibilityLabel/Traits
 *
 * 视图层次：
 * - NavigationStack
 *   - ScrollView
 *     - LazyVGrid（网格布局）
 *       - ForEach（遍历分类）
 *         - Section（分类区域）
 *           - ForEach（遍历表情）
 *             - LazyImage（表情图片）
 *
 * 布局设计：
 * - 网格列数：自适应，每列 40pt
 * - 间距：9pt
 * - 表情大小：40x40pt
 * - 分类标题：左对齐，加粗
 *
 * 使用场景：
 * - 编辑器中点击表情按钮
 * - 选择自定义表情插入到帖子
 * - 浏览实例的自定义表情
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 环境对象
 * - Models: 数据模型
 * - NukeUI: 图片加载库
 */

import DesignSystem
import Env
import Models
import NukeUI
import SwiftUI

extension StatusEditor {
  /// 自定义表情视图
  ///
  /// 显示实例的自定义表情列表。
  ///
  /// 主要功能：
  /// - **表情显示**：网格布局显示所有自定义表情
  /// - **分类展示**：按类别组织表情
  /// - **点击插入**：点击表情插入到编辑器
  /// - **无障碍支持**：完整的辅助功能标签
  ///
  /// 使用示例：
  /// ```swift
  /// CustomEmojisView(viewModel: viewModel)
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: 使用 LazyImage 延迟加载表情图片以优化性能
  @MainActor
  struct CustomEmojisView: View {
    /// 关闭视图的环境变量
    @Environment(\.dismiss) private var dismiss

    /// 主题设置
    @Environment(Theme.self) private var theme

    /// 编辑器 ViewModel
    var viewModel: ViewModel

    var body: some View {
      NavigationStack {
        ScrollView {
          // 自适应网格布局，每列 40pt
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 40, maximum: 40))], spacing: 9) {
            // 遍历所有表情分类
            ForEach(viewModel.customEmojiContainer) { container in
              Section {
                // 遍历分类中的所有表情
                ForEach(container.emojis) { emoji in
                  // 延迟加载表情图片
                  LazyImage(url: emoji.url) { state in
                    if let image = state.image {
                      // 显示表情图片
                      image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .accessibilityLabel(
                          emoji.shortcode.replacingOccurrences(of: "_", with: " ")
                        )
                        .accessibilityAddTraits(.isButton)
                    } else if state.isLoading {
                      // 显示加载占位符
                      Rectangle()
                        .fill(Color.gray)
                        .frame(width: 40, height: 40)
                        .accessibility(hidden: true)
                    }
                  }
                  .onTapGesture {
                    // 点击表情插入到编辑器
                    viewModel.insertStatusText(text: " :\(emoji.shortcode): ")
                  }
                }
                .padding(.horizontal, 16)
              } header: {
                // 分类标题
                Text(container.categoryName)
                  .font(.scaledHeadline)
                  .bold()
                  .foregroundStyle(Color.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 16)
              }
            }
          }
        }
        .toolbar {
          // 取消按钮
          CancelToolbarItem()
        }
        .navigationTitle("status.editor.emojis.navigation-title")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.medium, .large])
    }
  }
}
