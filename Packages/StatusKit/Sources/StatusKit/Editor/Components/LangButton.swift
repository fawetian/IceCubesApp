/*
 * LangButton.swift
 * IceCubesApp - 语言选择按钮
 *
 * 功能描述：
 * 提供帖子语言选择的按钮组件
 * 显示当前选择的语言，点击后打开语言选择面板
 *
 * 核心功能：
 * 1. 语言显示 - 显示当前选择的语言代码
 * 2. 语言选择 - 打开语言选择面板
 * 3. 自动初始化 - 根据用户偏好设置初始语言
 * 4. 视觉反馈 - 使用图标和文字表示状态
 * 5. 无障碍支持 - 完整的辅助功能标签
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @Environment - 环境依赖注入
 * 3. @State - 本地状态管理
 * 4. sheet - 模态视图
 * 5. onAppear - 视图出现时的初始化
 * 6. buttonStyle - 按钮样式
 * 7. HStack - 水平布局
 * 8. 条件渲染 - 根据语言状态显示不同内容
 * 9. 无障碍 - accessibilityLabel
 * 10. 字体样式 - footnote 字体
 *
 * 视觉设计：
 * - 左侧：文本气泡图标
 * - 右侧：语言代码（大写）或地球图标（未选择）
 * - 样式：bordered 按钮样式
 * - 字体：footnote 大小
 *
 * 初始化逻辑：
 * 1. 视图出现时自动初始化
 * 2. 优先使用最近使用的语言
 * 3. 其次使用服务器偏好设置的语言
 * 4. 如果都没有，显示地球图标
 *
 * 使用场景：
 * - 编辑器底部工具栏
 * - 创建新帖子时选择语言
 * - 编辑帖子时修改语言
 * - 回复帖子时设置语言
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 用户偏好设置
 * - Models: 数据模型
 */

import DesignSystem
import Env
import Models
import SwiftUI

extension StatusEditor {
  /// 语言选择按钮
  ///
  /// 显示当前选择的语言，点击后打开语言选择面板。
  ///
  /// 主要功能：
  /// - **语言显示**：显示当前选择的语言代码（大写）
  /// - **语言选择**：点击打开语言选择面板
  /// - **自动初始化**：根据用户偏好自动设置初始语言
  ///
  /// 使用示例：
  /// ```swift
  /// LangButton(viewModel: viewModel)
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: 视图出现时会自动初始化语言选择
  @MainActor
  struct LangButton: View {
    /// 用户偏好设置
    @Environment(UserPreferences.self) private var preferences

    /// 是否显示语言选择面板
    @State private var isLanguageSheetDisplayed: Bool = false

    /// 编辑器 ViewModel
    var viewModel: ViewModel

    var body: some View {
      Button {
        // 切换语言选择面板的显示状态
        isLanguageSheetDisplayed.toggle()
      } label: {
        HStack(alignment: .center) {
          // 文本气泡图标
          Image(systemName: "text.bubble")
          // 显示语言代码或地球图标
          if let language = viewModel.selectedLanguage {
            Text(language.uppercased())
          } else {
            Image(systemName: "globe")
          }
        }
        .font(.footnote)
      }
      .buttonStyle(.bordered)
      .onAppear {
        // 视图出现时初始化语言选择
        // 优先使用最近使用的语言，其次使用服务器偏好设置
        viewModel.setInitialLanguageSelection(
          preference: preferences.recentlyUsedLanguages.first
            ?? preferences.serverPreferences?.postLanguage)
      }
      .accessibilityLabel("accessibility.editor.button.language")
      .sheet(isPresented: $isLanguageSheetDisplayed) {
        // 语言选择面板
        LanguageSheetView(
          viewModel: viewModel,
          isPresented: $isLanguageSheetDisplayed
        )
      }
    }

  }
}
