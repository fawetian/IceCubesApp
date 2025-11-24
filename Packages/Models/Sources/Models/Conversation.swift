// 文件功能：Mastodon 对话（私信）数据模型
//
// 核心职责：
// - 表示 Mastodon 的私信对话
// - 包含对话的参与者和最后一条消息
// - 跟踪未读状态
// - 支持多人对话
//
// 技术要点：
// - Conversation：对话的完整信息
// - accounts：对话的所有参与者
// - lastStatus：对话中的最后一条消息
// - unread：是否有未读消息
//
// 对话特性：
// - 类似于聊天应用的对话列表
// - 显示最后一条消息的预览
// - 支持多人对话（群聊）
// - 实时更新未读状态
//
// 依赖关系：
// - 依赖：Status, Account
// - 被依赖：ConversationsListView, MessagesTab

import Foundation

/// Mastodon 对话（私信）数据模型
///
/// 表示 Mastodon 中的私信对话，类似于聊天应用的对话列表。
///
/// 对话特性：
/// - 包含对话的所有参与者
/// - 显示最后一条消息
/// - 跟踪未读状态
/// - 支持多人对话（群聊）
///
/// 工作原理：
/// - Mastodon 的私信实际上是可见性为 "direct" 的帖子
/// - 系统自动将相关的私信组织成对话
/// - 对话按最后消息时间排序
/// - 新消息会更新对话的未读状态
///
/// 使用示例：
/// ```swift
/// ForEach(conversations) { conversation in
///     HStack {
///         // 显示参与者头像
///         ForEach(conversation.accounts.prefix(3)) { account in
///             AvatarView(url: account.avatar)
///         }
///         
///         VStack(alignment: .leading) {
///             // 显示参与者名称
///             Text(conversation.accounts.map { $0.displayName }.joined(separator: ", "))
///             
///             // 显示最后一条消息
///             if let lastStatus = conversation.lastStatus {
///                 Text(lastStatus.content.asRawText)
///                     .lineLimit(1)
///             }
///         }
///         
///         if conversation.unread {
///             Circle()
///                 .fill(Color.blue)
///                 .frame(width: 8, height: 8)
///         }
///     }
/// }
/// ```
public struct Conversation: Identifiable, Decodable, Hashable, Equatable {
  /// 对话的唯一标识符
  public let id: String
  
  /// 是否有未读消息
  ///
  /// 未读状态的判断：
  /// - 对话中有新消息且用户未查看
  /// - 用户打开对话后，未读状态会被清除
  /// - 用于显示未读标记（如蓝点）
  ///
  /// UI 表现：
  /// - 未读对话通常显示蓝点或加粗
  /// - 未读对话排在列表前面
  /// - 打开对话后自动标记为已读
  public let unread: Bool
  
  /// 对话中的最后一条消息
  ///
  /// 用途：
  /// - 在对话列表中显示消息预览
  /// - 显示最后消息的时间
  /// - 判断对话的活跃度
  ///
  /// 为什么是可选值？
  /// - 理论上对话应该总有消息
  /// - 但某些边缘情况下可能为空
  /// - 例如消息被删除或过滤
  ///
  /// - Note: 通常不为 nil，但需要安全处理
  public let lastStatus: Status?
  
  /// 对话的参与者列表
  ///
  /// 包含对话中的所有用户（除了当前用户）。
  ///
  /// 参与者说明：
  /// - 不包括当前用户自己
  /// - 单人对话：数组包含 1 个账户
  /// - 群聊：数组包含多个账户
  /// - 按某种顺序排列（通常是最后发言时间）
  ///
  /// 用途：
  /// - 显示对话的参与者头像
  /// - 显示对话的标题（参与者名称）
  /// - 判断是单聊还是群聊
  ///
  /// UI 显示：
  /// - 单人对话：显示对方的名称和头像
  /// - 群聊：显示多个头像或 "你和 N 个人"
  public let accounts: [Account]

  /// 初始化对话
  ///
  /// - Parameters:
  ///   - id: 对话 ID
  ///   - unread: 是否未读
  ///   - lastStatus: 最后一条消息
  ///   - accounts: 参与者列表
  public init(id: String, unread: Bool, lastStatus: Status? = nil, accounts: [Account]) {
    self.id = id
    self.unread = unread
    self.lastStatus = lastStatus
    self.accounts = accounts
  }

  /// 创建占位符对话
  ///
  /// 用于 SwiftUI 预览、测试和加载状态。
  ///
  /// 使用场景：
  /// ```swift
  /// #Preview {
  ///     ConversationRowView(conversation: .placeholder())
  /// }
  /// ```
  public static func placeholder() -> Conversation {
    .init(
      id: UUID().uuidString, unread: false, lastStatus: .placeholder(), accounts: [.placeholder()])
  }

  /// 创建占位符对话数组
  ///
  /// 返回 10 个占位符对话，用于列表预览。
  ///
  /// 使用场景：
  /// ```swift
  /// #Preview {
  ///     List(Conversation.placeholders()) { conversation in
  ///         ConversationRowView(conversation: conversation)
  ///     }
  /// }
  /// ```
  public static func placeholders() -> [Conversation] {
    [
      .placeholder(), .placeholder(), .placeholder(), .placeholder(), .placeholder(),
      .placeholder(), .placeholder(), .placeholder(), .placeholder(), .placeholder(),
    ]
  }
}

// MARK: - Sendable 一致性

/// Conversation 符合 Sendable 协议
///
/// 所有属性都是不可变的，可以安全地在并发上下文中使用
extension Conversation: Sendable {}
