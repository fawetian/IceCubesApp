// 文件功能说明：
// 该文件定义了 FollowedTagsListView 视图，负责展示和管理当前账号关注的标签列表。用户可以在此查看自己订阅的所有话题标签，支持列表刷新和导航操作。
// 技术点：
// 1. SwiftUI View 组合式开发 —— 基于 SwiftUI 声明式 UI 框架。
// 2. @Environment 依赖注入 —— 注入当前账户和主题等环境对象。
// 3. List 和数据绑定 —— 使用 List 组件展示动态标签数据。
// 4. TagRowView 复用 —— 复用标签行视图组件保持一致性。
// 5. 异步任务处理 —— 使用 task 和 refreshable 处理数据获取。
// 6. 多平台适配 —— 根据不同平台调整视觉样式。
// 7. 导航标题管理 —— 设置本地化的导航标题。
// 8. 下拉刷新机制 —— 支持用户手动刷新标签列表。
// 9. 主题系统集成 —— 根据应用主题调整背景色。
// 10. 生命周期管理 —— 在视图出现时自动获取数据。
//
// 技术点详解：
// - SwiftUI View：现代化的声明式 UI 开发模式，描述界面状态而非操作步骤
// - @Environment：SwiftUI 的依赖注入机制，自动管理跨视图的共享状态
// - List 数据驱动：基于数据集合自动生成列表项，支持动态更新
// - TagRowView 组件化：通过组件复用确保标签显示的一致性和可维护性
// - task 生命周期：在视图出现时自动执行异步数据获取任务
// - refreshable 交互：为用户提供主动刷新数据的能力
// - 条件编译：使用 #if 指令为不同平台提供适配的视觉效果
// - 本地化支持：使用 LocalizedStringKey 支持多语言界面
// - 主题适配：根据用户选择的主题动态调整界面颜色
// - 异步数据流：通过 CurrentAccount 统一管理标签数据的获取和状态

// 引入设计系统模块，提供主题和视觉组件
import DesignSystem
// 引入环境配置模块，提供当前账户等环境对象
import Env
// 引入数据模型模块，提供标签等核心数据结构
import Models
// 引入 SwiftUI 框架，构建现代化用户界面
import SwiftUI

// 关注标签列表视图的公开结构体
public struct FollowedTagsListView: View {
  // 注入当前账户环境对象，获取用户关注的标签数据
  @Environment(CurrentAccount.self) private var currentAccount
  // 注入主题环境对象，获取当前应用主题设置
  @Environment(Theme.self) private var theme

  // 公开的初始化方法，不需要参数
  public init() {}

  // 视图的主体内容定义
  public var body: some View {
    // 创建列表视图，遍历当前账户关注的标签
    List(currentAccount.tags) { tag in
      // 为每个标签创建行视图
      TagRowView(tag: tag)
        #if !os(visionOS)
          // 在非 visionOS 平台设置列表行背景色
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
        // 添加垂直内边距，增加行间距
        .padding(.vertical, 4)
    }
    // 视图首次出现时执行的异步任务
    .task {
      // 异步获取用户关注的标签列表
      await currentAccount.fetchFollowedTags()
    }
    // 支持下拉刷新功能
    .refreshable {
      // 重新获取关注的标签列表
      await currentAccount.fetchFollowedTags()
    }
    #if !os(visionOS)
      // 在非 visionOS 平台隐藏默认滚动背景
      .scrollContentBackground(.hidden)
      // 设置自定义背景色
      .background(theme.secondaryBackgroundColor)
    #endif
    // 使用简洁的列表样式
    .listStyle(.plain)
    // 设置导航标题为本地化字符串
    .navigationTitle("timeline.filter.tags")
    // 设置导航栏标题显示模式为内联
    .navigationBarTitleDisplayMode(.inline)
  }
}
