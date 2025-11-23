// 文件功能说明：
// 该文件定义了账户小组件的配置意图，允许用户在添加小组件时选择要显示的 Mastodon 账户。由于账户小组件功能相对简单，只需要配置一个账户参数即可。
// 技术点：
// 1. WidgetConfigurationIntent 协议 —— 小组件配置的基础协议。
// 2. 单一参数配置 —— 只需配置账户一个参数。
// 3. 本地化支持 —— 配置界面支持多语言。
// 4. 意图描述 —— 为用户提供清晰的配置说明。
// 5. 参数装饰器 —— 使用 @Parameter 声明配置项。
// 6. 实体引用 —— 关联 AppAccountEntity 账户实体。
// 7. 预览配置 —— 提供开发调试用的示例配置。
// 8. 扩展设计 —— 通过扩展添加便利方法。
// 9. 可选参数 —— 支持用户不选择账户的情况。
// 10. 简化配置 —— 配置流程简洁，用户体验友好。
//
// 技术点详解：
// - 单一职责：专注于账户选择，配置简单明确
// - LocalizedStringResource：自动适配系统语言设置
// - IntentDescription：在设置界面显示功能说明
// - @Parameter：系统自动生成账户选择 UI
// - AppAccountEntity：复用应用中的账户实体
// - 预览支持：提供测试数据便于开发调试
// - 可选设计：账户参数为可选，提高容错性
// - 扩展模式：保持核心结构简洁，功能分离
// - 静态配置：title 和 description 为小组件提供元信息
// - 用户体验：配置步骤最少化，降低使用门槛

// 引入应用意图框架，提供小组件配置功能
import AppIntents
// 引入小组件工具包，提供配置意图支持
import WidgetKit

// 账户小组件的配置意图结构体
struct AccountWidgetConfiguration: WidgetConfigurationIntent {
  // 配置意图的标题，支持本地化显示
  static let title: LocalizedStringResource = "Account Widget Configuration"
  // 配置意图的描述，指导用户进行配置
  static let description = IntentDescription("Choose the account for this widget")

  // 账户选择参数，用户可以选择要显示的账户
  @Parameter(title: "Account")
  var account: AppAccountEntity?
}

// 为配置意图添加扩展方法
extension AccountWidgetConfiguration {
  // 提供预览和开发用的账户配置示例
  static var previewAccount: AccountWidgetConfiguration {
    // 创建新的配置意图实例
    let intent = AccountWidgetConfiguration()
    // 设置示例账户信息，用于预览和测试
    intent.account = .init(account: .init(server: "Test", accountName: "Test account"))
    // 返回配置好的示例实例
    return intent
  }
}
