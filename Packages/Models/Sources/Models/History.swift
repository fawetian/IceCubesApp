// 文件功能：Mastodon 历史数据模型
//
// 核心职责：
// - 表示标签或内容的历史统计数据
// - 按天记录使用情况
// - 包含账户数和使用次数
// - 支持趋势分析
//
// 技术要点：
// - History：单日的统计数据
// - 使用日期作为 ID
// - 字符串类型的数值（API 返回格式）
// - Sendable 并发安全
//
// 历史数据：
// - 日期：统计的日期
// - 账户数：使用此标签的账户数
// - 使用次数：标签被使用的总次数
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：Tag, TrendingView

import Foundation

/// 历史统计数据模型
///
/// 表示标签或内容按天的历史统计数据。
///
/// 主要用途：
/// - **趋势分析**：显示标签的使用趋势
/// - **统计图表**：绘制使用情况曲线
/// - **热度判断**：根据历史数据判断热度
///
/// 使用场景：
/// - 标签详情页的趋势图
/// - 热门标签的排序
/// - 统计分析
///
/// 示例：
/// ```swift
/// // 显示标签的历史趋势
/// ForEach(tag.history ?? []) { history in
///     VStack(alignment: .leading) {
///         Text(history.day)
///             .font(.caption)
///         HStack {
///             Text("\(history.uses) 次使用")
///             Text("\(history.accounts) 个账户")
///         }
///         .font(.caption2)
///         .foregroundColor(.secondary)
///     }
/// }
///
/// // 计算总使用次数
/// let totalUses = tag.history?.compactMap { Int($0.uses) }.reduce(0, +) ?? 0
/// ```
public struct History: Codable, Identifiable, Sendable, Equatable, Hashable {
  public var id: String {
    day
  }

  public let day: String
  public let accounts: String
  public let uses: String
}
