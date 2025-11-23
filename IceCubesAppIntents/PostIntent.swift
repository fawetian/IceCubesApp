// 文件功能说明：
// 该文件定义了发帖意图，支持通过 Siri 快捷指令创建新的文本帖子，可以接收来自其他快捷指令的文本内容，并在应用中打开编辑界面进行进一步编辑和发布。
// 技术点：
// 1. App Intents 框架 —— iOS 16+ 的快捷指令集成。
// 2. @Parameter 属性包装器 —— 定义文本输入参数。
// 3. inputConnectionBehavior —— 控制参数与前一个快捷指令的连接行为。
// 4. 可选参数 —— 支持不传入内容直接打开编辑器。
// 5. AppIntentService —— 应用内部的意图处理服务。
// 6. HandledIntent —— 封装已处理的意图数据。
// 7. openAppWhenRun —— 控制执行时是否打开应用。
// 8. LocalizedStringResource —— 本地化字符串资源。
// 9. IntentDescription —— 快捷指令的描述信息。
// 10. 数据传递机制 —— 在快捷指令和应用间传递内容。
//
// 技术点详解：
// - App Intents：现代化的快捷指令框架，提供类型安全和更好的集成体验
// - @Parameter：定义快捷指令的输入参数，支持可选值和连接行为
// - inputConnectionBehavior：允许参数从前一个快捷指令步骤获取输入值
// - 可选参数：String? 类型允许用户不提供内容直接打开编辑器
// - AppIntentService：单例服务，在应用启动时处理传入的快捷指令数据
// - HandledIntent：包装快捷指令数据的结构体，便于应用内部处理
// - 应用启动：设置为 true 确保快捷指令执行时打开应用界面
// - 本地化：使用 LocalizedStringResource 支持多语言显示
// - 简洁设计：轻量级的意图，主要负责数据传递而非复杂逻辑
// - 用户体验：支持从其他应用或快捷指令步骤接收文本内容

// 引入 App Intents 框架
import AppIntents
// 引入 Foundation 框架
import Foundation

// 发帖意图结构体，支持通过快捷指令创建文本帖子
struct PostIntent: AppIntent {
  // 快捷指令的标题
  static let title: LocalizedStringResource = "Compose a post to Mastodon"
  // 快捷指令的描述
  static let description: IntentDescription = "Use Ice Cubes to compose a post for Mastodon"
  // 执行时打开应用（需要在应用内编辑和发布帖子）
  static let openAppWhenRun: Bool = true

  // 帖子内容参数，可选值，支持从前一个快捷指令步骤接收文本
  @Parameter(title: "Post content", inputConnectionBehavior: .connectToPreviousIntentResult)
  var content: String?

  // 执行发帖操作
  func perform() async throws -> some IntentResult {
    // 将意图数据传递给应用内部的意图处理服务
    AppIntentService.shared.handledIntent = .init(intent: self)
    // 返回执行结果（应用会在启动后处理文本内容）
    return .result()
  }
}
