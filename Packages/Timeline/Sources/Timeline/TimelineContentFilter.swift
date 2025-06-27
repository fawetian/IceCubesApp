// 文件功能：时间线内容过滤器，控制时间线中显示哪些类型的帖子（转发、回复、话题、引用）。
// 相关技术点：
// - @Observable：SwiftUI 新的状态管理，替代 ObservableObject。
// - @AppStorage：持久化用户设置到 UserDefaults。
// - 单例模式：shared 实例全局访问。
// - 嵌套 Storage 类：组织存储属性的设计模式。
// - didSet 观察器：属性值变化时同步到存储。
// - private init：强制使用单例模式。
// - 布尔过滤：通过四个布尔值控制内容类型。
// - 存储同步：内存状态与持久化存储的双向同步。
//
// 技术点详解：
// 1. @Observable：iOS 17+ 新的响应式状态管理。
// 2. @AppStorage：自动绑定到 UserDefaults 的属性包装器。
// 3. Storage 类：封装所有存储逻辑，保持主类简洁。
// 4. didSet：属性观察器，确保内存状态变化时更新存储。
// 5. 单例模式：确保全局唯一的过滤器实例。
// 6. 存储键名：timeline_show_* 前缀避免键冲突。
// 7. 默认值：true 确保用户首次使用时显示所有内容。
// 8. 私有初始化：从存储读取初始值，建立双向绑定。
// 导入基础库，基本数据类型
import Foundation
// 导入 SwiftUI，@AppStorage 属性包装器
import SwiftUI

// 时间线内容过滤器，控制显示的帖子类型
@MainActor
@Observable public class TimelineContentFilter {
  // 存储类，封装所有 @AppStorage 属性
  class Storage {
    // 是否显示转发帖子的设置
    @AppStorage("timeline_show_boosts") var showBoosts: Bool = true
    // 是否显示回复帖子的设置
    @AppStorage("timeline_show_replies") var showReplies: Bool = true
    // 是否显示话题帖子的设置
    @AppStorage("timeline_show_threads") var showThreads: Bool = true
    // 是否显示引用帖子的设置
    @AppStorage("timeline_quote_posts") var showQuotePosts: Bool = true
  }

  // 单例实例，全局访问
  public static let shared = TimelineContentFilter()
  // 存储实例，管理持久化
  private let storage = Storage()

  // 是否显示转发帖子（带同步机制）
  public var showBoosts: Bool {
    didSet {
      storage.showBoosts = showBoosts
    }
  }

  // 是否显示回复帖子（带同步机制）
  public var showReplies: Bool {
    didSet {
      storage.showReplies = showReplies
    }
  }

  // 是否显示话题帖子（带同步机制）
  public var showThreads: Bool {
    didSet {
      storage.showThreads = showThreads
    }
  }

  // 是否显示引用帖子（带同步机制）
  public var showQuotePosts: Bool {
    didSet {
      storage.showQuotePosts = showQuotePosts
    }
  }

  // 私有初始化器，从存储加载初始值
  private init() {
    showBoosts = storage.showBoosts
    showReplies = storage.showReplies
    showThreads = storage.showThreads
    showQuotePosts = storage.showQuotePosts
  }
}
