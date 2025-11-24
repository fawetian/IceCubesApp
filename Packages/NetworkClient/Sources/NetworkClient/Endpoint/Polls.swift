// 文件功能：Mastodon 投票 API 端点定义
//
// 核心职责：
// - 定义投票相关的 API 端点
// - 支持获取投票详情
// - 支持投票操作
//
// 技术要点：
// - Polls：枚举类型，定义投票操作
// - 支持单选和多选投票
// - 投票选项使用索引（从 0 开始）
//
// 投票操作类型：
// - poll：获取投票详情
// - vote：提交投票
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：PollView, MastodonClient

import Foundation

/// Mastodon 投票 API 端点
///
/// 定义了投票相关的操作。
///
/// 主要功能：
/// - **获取投票**：查看投票详情和结果
/// - **提交投票**：为投票选项投票
///
/// 投票特性：
/// - 单选或多选
/// - 设置过期时间
/// - 实时更新结果
/// - 匿名投票
///
/// 使用示例：
/// ```swift
/// // 获取投票详情
/// let poll: Poll = try await client.get(
///     endpoint: Polls.poll(id: "123456")
/// )
///
/// // 单选投票（选择第一个选项）
/// let votedPoll: Poll = try await client.post(
///     endpoint: Polls.vote(
///         id: "123456",
///         votes: [0]  // 选项索引从 0 开始
///     )
/// )
///
/// // 多选投票（选择第一和第三个选项）
/// let multiVotedPoll: Poll = try await client.post(
///     endpoint: Polls.vote(
///         id: "123456",
///         votes: [0, 2]
///     )
/// )
///
/// // 检查投票状态
/// if poll.voted {
///     print("你已经投票了")
///     print("你的选择：\(poll.ownVotes ?? [])")
/// }
///
/// if poll.expired {
///     print("投票已结束")
/// } else {
///     print("剩余时间：\(poll.expiresAt)")
/// }
/// ```
///
/// 投票限制：
/// - 每个用户只能投票一次
/// - 投票后无法更改
/// - 投票结束后无法投票
/// - 多选投票的选项数量有限制
///
/// - Note: 投票是匿名的，其他用户看不到你的具体选择
/// - SeeAlso: `Poll` 模型包含投票的完整信息
public enum Polls: Endpoint {
  /// 获取投票详情
  ///
  /// - Parameter id: 投票 ID
  ///
  /// 返回：Poll 对象，包含：
  /// - options: 投票选项和票数
  /// - votesCount: 总投票数
  /// - votersCount: 投票人数（如果可用）
  /// - multiple: 是否允许多选
  /// - expiresAt: 过期时间
  /// - expired: 是否已过期
  /// - voted: 当前用户是否已投票
  /// - ownVotes: 当前用户的选择（如果已投票）
  ///
  /// 使用场景：
  /// - 显示投票界面
  /// - 查看投票结果
  /// - 刷新投票状态
  ///
  /// API 路径：`/api/v1/polls/:id`
  /// HTTP 方法：GET
  case poll(id: String)
  
  /// 提交投票
  ///
  /// - Parameters:
  ///   - id: 投票 ID
  ///   - votes: 选项索引数组（从 0 开始）
  ///
  /// 返回：更新后的 Poll 对象
  ///
  /// 投票规则：
  /// - **单选投票**：votes 数组只能包含一个索引
  /// - **多选投票**：votes 数组可以包含多个索引
  /// - 索引从 0 开始，对应选项的顺序
  /// - 每个用户只能投票一次
  /// - 投票后无法更改
  ///
  /// 选项索引示例：
  /// ```
  /// 投票问题："你最喜欢哪个编程语言？"
  /// 选项：
  ///   [0] Swift
  ///   [1] Kotlin
  ///   [2] Rust
  ///   [3] Go
  ///
  /// 选择 Swift：votes = [0]
  /// 选择 Swift 和 Rust：votes = [0, 2]
  /// ```
  ///
  /// 错误情况：
  /// - 投票已结束：返回错误
  /// - 已经投过票：返回错误
  /// - 单选投票提交多个选项：返回错误
  /// - 选项索引超出范围：返回错误
  ///
  /// 使用场景：
  /// - 用户点击投票选项
  /// - 提交投票表单
  /// - 参与社区投票
  ///
  /// API 路径：`/api/v1/polls/:id/votes`
  /// HTTP 方法：POST
  case vote(id: String, votes: [Int])

  public func path() -> String {
    switch self {
    case let .poll(id):
      "polls/\(id)"
    case let .vote(id, _):
      "polls/\(id)/votes"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .vote(_, votes):
      var params: [URLQueryItem] = []
      for vote in votes {
        params.append(.init(name: "choices[]", value: "\(vote)"))
      }
      return params

    default:
      return nil
    }
  }
}
