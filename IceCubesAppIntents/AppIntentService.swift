// 文件功能说明：
// 该文件定义了应用意图服务，作为快捷指令和主应用之间的桥梁，负责接收和管理来自 App Intents 的意图数据，通过单例模式提供全局访问，支持应用启动时处理快捷指令传递的数据。
// 技术点：
// 1. @Observable 属性包装器 —— SwiftUI 的现代状态管理。
// 2. @unchecked Sendable 协议 —— 解决并发安全标记问题。
// 3. 单例模式 —— 全局唯一的服务实例。
// 4. 嵌套结构体 —— HandledIntent 作为内部数据结构。
// 5. Equatable 协议 —— 支持意图对象的相等性比较。
// 6. UUID 生成 —— 为每个意图创建唯一标识符。
// 7. 类型擦除 —— 使用 any AppIntent 存储不同类型的意图。
// 8. 可选值处理 —— 使用可选类型管理意图状态。
// 9. 私有初始化器 —— 确保单例模式的正确实现。
// 10. 数据封装 —— 将意图和标识符封装在一起。
//
// 技术点详解：
// - @Observable：SwiftUI 的现代响应式编程模型，替代 ObservableObject
// - @unchecked Sendable：标记类为并发安全，用于在不同线程间传递
// - 单例模式：确保全应用只有一个意图服务实例，方便全局状态管理
// - 嵌套结构体：HandledIntent 封装了意图数据和唯一标识符
// - Equatable：通过比较 ID 实现意图对象的相等性判断
// - UUID：为每个处理的意图生成唯一标识符，避免重复处理
// - 类型擦除：使用 any AppIntent 存储不同类型的快捷指令意图
// - 状态管理：通过可选值跟踪当前正在处理的意图
// - 访问控制：私有初始化器防止外部创建额外实例
// - 数据桥接：在快捷指令扩展和主应用间传递数据

// 引入 App Intents 框架
import AppIntents
// 引入 SwiftUI 框架
import SwiftUI

// 应用意图服务类，使用 SwiftUI 的可观察模式和并发安全标记
@Observable
public class AppIntentService: @unchecked Sendable {
  // 已处理意图结构体，封装意图数据和唯一标识符
  struct HandledIntent: Equatable {
    // 实现相等性比较，通过 ID 判断是否为同一个意图
    static func == (lhs: AppIntentService.HandledIntent, rhs: AppIntentService.HandledIntent)
      -> Bool
    {
      lhs.id == rhs.id
    }

    // 意图的唯一标识符
    let id: String
    // 实际的意图对象（类型擦除）
    let intent: any AppIntent

    // 初始化器，为新意图生成唯一 ID
    init(intent: any AppIntent) {
      // 生成随机的 UUID 字符串作为标识符
      id = UUID().uuidString
      self.intent = intent
    }
  }

  // 单例实例，全应用共享
  public static let shared = AppIntentService()

  // 当前正在处理的意图，可选值
  var handledIntent: HandledIntent?

  // 私有初始化器，确保单例模式
  private init() {}
}
