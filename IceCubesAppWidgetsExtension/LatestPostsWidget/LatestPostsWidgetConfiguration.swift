// 文件功能说明：
// 该文件定义了最新帖子小组件的配置意图，允许用户在添加小组件时选择账户和时间线类型。使用 App Intents 框架提供交互式配置界面，支持多账户和多时间线选择。
// 技术点：
// 1. WidgetConfigurationIntent 协议 —— 小组件配置意图基础协议。
// 2. AppIntents 框架 —— iOS 16+ 的意图系统，支持 Siri 和小组件。
// 3. 本地化字符串 —— 支持多语言的配置界面。
// 4. 参数装饰器 —— @Parameter 声明可配置的参数。
// 5. 意图描述 —— 为配置提供用户友好的说明。
// 6. 实体引用 —— 关联账户和时间线实体对象。
// 7. 预览配置 —— 提供开发和调试用的示例配置。
// 8. 扩展方法 —— 通过扩展添加便利功能。
// 9. 类型安全 —— 强类型的参数定义和验证。
// 10. 可选参数 —— 支持用户跳过某些配置步骤。
//
// 技术点详解：
// - WidgetConfigurationIntent：让用户在添加小组件时进行个性化配置
// - LocalizedStringResource：自动支持多语言，根据系统语言显示相应文本
// - IntentDescription：在设置界面为用户提供清晰的功能说明
// - @Parameter：标记可配置的参数，系统会自动生成配置 UI
// - AppAccountEntity：封装账户信息的实体，支持账户选择
// - TimelineFilterEntity：封装时间线类型的实体，支持时间线选择
// - 静态配置：title 和 description 为小组件提供元数据
// - 预览支持：previewAccount 为开发环境提供测试数据
// - 可选性设计：参数都是可选的，提高用户体验的灵活性
// - 配置持久化：用户的选择会被系统自动保存和恢复

// 引入应用意图框架，提供配置意图功能
import AppIntents
// 引入小组件工具包，提供小组件配置支持
import WidgetKit

// 最新帖子小组件的配置意图结构体
struct LatestPostsWidgetConfiguration: WidgetConfigurationIntent {
  // 配置意图的标题，支持本地化
  static let title: LocalizedStringResource = "Timeline Widget Configuration"
  // 配置意图的描述，为用户提供操作指导
  static let description = IntentDescription("Choose the account and timeline for this widget")

  // 账户选择参数，用户可以选择要显示的 Mastodon 账户
  @Parameter(title: "Account")
  var account: AppAccountEntity?

  // 时间线选择参数，用户可以选择要显示的时间线类型
  @Parameter(title: "Timeline")
  var timeline: TimelineFilterEntity?
}

// 为配置意图添加扩展方法
extension LatestPostsWidgetConfiguration {
  // 提供预览和开发用的账户配置示例
  static var previewAccount: LatestPostsWidgetConfiguration {
    // 创建新的配置意图实例
    let intent = LatestPostsWidgetConfiguration()
    // 设置示例账户信息
    intent.account = .init(account: .init(server: "Test", accountName: "Test account"))
    // 设置示例时间线为主页时间线
    intent.timeline = .init(timeline: .home)
    // 返回配置好的示例实例
    return intent
  }
}
