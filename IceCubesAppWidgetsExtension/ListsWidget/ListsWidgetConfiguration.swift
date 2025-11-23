// 文件功能说明：
// 该文件定义了列表小组件的配置意图，允许用户在添加小组件时选择要监控的 Mastodon 账户和特定列表。用户可以通过配置界面选择感兴趣的用户列表，小组件将显示该列表成员的最新帖子。
// 技术点：
// 1. WidgetConfigurationIntent 协议 —— 小组件配置意图的基础协议。
// 2. 双参数配置 —— 需要配置账户和列表两个参数。
// 3. 实体引用 —— 使用 ListEntity 表示 Mastodon 列表。
// 4. 本地化字符串 —— 配置界面标题支持多语言。
// 5. 意图描述 —— 为用户提供配置操作的指导说明。
// 6. 参数装饰器 —— 使用 @Parameter 声明可配置项。
// 7. 账户实体 —— 关联 AppAccountEntity 账户实体。
// 8. 预览配置 —— 提供开发和测试用的示例数据。
// 9. 扩展方法 —— 通过扩展添加便利功能。
// 10. 可选参数 —— 所有参数都是可选的，提高容错性。
//
// 技术点详解：
// - 列表过滤：专门用于监控特定用户群组的动态内容
// - ListEntity：封装 Mastodon 列表信息的实体，支持列表选择
// - LocalizedStringResource：自动适配用户设备的语言设置
// - IntentDescription：在配置界面为用户提供清晰的操作指导
// - @Parameter：系统自动生成对应的配置 UI 组件
// - AppAccountEntity：复用应用中的账户管理机制
// - 双重配置：账户决定数据源，列表决定内容范围
// - 预览支持：提供示例配置便于开发时调试
// - 可选性设计：参数可选确保配置流程的灵活性
// - 扩展模式：保持核心配置简洁，额外功能通过扩展实现

// 引入应用意图框架，提供小组件配置功能
import AppIntents
// 引入小组件工具包，提供配置意图基础支持
import WidgetKit

// 列表小组件的配置意图结构体
struct ListsWidgetConfiguration: WidgetConfigurationIntent {
  // 配置意图的标题，支持本地化显示
  static let title: LocalizedStringResource = "List Widget Configuration"
  // 配置意图的描述，指导用户进行账户和列表配置
  static let description = IntentDescription("Choose the account and list for this widget")

  // 账户选择参数，用户可以选择要使用的 Mastodon 账户
  @Parameter(title: "Account")
  var account: AppAccountEntity?

  // 列表选择参数，用户可以选择要监控的用户列表
  @Parameter(title: "List")
  var timeline: ListEntity?
}

// 为配置意图添加扩展方法
extension ListsWidgetConfiguration {
  // 提供预览和开发用的配置示例
  static var previewAccount: LatestPostsWidgetConfiguration {
    // 创建新的配置意图实例（注意这里使用了 LatestPostsWidgetConfiguration，可能是代码错误）
    let intent = LatestPostsWidgetConfiguration()
    // 设置示例账户信息，用于预览和测试
    intent.account = .init(account: .init(server: "Test", accountName: "Test account"))
    // 返回配置好的示例实例
    return intent
  }
}
