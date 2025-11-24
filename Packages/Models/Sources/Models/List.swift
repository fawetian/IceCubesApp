// 文件功能：Mastodon 列表数据模型
//
// 核心职责：
// - 表示 Mastodon 的自定义列表
// - 包含列表的标题和设置
// - 控制回复显示策略
// - 支持独占模式
//
// 技术要点：
// - List：列表的完整信息
// - RepliesPolicy：回复显示策略枚举
// - exclusive：是否从主时间线隐藏
// - title：列表的自定义名称
//
// 列表特性：
// - 用户可以创建多个列表
// - 将特定用户添加到列表
// - 查看列表的专属时间线
// - 控制是否显示回复
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：Timeline, ListsView, CurrentAccount

import Foundation

/// Mastodon 列表数据模型
///
/// 表示用户创建的自定义列表，用于组织关注的账户。
///
/// 列表特性：
/// - 创建多个主题列表（如"朋友"、"工作"、"新闻"）
/// - 将关注的用户添加到列表
/// - 查看列表的专属时间线
/// - 控制回复的显示方式
/// - 可选择是否从主时间线隐藏
///
/// 使用场景：
/// - 组织大量关注的账户
/// - 按主题分类内容
/// - 减少主时间线的噪音
/// - 专注于特定群体的内容
///
/// 使用示例：
/// ```swift
/// // 显示用户的所有列表
/// ForEach(lists) { list in
///     NavigationLink(destination: ListTimelineView(list: list)) {
///         HStack {
///             Text(list.title)
///             Spacer()
///             if list.exclusive == true {
///                 Image(systemName: "eye.slash")
///             }
///         }
///     }
/// }
/// ```
public struct List: Codable, Identifiable, Equatable, Hashable {
  /// 列表的唯一标识符
  public let id: String
  
  /// 列表标题
  ///
  /// 用户为列表设置的自定义名称。
  ///
  /// 示例：
  /// - "朋友"
  /// - "工作相关"
  /// - "科技新闻"
  /// - "iOS 开发者"
  ///
  /// 规则：
  /// - 可以使用任何字符
  /// - 通常限制在 50 个字符以内
  /// - 在同一账户中不要求唯一
  public let title: String
  
  /// 回复显示策略
  ///
  /// 控制列表时间线中如何显示回复。
  ///
  /// 策略说明：
  /// - followed: 显示列表成员对你关注的人的回复
  /// - list: 只显示列表成员之间的回复
  /// - none: 不显示任何回复
  ///
  /// 用途：
  /// - 控制时间线的内容密度
  /// - 减少不相关的回复
  /// - 专注于原创内容
  ///
  /// - Note: 某些旧版本的 Mastodon 可能不支持此功能，此时为 nil
  public let repliesPolicy: RepliesPolicy?
  
  /// 是否独占模式
  ///
  /// 控制列表成员的帖子是否从主时间线隐藏。
  ///
  /// 独占模式说明：
  /// - true: 列表成员的帖子只在列表时间线显示，不在主时间线显示
  /// - false: 列表成员的帖子同时在列表和主时间线显示
  /// - nil: 未设置（默认为 false）
  ///
  /// 使用场景：
  /// - 将高频发帖的账户隔离到专门列表
  /// - 减少主时间线的内容量
  /// - 创建完全独立的内容流
  ///
  /// 示例：
  /// - 将新闻机器人账户设为独占，避免刷屏
  /// - 将工作相关账户隔离，工作时专注查看
  ///
  /// - Note: 这是较新的功能，旧版本 Mastodon 可能不支持
  public let exclusive: Bool?

  /// 回复显示策略枚举
  ///
  /// 定义列表时间线中回复的显示规则。
  ///
  /// 策略详解：
  /// - followed: 显示列表成员对你关注的人的回复
  ///   - 例如：列表中的 Alice 回复了你关注的 Bob，会显示
  ///   - 但 Alice 回复陌生人 Charlie，不会显示
  ///
  /// - list: 只显示列表成员之间的回复
  ///   - 例如：列表中的 Alice 回复列表中的 Bob，会显示
  ///   - 但 Alice 回复列表外的人，不会显示
  ///
  /// - none: 不显示任何回复
  ///   - 只显示列表成员的原创帖子
  ///   - 最干净的时间线，但可能错过重要对话
  ///
  /// 选择建议：
  /// - followed: 平衡模式，适合大多数情况
  /// - list: 适合紧密的小群体
  /// - none: 适合只想看原创内容的场景
  public enum RepliesPolicy: String, Sendable, Codable, CaseIterable, Identifiable {
    /// 策略的唯一标识符
    public var id: String {
      rawValue
    }

    /// 显示对关注者的回复
    case followed
    
    /// 只显示列表成员间的回复
    case list
    
    /// 不显示任何回复
    case none
  }

  /// 初始化列表
  ///
  /// - Parameters:
  ///   - id: 列表 ID
  ///   - title: 列表标题
  ///   - repliesPolicy: 回复显示策略
  ///   - exclusive: 是否独占模式
  public init(
    id: String, title: String, repliesPolicy: RepliesPolicy? = nil, exclusive: Bool? = nil
  ) {
    self.id = id
    self.title = title
    self.repliesPolicy = repliesPolicy
    self.exclusive = exclusive
  }
}

// MARK: - Sendable 一致性

/// List 符合 Sendable 协议
extension List: Sendable {}
