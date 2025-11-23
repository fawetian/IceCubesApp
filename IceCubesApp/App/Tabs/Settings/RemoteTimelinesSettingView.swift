// 文件功能：远程时间线设置页面，管理本地保存的远程实例时间线列表。
// 相关技术点：
// - SwiftData：数据持久化框架，@Query 查询数据。
// - @Environment：依赖注入，模型上下文和路由。
// - Form 表单：列表展示和操作界面。
// - .onDelete：SwiftUI 删除手势处理。
// - EditButton：系统编辑按钮。
// - LocalTimeline：本地时间线数据模型。
//
// 技术点详解：
// 1. @Query：SwiftData 查询装饰器，自动更新视图。
// 2. \.modelContext：SwiftData 模型上下文环境值。
// 3. sort: \LocalTimeline.creationDate：按创建日期排序。
// 4. order: .reverse：倒序排列，最新的在前。
// 5. context.delete：删除数据模型实例。
// 6. presentedSheet：Sheet 弹窗展示控制。
// 7. EditButton：系统提供的编辑模式切换按钮。
import DesignSystem
// 导入设计系统，主题和样式
import Env
// 导入环境配置，路由路径
import Models
// 导入数据模型，LocalTimeline 等
import SwiftData
// 导入 SwiftData 数据持久化框架
import SwiftUI
// 导入 SwiftUI 框架

// 远程时间线设置视图
struct RemoteTimelinesSettingView: View {
  // 注入 SwiftData 模型上下文
  @Environment(\.modelContext) private var context

  // 注入路由路径
  @Environment(RouterPath.self) private var routerPath
  // 注入主题
  @Environment(Theme.self) private var theme

  // 查询本地时间线，按创建日期倒序排列
  @Query(sort: \LocalTimeline.creationDate, order: .reverse) var localTimelines: [LocalTimeline]

  // 主体视图
  var body: some View {
    Form {
      // 遍历显示本地时间线列表
      ForEach(localTimelines) { timeline in
        Text(timeline.instance)
      }.onDelete { indexes in
        // 删除选中的时间线
        if let index = indexes.first {
          context.delete(localTimelines[index])
        }
      }
      #if !os(visionOS)
        // 设置行背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
      // 添加远程时间线按钮
      Button {
        routerPath.presentedSheet = .addRemoteLocalTimeline
      } label: {
        Label("settings.timeline.add", systemImage: "badge.plus.radiowaves.right")
      }
      #if !os(visionOS)
        // 设置行背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    // 设置导航标题
    .navigationTitle("settings.general.remote-timelines")
    // 隐藏滚动内容背景
    .scrollContentBackground(.hidden)
    #if !os(visionOS)
      // 设置次要背景色
      .background(theme.secondaryBackgroundColor)
    #endif
    .toolbar {
      // 编辑按钮，用于进入删除模式
      EditButton()
    }
  }
}
