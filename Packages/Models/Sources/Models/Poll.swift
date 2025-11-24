// 文件功能：Mastodon 投票数据模型
//
// 核心职责：
// - 表示帖子中的投票功能
// - 包含投票选项、票数、截止时间等信息
// - 支持单选和多选投票
// - 跟踪用户的投票状态
//
// 技术要点：
// - Option：投票选项，包含标题和票数
// - multiple：是否允许多选
// - expired：投票是否已结束
// - ownVotes：当前用户的投票选择
// - NullableString：处理可能为 null 的日期字符串
//
// 投票规则：
// - 每个帖子最多一个投票
// - 可以设置 2-4 个选项
// - 可以设置截止时间（5分钟到7天）
// - 投票结束后不能再投票
// - 某些实例允许查看投票者
//
// 依赖关系：
// - 依赖：ServerDate, Foundation
// - 被依赖：Status, StatusPollView

import Foundation

/// Mastodon 投票数据模型
///
/// 表示帖子中的投票功能，包括：
/// - 投票选项和票数
/// - 投票状态（进行中/已结束）
/// - 用户的投票记录
/// - 投票类型（单选/多选）
///
/// 投票特性：
/// - 支持 2-4 个选项
/// - 可以设置截止时间
/// - 支持单选或多选
/// - 实时更新票数
/// - 投票结束后显示最终结果
///
/// 使用示例：
/// ```swift
/// if let poll = status.poll {
///     if poll.expired {
///         showPollResults(poll)
///     } else {
///         showPollVoting(poll)
///     }
/// }
/// ```
public struct Poll: Codable, Equatable, Hashable {
  /// 相等性比较
  ///
  /// 只比较 ID，因为投票的其他属性（如票数）会实时变化
  public static func == (lhs: Poll, rhs: Poll) -> Bool {
    lhs.id == rhs.id
  }

  /// 哈希值计算
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  /// 投票选项
  ///
  /// 表示投票中的一个选项。
  ///
  /// 特性：
  /// - 每个投票有 2-4 个选项
  /// - 选项按顺序显示
  /// - 显示选项文本和票数
  /// - 投票结束后显示百分比
  public struct Option: Identifiable, Codable {
    /// 自定义编码键
    ///
    /// 因为 id 是客户端生成的，不需要编码到 JSON
    enum CodingKeys: String, CodingKey {
      case title, votesCount
    }

    /// 选项的唯一标识符
    ///
    /// 客户端生成的 UUID，用于 SwiftUI 列表渲染。
    /// 不是 API 返回的字段。
    public var id = UUID().uuidString
    
    /// 选项文本
    ///
    /// 用户创建投票时输入的选项内容。
    /// 最大长度通常为 50 个字符。
    public let title: String
    
    /// 该选项的票数
    ///
    /// 实时更新的票数。
    ///
    /// 为什么是可选值？
    /// - 某些实例可能隐藏票数
    /// - 投票进行中时可能不显示实时票数
    /// - 只有投票结束后才显示
    public let votesCount: Int?
  }

  // MARK: - 基本信息
  
  /// 投票的唯一标识符
  public let id: String
  
  /// 投票截止时间
  ///
  /// 使用 NullableString 包装，因为 API 可能返回 null。
  ///
  /// 为什么需要特殊处理？
  /// - Mastodon API 在某些情况下返回 null 而不是日期字符串
  /// - 需要优雅地处理这种情况
  /// - NullableString 会捕获解码错误并返回 nil
  public let expiresAt: NullableString
  
  /// 投票是否已结束
  ///
  /// 判断依据：
  /// - 已到达截止时间
  /// - 或者发帖者手动结束投票
  ///
  /// 影响：
  /// - 已结束的投票不能再投票
  /// - 显示最终结果和百分比
  /// - UI 显示"已结束"标记
  public let expired: Bool
  
  /// 是否允许多选
  ///
  /// - true: 可以选择多个选项
  /// - false: 只能选择一个选项（单选）
  ///
  /// UI 差异：
  /// - 多选：显示复选框
  /// - 单选：显示单选按钮
  public let multiple: Bool
  
  // MARK: - 统计数据
  
  /// 总票数
  ///
  /// 所有选项的票数之和。
  ///
  /// - Note: 如果是多选投票，一个人可以投多票，所以 votesCount 可能大于 votersCount
  public let votesCount: Int
  
  /// 投票人数
  ///
  /// 参与投票的用户数量。
  ///
  /// 为什么是可选值？
  /// - 根据 Mastodon API 文档，单选投票时可能为 null
  /// - 实际上通常都有值，但为了安全起见设为可选
  /// - 使用 safeVotersCount 获取安全的值
  public let votersCount: Int?
  
  /// 安全的投票人数
  ///
  /// 如果 votersCount 为 nil，使用 votesCount 作为后备值。
  ///
  /// 为什么需要这个？
  /// - API 文档说单选投票时 votersCount 可能为 null
  /// - 单选投票时，votesCount 等于 votersCount
  /// - 提供一个总是有值的属性，避免处理可选值
  public var safeVotersCount: Int {
    votersCount ?? votesCount
  }
  
  // MARK: - 用户投票状态
  
  /// 当前用户是否已投票
  ///
  /// - true: 已投票
  /// - false: 未投票
  /// - nil: 未登录或无法确定
  ///
  /// 用途：
  /// - 决定显示投票界面还是结果界面
  /// - 已投票的用户可以看到实时结果
  /// - 未投票的用户看到投票按钮
  public let voted: Bool?
  
  /// 当前用户的投票选择
  ///
  /// 数组中的数字是选项的索引（从 0 开始）。
  ///
  /// 示例：
  /// - [0]: 投了第一个选项
  /// - [1, 2]: 投了第二和第三个选项（多选）
  /// - nil: 未投票或未登录
  ///
  /// 用途：
  /// - 高亮显示用户投的选项
  /// - 允许用户查看自己的投票
  /// - 某些实例允许修改投票
  public let ownVotes: [Int]?
  
  /// 投票选项数组
  ///
  /// 包含 2-4 个选项，按创建顺序排列。
  public let options: [Option]
}

/// 可空字符串包装器
///
/// 用于处理 Mastodon API 中可能为 null 的日期字符串。
///
/// 问题背景：
/// - Mastodon API 的某些日期字段可能返回 null
/// - 标准的 Codable 解码会因为 null 而失败
/// - 需要一个包装器来优雅地处理这种情况
///
/// 解决方案：
/// - 尝试解码为 ServerDate
/// - 如果失败（遇到 null），设置 value 为 nil
/// - 不会导致整个对象解码失败
///
/// 使用场景：
/// - Poll.expiresAt: 投票截止时间可能为 null
/// - 其他可能为 null 的日期字段
public struct NullableString: Codable, Equatable, Hashable {
  /// 解码后的日期值
  ///
  /// - 如果 API 返回有效日期字符串，包含 ServerDate
  /// - 如果 API 返回 null，为 nil
  public let value: ServerDate?

  /// 自定义解码
  ///
  /// 尝试解码为 ServerDate，失败时返回 nil 而不是抛出错误。
  ///
  /// 实现逻辑：
  /// 1. 尝试解码为 ServerDate
  /// 2. 如果成功，value 包含日期
  /// 3. 如果失败（遇到 null），value 为 nil
  /// 4. 不会抛出错误，确保整个对象能成功解码
  public init(from decoder: Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()
      value = try container.decode(ServerDate.self)
    } catch {
      value = nil
    }
  }
}

// MARK: - Sendable 一致性

/// Poll 符合 Sendable 协议
extension Poll: Sendable {}

/// Option 符合 Sendable 协议
extension Poll.Option: Sendable {}

/// NullableString 符合 Sendable 协议
extension NullableString: Sendable {}
