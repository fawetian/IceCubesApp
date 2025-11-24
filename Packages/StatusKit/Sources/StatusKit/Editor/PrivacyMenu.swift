/*
 * PrivacyMenu.swift
 * IceCubesApp - 隐私菜单组件
 *
 * 功能描述：
 * 提供帖子可见性（隐私级别）选择菜单
 * 用户可以选择帖子的可见范围：公开、不列出、仅关注者、私信等
 *
 * 核心功能：
 * 1. 可见性选择 - 显示所有可用的可见性选项
 * 2. 视觉反馈 - 使用图标和颜色表示当前选择
 * 3. iOS 26 适配 - 支持新的 Liquid Glass 效果
 * 4. 无障碍支持 - 完整的辅助功能标签和提示
 * 5. 动态样式 - 根据系统版本应用不同的视觉效果
 *
 * 技术点：
 * 1. @Binding - 双向数据绑定，同步可见性状态
 * 2. Menu - SwiftUI 菜单组件
 * 3. ForEach - 遍历所有可见性选项
 * 4. 条件编译 - iOS 26+ 使用 glassEffect
 * 5. Label - 图标和文本组合
 * 6. 无障碍 - accessibilityLabel/Value/Hint
 * 7. 视觉样式 - overlay 和 glassEffect
 * 8. 颜色主题 - 使用 tint 颜色
 * 9. 圆角矩形 - RoundedRectangle 边框
 * 10. 字体缩放 - scaledFootnote 自适应字体
 *
 * 可见性选项（Models.Visibility）：
 * - public: 公开 - 所有人可见，显示在公共时间线
 * - unlisted: 不列出 - 所有人可见，但不显示在公共时间线
 * - private: 仅关注者 - 只有关注者可见
 * - direct: 私信 - 只有提及的用户可见
 *
 * 视觉设计：
 * - iOS 26+: 使用 Liquid Glass 效果，现代化外观
 * - iOS 25-: 使用圆角矩形边框，经典外观
 * - 图标: 每个可见性级别有对应的 SF Symbol
 * - 颜色: 使用 tint 颜色突出显示
 *
 * 使用场景：
 * - 创建新帖子时选择可见性
 * - 编辑帖子时修改可见性
 * - 回复帖子时设置可见性
 * - 帖子串中每条帖子的可见性设置
 *
 * 用户体验：
 * - 点击显示下拉菜单
 * - 当前选择高亮显示
 * - 每个选项有标题和说明
 * - 图标直观表示可见性级别
 * - 无障碍用户可以听到完整描述
 *
 * 依赖关系：
 * - Models: Visibility 枚举定义
 * - SwiftUI: UI 框架
 */

import Models
import SwiftUI

extension StatusEditor {
  /// 隐私菜单视图
  ///
  /// 提供帖子可见性选择的下拉菜单。
  ///
  /// 主要功能：
  /// - **可见性选择**：显示所有可用的可见性选项
  /// - **视觉反馈**：当前选择的可见性用图标和文字显示
  /// - **iOS 26 适配**：在支持的系统上使用 Liquid Glass 效果
  /// - **无障碍支持**：完整的辅助功能标签和提示
  ///
  /// 使用示例：
  /// ```swift
  /// PrivacyMenu(
  ///     visibility: $viewModel.visibility,
  ///     tint: theme.tintColor
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - visibility: 绑定的可见性状态，双向同步
  ///   - tint: 主题色，用于边框和强调
  ///
  /// - Note: iOS 26+ 使用 glassEffect，旧版本使用圆角矩形边框
  /// - Important: 可见性变化会立即反映到绑定的 ViewModel
  struct PrivacyMenu: View {
    /// 绑定的可见性状态
    @Binding var visibility: Models.Visibility
    /// 主题色，用于视觉强调
    let tint: Color

    var body: some View {
      // 下拉菜单，显示所有可见性选项
      Menu {
        // 遍历所有可见性选项
        ForEach(Models.Visibility.allCases, id: \.self) { vis in
          Button {
            // 更新选中的可见性
            visibility = vis
          } label: {
            // 显示图标和标题
            Label(vis.title, systemImage: vis.iconName)
            // 显示说明文字
            Text(vis.subtitle)
          }
        }
      } label: {
        // iOS 26+ 使用 Liquid Glass 效果
        if #available(iOS 26.0, *) {
          makeMenuLabel(visibility: visibility)
            .padding(8)
            .glassEffect()
        } else {
          // 旧版本使用圆角矩形边框
          makeMenuLabel(visibility: visibility)
            .padding(4)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(tint, lineWidth: 1)
            )
        }
      }
    }

    /// 创建菜单标签视图
    ///
    /// 显示当前选中的可见性，包括图标、标题和下拉箭头。
    ///
    /// - Parameter visibility: 当前的可见性级别
    /// - Returns: 菜单标签视图
    private func makeMenuLabel(visibility: Models.Visibility) -> some View {
      HStack {
        // 显示可见性图标和标题
        Label(visibility.title, systemImage: visibility.iconName)
          .accessibilityLabel("accessibility.editor.privacy.label")
          .accessibilityValue(visibility.title)
          .accessibilityHint("accessibility.editor.privacy.hint")
        // 下拉箭头
        Image(systemName: "chevron.down")
      }
      .font(.scaledFootnote)
    }
  }
}
