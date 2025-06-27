// 文件功能：标签分组设置页面，用户可查看、编辑、删除、新增标签分组。
// 相关技术点：
// - SwiftData：@Query 数据查询与 @Environment(\.modelContext) 数据操作。
// - SwiftUI 表单：Form 组织界面。
// - @Environment：路由、主题等依赖注入。
// - ForEach：遍历数据生成列表。
// - onTapGesture：手势响应，点击编辑。
// - onDelete：滑动删除功能。
// - 导航与工具栏：navigationTitle、toolbar、EditButton。
// - 条件编译：适配 visionOS。
//
// 技术点详解：
// 1. SwiftData：苹果官方数据持久化框架，替代 Core Data。
// 2. @Query：SwiftData 数据查询，支持排序、过滤等。
// 3. modelContext：SwiftData 数据上下文，用于增删改查操作。
// 4. ForEach：遍历集合生成视图，支持 Identifiable 协议。
// 5. onTapGesture：添加手势响应，处理用户交互。
// 6. onDelete：列表滑动删除功能，支持批量删除。
// 7. EditButton：SwiftUI 内置编辑按钮，切换编辑模式。
import DesignSystem
// 导入设计系统，包含主题、控件等
import Env
// 导入环境依赖模块
import Models
// 导入数据模型
import SwiftData
// 导入 SwiftData 数据持久化框架
import SwiftUI

// 导入 SwiftUI 框架

// 定义标签分组设置视图
struct TagsGroupSettingView: View {
  // 注入 SwiftData 数据上下文
  @Environment(\.modelContext) private var context

  // 注入路由路径
  @Environment(RouterPath.self) private var routerPath
  // 注入主题
  @Environment(Theme.self) private var theme

  // 查询所有标签分组，按创建时间倒序排列
  @Query(sort: \TagGroup.creationDate, order: .reverse) var tagGroups: [TagGroup]

  // 主体视图
  var body: some View {
    Form {
      // 遍历所有标签分组
      ForEach(tagGroups) { group in
        // 显示标签分组的标题和图标
        Label(group.title, systemImage: group.symbolName)
          // 点击手势，打开编辑页面
          .onTapGesture {
            routerPath.presentedSheet = .editTagGroup(tagGroup: group, onSaved: nil)
          }
      }
      // 滑动删除功能
      .onDelete { indexes in
        if let index = indexes.first {
          context.delete(tagGroups[index])
        }
      }
      #if !os(visionOS)
        // 设置列表行背景色为主题主背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      // 添加新标签分组按钮
      Button {
        routerPath.presentedSheet = .addTagGroup
      } label: {
        Label("timeline.filter.add-tag-groups", systemImage: "plus")
      }
      #if !os(visionOS)
        // 设置按钮背景色为主题主背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    // 设置导航标题
    .navigationTitle("timeline.filter.tag-groups")
    // 隐藏表单默认背景
    .scrollContentBackground(.hidden)
    #if !os(visionOS)
      // 设置整体背景色为主题次背景色
      .background(theme.secondaryBackgroundColor)
    #endif
    // 添加编辑按钮到工具栏
    .toolbar {
      EditButton()
    }
  }
}
