// 文件功能说明：
// 该文件定义了 ListsListView 视图，负责展示和管理当前账号的所有列表（如分组、关注列表等），支持导航、删除、刷新等操作。
// 技术点：
// 1. SwiftUI View 组合式开发。
// 2. @Environment —— 状态与依赖注入。
// 3. List、NavigationLink、onDelete、refreshable 等列表操作。
// 4. 异步任务、删除、刷新、导航。
// 5. 多平台适配（visionOS）。
//
// 下面为每行代码详细注释：
// 引入设计系统模块
import DesignSystem
// 引入环境配置模块
import Env
// 引入模型模块
import Models
// 引入 SwiftUI 框架
import SwiftUI

// 公开结构体，定义列表视图
public struct ListsListView: View {
  // 注入当前账号
  @Environment(CurrentAccount.self) private var currentAccount
  // 注入主题管理器
  @Environment(Theme.self) private var theme

  // 初始化方法
  public init() {}

  // 主体视图
  public var body: some View {
    List {
      // 遍历所有列表，生成导航链接
      ForEach(currentAccount.lists) { list in
        NavigationLink(value: RouterDestination.list(list: list)) {
          Text(list.title)
            .font(.scaledHeadline)
        }
        #if !os(visionOS)
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
      }
      // 支持滑动删除
      .onDelete { index in
        if let index = index.first {
          Task {
            await currentAccount.deleteList(currentAccount.lists[index])
          }
        }
      }
    }
    // 首次进入自动拉取列表
    .task {
      await currentAccount.fetchLists()
    }
    // 下拉刷新
    .refreshable {
      await currentAccount.fetchLists()
    }
    #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
    #endif
    .listStyle(.plain)
    .navigationTitle("timeline.filter.lists")
    .navigationBarTitleDisplayMode(.inline)
  }
}
