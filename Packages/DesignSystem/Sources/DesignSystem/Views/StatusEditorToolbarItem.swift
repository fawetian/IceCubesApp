// 文件功能说明：
// 该文件实现了状态编辑器工具栏项组件，为导航栏提供新建帖子按钮和副栏控制按钮，支持多平台窗口管理和用户偏好设置。

// 技术点：
// 1. ToolbarContent协议 —— SwiftUI工具栏内容定义
// 2. @MainActor修饰符 —— 确保UI操作在主线程执行
// 3. 条件编译 —— 针对不同平台提供不同的UI行为
// 4. @Environment环境值 —— 获取系统提供的环境数据
// 5. RouterPath导航 —— 应用内路由和页面导航管理
// 6. WindowDestination —— 多窗口应用的窗口目标定义
// 7. HapticManager —— 触觉反馈管理器
// 8. 无障碍支持 —— accessibilityLabel和inputLabels
// 9. 动画过渡 —— withAnimation包装状态变化
// 10. Extension扩展 —— 为现有类型添加便捷方法

// 技术点详解：
// 1. ToolbarContent：SwiftUI协议，定义工具栏项的内容和布局
// 2. @MainActor：Swift并发安全特性，确保所有UI更新在主线程执行
// 3. 条件编译：#if targetEnvironment()检查运行环境，为不同平台提供特定行为
// 4. @Environment：SwiftUI环境系统，访问系统或应用级别的共享数据
// 5. RouterPath：应用的导航路径管理器，控制页面跳转和模态显示
// 6. WindowDestination：定义多窗口应用中不同窗口的目标和配置
// 7. HapticManager：管理设备触觉反馈，提供按钮点击等交互反馈
// 8. 无障碍支持：为视障用户提供屏幕阅读器标签和快捷输入选项
// 9. 动画过渡：SwiftUI的withAnimation函数为状态变化添加平滑动画
// 10. Extension：Swift语言特性，为现有类型添加新功能而不修改原始定义

// 导入Env模块，提供环境管理和路由功能
import Env
// 导入Models模块，提供数据模型定义
import Models
// 导入SwiftUI框架，提供视图和工具栏组件
import SwiftUI

// 扩展View类型，添加状态编辑器工具栏项的便捷方法
@MainActor
extension View {
  // 公共方法：为视图添加状态编辑器工具栏项
  public func statusEditorToolbarItem(
    routerPath _: RouterPath,
    visibility: Models.Visibility
  ) -> some ToolbarContent {
    // 返回状态编辑器工具栏项实例
    StatusEditorToolbarItem(visibility: visibility)
  }
}

// 扩展ToolbarContent类型，添加状态编辑器工具栏项的便捷方法
@MainActor
extension ToolbarContent {
  // 公共方法：为工具栏内容添加状态编辑器项
  public func statusEditorToolbarItem(
    routerPath _: RouterPath,
    visibility: Models.Visibility
  ) -> some ToolbarContent {
    // 返回状态编辑器工具栏项实例
    StatusEditorToolbarItem(visibility: visibility)
  }
}

// 状态编辑器工具栏项，提供新建帖子功能的工具栏按钮
@MainActor
public struct StatusEditorToolbarItem: ToolbarContent {
  // 从环境中获取开窗函数，用于多窗口支持
  @Environment(\.openWindow) private var openWindow
  // 从环境中获取路由路径，用于导航管理
  @Environment(RouterPath.self) private var routerPath

  // 存储帖子的可见性设置
  let visibility: Models.Visibility

  // 公共初始化方法，创建状态编辑器工具栏项
  public init(visibility: Models.Visibility) {
    // 设置帖子可见性
    self.visibility = visibility
  }

  // ToolbarContent协议要求的主体属性，定义工具栏项内容
  public var body: some ToolbarContent {
    // 创建工具栏项，放置在导航栏尾部
    ToolbarItem(placement: .navigationBarTrailing) {
      // 新建帖子按钮
      Button {
        // 创建异步任务处理按钮点击
        Task { @MainActor in
          // 根据平台选择不同的打开方式
          #if targetEnvironment(macCatalyst) || os(visionOS)
            // macCatalyst和visionOS：在新窗口中打开编辑器
            openWindow(value: WindowDestinationEditor.newStatusEditor(visibility: visibility))
          #else
            // 其他平台：在模态页面中打开编辑器
            routerPath.presentedSheet = .newStatusEditor(visibility: visibility)
            // 触发触觉反馈
            HapticManager.shared.fireHaptic(.buttonPress)
          #endif
        }
      } label: {
        // 按钮图标：方形和铅笔（新建帖子图标）
        Image(systemName: "square.and.pencil")
          // 设置无障碍标签
          .accessibilityLabel("accessibility.tabs.timeline.new-post.label")
          // 设置无障碍输入标签（语音控制）
          .accessibilityInputLabels([
            LocalizedStringKey("accessibility.tabs.timeline.new-post.label"),
            LocalizedStringKey("accessibility.tabs.timeline.new-post.inputLabel1"),
            LocalizedStringKey("accessibility.tabs.timeline.new-post.inputLabel2"),
          ])
          // 图标向上偏移2点，调整视觉对齐
          .offset(y: -2)
      }
      .tint(.label)
    }
  }
}

// 副栏工具栏项，用于控制iPad副栏的显示和隐藏
@MainActor
public struct SecondaryColumnToolbarItem: ToolbarContent {
  // 从环境中获取是否为副栏的状态
  @Environment(\.isSecondaryColumn) private var isSecondaryColumn
  // 从环境中获取用户偏好设置
  @Environment(UserPreferences.self) private var preferences

  // 公共初始化方法
  public init() {}

  // ToolbarContent协议要求的主体属性，定义工具栏项内容
  public var body: some ToolbarContent {
    // 根据是否为副栏决定工具栏项的位置
    ToolbarItem(placement: isSecondaryColumn ? .navigationBarLeading : .navigationBarTrailing) {
      // 副栏切换按钮
      Button {
        // 使用动画包装状态变化
        withAnimation {
          // 切换iPad副栏显示状态
          preferences.showiPadSecondaryColumn.toggle()
        }
      } label: {
        // 按钮图标：右侧边栏图标
        Image(systemName: "sidebar.right")
      }
      .tint(.label)
    }
  }
}
