// 文件功能：滑动操作设置页面，用户可自定义状态卡片的左右滑动手势。
// 相关技术点：
// - SwiftUI 表单与分区：Form、Section 组织界面。
// - @Bindable：双向数据绑定，便于修改用户偏好。
// - @Environment：主题、用户偏好等依赖注入。
// - Picker：选择器控件，支持单选操作。
// - Toggle：开关控件，启用/禁用功能。
// - onChange：监听数据变化，自动响应交互。
// - 条件编译：适配 visionOS。
//
// 技术点详解：
// 1. @Bindable：Swift 数据绑定，支持双向绑定可观察对象属性。
// 2. SwiftUI 表单：Form/Section 适合设置页面分组布局。
// 3. Picker：选择器组件，支持枚举选项展示。
// 4. onChange：监听属性变化，执行副作用操作。
// 5. disabled：根据条件禁用控件，提升用户体验。
// 6. @Environment：注入全局状态，便于跨组件共享。
// 7. LocalizedStringKey：支持本地化界面文本。
import DesignSystem
// 导入设计系统，包含主题、控件等
import Env
// 导入环境依赖模块
import SwiftUI

// 导入 SwiftUI 框架

// 主线程下定义滑动操作设置视图
@MainActor
struct SwipeActionsSettingsView: View {
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
        // 左滑操作标签
        Label("settings.swipeactions.status.leading", systemImage: "arrow.right")
          .foregroundColor(.secondary)

        // 左滑主要操作选择器
        createStatusActionPicker(
          selection: $userPreferences.swipeActionsStatusLeadingLeft,
          label: "settings.swipeactions.primary"
        )
        // 监听左滑主要操作变化，如果选择无操作则清空次要操作
        .onChange(of: userPreferences.swipeActionsStatusLeadingLeft) { _, action in
          if action == .none {
            userPreferences.swipeActionsStatusLeadingRight = .none
          }
        }

        // 左滑次要操作选择器
        createStatusActionPicker(
          selection: $userPreferences.swipeActionsStatusLeadingRight,
          label: "settings.swipeactions.secondary"
        )
        // 当左滑主要操作为无时，禁用次要操作
        .disabled(userPreferences.swipeActionsStatusLeadingLeft == .none)

        // 右滑操作标签
        Label("settings.swipeactions.status.trailing", systemImage: "arrow.left")
          .foregroundColor(.secondary)

        // 右滑主要操作选择器
        createStatusActionPicker(
          selection: $userPreferences.swipeActionsStatusTrailingRight,
          label: "settings.swipeactions.primary"
        )
        // 监听右滑主要操作变化，如果选择无操作则清空次要操作
        .onChange(of: userPreferences.swipeActionsStatusTrailingRight) { _, action in
          if action == .none {
            userPreferences.swipeActionsStatusTrailingLeft = .none
          }
        }

        // 右滑次要操作选择器
        createStatusActionPicker(
          selection: $userPreferences.swipeActionsStatusTrailingLeft,
          label: "settings.swipeactions.secondary"
        )
        // 当右滑主要操作为无时，禁用次要操作
        .disabled(userPreferences.swipeActionsStatusTrailingRight == .none)

      } header: {
        // 分区标题
        Text("settings.swipeactions.status")
      } footer: {
        // 分区说明
        Text("settings.swipeactions.status.explanation")
      }
      #if !os(visionOS)
        // 设置分区背景色为主题主背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section {
        // 图标样式选择器
        Picker(
          selection: $userPreferences.swipeActionsIconStyle,
          label: Text("settings.swipeactions.icon-style")
        ) {
          ForEach(UserPreferences.SwipeActionsIconStyle.allCases, id: \.rawValue) { style in
            Text(style.description).tag(style)
          }
        }
        // 是否使用主题色开关
        Toggle(isOn: $userPreferences.swipeActionsUseThemeColor) {
          Text("settings.swipeactions.use-theme-colors")
        }
      } header: {
        // 分区标题
        Text("settings.swipeactions.appearance")
      } footer: {
        // 分区说明
        Text("settings.swipeactions.use-theme-colors-explanation")
      }
      #if !os(visionOS)
        // 设置分区背景色为主题主背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    // 设置导航标题
    .navigationTitle("settings.swipeactions.navigation-title")
    #if !os(visionOS)
      // 隐藏表单默认背景
      .scrollContentBackground(.hidden)
      // 设置整体背景色为主题次背景色
      .background(theme.secondaryBackgroundColor)
    #endif
  }

  // 创建状态操作选择器
  private func createStatusActionPicker(selection: Binding<StatusAction>, label: LocalizedStringKey)
    -> some View
  {
    Picker(selection: selection, label: Text(label)) {
      Section {
        // 无操作选项
        Text(StatusAction.none.displayName()).tag(StatusAction.none)
      }
      Section {
        // 遍历所有可用操作
        ForEach(StatusAction.allCases) { action in
          if action != .none {
            Text(action.displayName()).tag(action)
          }
        }
      }
    }
  }
}
