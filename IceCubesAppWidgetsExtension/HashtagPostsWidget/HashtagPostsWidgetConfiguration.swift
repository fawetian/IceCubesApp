// 文件功能说明：
// 该文件定义了标签帖子小组件的配置意图，允许用户在添加小组件时选择要监控的 Mastodon 账户和特定标签。用户可以通过配置界面输入感兴趣的标签名称，小组件将显示该标签下的最新帖子。
// 技术点：
// 1. WidgetConfigurationIntent 协议 —— 小组件配置意图的基础协议。
// 2. 双参数配置 —— 需要配置账户和标签两个参数。
// 3. 字符串参数 —— 标签参数使用字符串类型，支持自由输入。
// 4. 本地化字符串 —— 配置界面标题支持多语言。
// 5. 意图描述 —— 为用户提供配置操作的指导说明。
// 6. 参数装饰器 —— 使用 @Parameter 声明可配置项。
// 7. 实体引用 —— 关联 AppAccountEntity 账户实体。
// 8. 预览配置 —— 提供开发和测试用的示例数据。
// 9. 扩展方法 —— 通过扩展添加便利功能。
// 10. 可选参数 —— 所有参数都是可选的，提高容错性。
//
// 技术点详解：
// - 标签监控：专门用于追踪特定话题或标签的讨论动态
// - 字符串输入：标签参数接受用户自由输入，不限制预定义选项
// - LocalizedStringResource：自动适配用户设备的语言设置
// - IntentDescription：在配置界面为用户提供清晰的操作指导
// - @Parameter：系统自动生成对应的配置 UI 组件
// - AppAccountEntity：复用应用中的账户管理机制
// - 双重配置：账户决定数据源，标签决定内容过滤
// - 预览支持：提供示例配置便于开发时调试
// - 可选性设计：参数可选确保配置流程的灵活性
// - 扩展模式：保持核心配置简洁，额外功能通过扩展实现

// 引入应用意图框架，提供小组件配置功能
import AppIntents
// 引入小组件工具包，提供配置意图基础支持
import WidgetKit

// 标签帖子小组件的配置意图结构体
struct HashtagPostsWidgetConfiguration: WidgetConfigurationIntent {
  // 配置意图的标题，支持本地化显示
  static let title: LocalizedStringResource = "Hashtag Widget Configuration"
  // 配置意图的描述，指导用户进行账户和标签配置
  static let description = IntentDescription("Choose the account and hashtag for this widget")

  // 账户选择参数，用户可以选择要使用的 Mastodon 账户
  @Parameter(title: "Account")
  var account: AppAccountEntity?

  // 标签输入参数，用户可以输入要监控的标签名称
  @Parameter(title: "Hashtag")
  var hashgtag: String?
}

// 为配置意图添加扩展方法
extension HashtagPostsWidgetConfiguration {
  // 提供预览和开发用的配置示例
  static var previewAccount: HashtagPostsWidgetConfiguration {
    // 创建新的配置意图实例
    let intent = HashtagPostsWidgetConfiguration()
    // 设置示例账户信息，用于预览和测试
    intent.account = .init(account: .init(server: "Test", accountName: "Test account"))
    // 设置示例标签名称
    intent.hashgtag = "Mastodon"
    // 返回配置好的示例实例
    return intent
  }
}
