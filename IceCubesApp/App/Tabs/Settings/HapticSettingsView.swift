// 文件功能：触觉反馈设置页面，用户可开启/关闭不同场景的震动反馈。
// 相关技术点：
// - SwiftUI 表单与分区：Form、Section 组织界面。
// - @Environment/@Bindable：环境注入与双向绑定。
// - Toggle：开关控件，控制触觉反馈开关。
// - 条件编译：适配 visionOS。
//
// 技术点详解：
// 1. 触觉反馈：iOS 设备的震动反馈，提升用户体验。
// 2. @Bindable：Swift 数据绑定，支持双向绑定可观察对象属性。
// 3. Toggle：SwiftUI 开关控件，用于布尔值设置。
// 4. @MainActor：确保 UI 更新在主线程执行。
// 5. 用户偏好：持久化用户设置，跨应用启动保持状态。
// 6. 条件编译：visionOS 不支持触觉反馈，需要适配。
import DesignSystem
// 导入设计系统，包含主题、控件等
import Env
// 导入环境依赖模块
import Models
// 导入数据模型
import StatusKit
// 导入状态相关 UI 组件
import SwiftUI

// 导入 SwiftUI 框架

// 主线程下定义触觉反馈设置视图
@MainActor
struct HapticSettingsView: View {
  // 注入主题
  @Environment(Theme.self) private var theme
  // 注入用户偏好设置
  @Environment(UserPreferences.self) private var userPreferences

  // 主体视图
  var body: some View {
    // 创建可绑定的用户偏好对象
    @Bindable var userPreferences = userPreferences
    Form {
      Section {
        // 时间线滚动触觉反馈开关
        Toggle("settings.haptic.timeline", isOn: $userPreferences.hapticTimelineEnabled)
        // 标签页切换触觉反馈开关
        Toggle("settings.haptic.tab-selection", isOn: $userPreferences.hapticTabSelectionEnabled)
        // 按钮点击触觉反馈开关
        Toggle("settings.haptic.buttons", isOn: $userPreferences.hapticButtonPressEnabled)
      }
      #if !os(visionOS)
        // 设置分区背景色为主题主背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    // 设置导航标题
    .navigationTitle("settings.haptic.navigation-title")
    #if !os(visionOS)
      // 隐藏表单默认背景
      .scrollContentBackground(.hidden)
      // 设置整体背景色为主题次背景色
      .background(theme.secondaryBackgroundColor)
    #endif
  }
}
