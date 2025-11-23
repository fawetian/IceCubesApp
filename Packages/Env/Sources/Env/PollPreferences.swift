// 文件功能：投票偏好设置枚举，定义Mastodon投票的投票频率选项，支持单次投票和多次投票。
// 相关技术点：
// - 枚举类型：PollVotingFrequency定义投票频率选项。
// - String原始值：字符串原始值用于API通信。
// - CaseIterable：自动生成所有枚举案例的集合。
// - LocalizedStringKey：本地化字符串键支持多语言。
// - 计算属性：canVoteMultipleTimes和displayString的动态计算。
// - 布尔逻辑：投票规则的逻辑判断。
// - 投票系统：Mastodon平台的投票功能支持。
// - 用户界面：为投票创建界面提供选项。
//
// 技术点详解：
// 1. enum PollVotingFrequency：投票频率的枚举定义。
// 2. String原始值：便于与API的JSON数据交换。
// 3. CaseIterable：支持遍历所有投票频率选项。
// 4. computed property：根据枚举值计算相关属性。
// 5. switch语句：模式匹配处理不同投票频率。
// 6. LocalizedStringKey：支持系统自动本地化。
// 7. Bool返回值：简化投票规则的判断逻辑。
// 8. 多语言支持：displayString提供本地化显示。
// 导入基础库，基本数据类型
import Foundation
// 导入SwiftUI框架，LocalizedStringKey支持
import SwiftUI

// 投票频率枚举，定义Mastodon投票的投票次数规则
public enum PollVotingFrequency: String, CaseIterable {
  // 单次投票（每个用户只能投一票）
  case oneVote = "one-vote"
  // 多次投票（每个用户可以投多票）
  case multipleVotes = "multiple-votes"

  // 计算属性：判断是否可以多次投票
  public var canVoteMultipleTimes: Bool {
    switch self {
    case .multipleVotes:
      // 多次投票模式返回true
      true
    case .oneVote:
      // 单次投票模式返回false
      false
    }
  }

  // 计算属性：返回投票频率的本地化显示字符串
  public var displayString: LocalizedStringKey {
    switch self {
    case .oneVote:
      // 单次投票的显示文本
      "env.poll-vote-frequency.one"
    case .multipleVotes:
      // 多次投票的显示文本
      "env.poll-vote-frequency.multiple"
    }
  }
}
