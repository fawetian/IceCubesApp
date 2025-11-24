// 文件功能：Mastodon 标签（Hashtag）数据模型
//
// 核心职责：
// - 表示 Mastodon 的标签（#hashtag）
// - 包含标签的使用历史和趋势数据
// - 支持关注标签功能
// - 提供精选标签（个人资料置顶）
//
// 技术要点：
// - Tag：普通标签，包含历史数据和关注状态
// - FeaturedTag：精选标签，显示在个人资料页
// - History：标签的历史使用数据（每日统计）
// - 自定义 Codable：处理可选字段和类型不匹配
//
// 标签功能：
// - 点击标签查看相关帖子
// - 关注标签，在时间线中看到相关内容
// - 查看标签的使用趋势
// - 在个人资料中置顶标签
//
// 依赖关系：
// - 依赖：History（历史数据模型）
// - 被依赖：Status, Timeline, Explore

import Foundation

/// Mastodon 标签数据模型
///
/// 表示 Mastodon 中的标签（Hashtag），包括：
/// - 标签名称和 URL
/// - 关注状态
/// - 使用历史和趋势数据
///
/// 标签特性：
/// - 格式：#标签名（不区分大小写）
/// - 可以关注标签，在时间线中看到相关内容
/// - 显示标签的使用趋势（过去 7 天）
/// - 支持搜索和发现热门标签
///
/// 使用示例：
/// ```swift
/// // 显示标签信息
/// Text("#\(tag.name)")
/// Text("过去 7 天使用 \(tag.totalUses) 次")
/// Text("\(tag.totalAccounts) 人使用")
///
/// // 关注标签
/// if !tag.following {
///     Button("关注") {
///         await followTag(tag.name)
///     }
/// }
/// ```
public struct Tag: Codable, Identifiable, Equatable, Hashable {
  /// 哈希值计算
  ///
  /// 只使用标签名称计算哈希，因为标签名称是唯一标识符
  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }

  /// 相等性比较
  ///
  /// 比较标签名称和关注状态。
  ///
  /// 为什么要比较 following？
  /// - 关注状态变化时需要更新 UI
  /// - 用户可能关注或取消关注标签
  /// - 需要检测这种变化以刷新视图
  public static func == (lhs: Tag, rhs: Tag) -> Bool {
    lhs.name == rhs.name && lhs.following == rhs.following
  }

  /// 标签的唯一标识符
  ///
  /// 使用标签名称作为 ID，因为标签名称在 Mastodon 中是唯一的。
  ///
  /// - Note: 标签名称不区分大小写，但保留原始大小写
  public var id: String {
    name
  }

  // MARK: - 基本信息
  
  /// 标签名称
  ///
  /// 不包含 # 符号的标签名称。
  ///
  /// 示例：
  /// - "SwiftUI"（不是 "#SwiftUI"）
  /// - "iOS开发"
  /// - "Mastodon"
  ///
  /// 规则：
  /// - 不区分大小写（#swift 和 #Swift 是同一个标签）
  /// - 但保留原始大小写用于显示
  /// - 不能包含空格和特殊字符
  public let name: String
  
  /// 标签的 Web URL
  ///
  /// 可以在浏览器中打开的标签页面链接。
  ///
  /// 格式：https://instance.com/tags/标签名
  public let url: String
  
  /// 当前用户是否关注了这个标签
  ///
  /// 关注标签的效果：
  /// - 包含该标签的帖子会出现在你的时间线中
  /// - 类似于关注用户，但是关注话题
  /// - 可以在设置中管理关注的标签
  ///
  /// - Note: 如果未登录或 API 未返回此字段，默认为 false
  public let following: Bool
  
  /// 标签的历史使用数据
  ///
  /// 包含过去 7 天的每日使用统计。
  ///
  /// 用途：
  /// - 显示标签的使用趋势
  /// - 绘制趋势图表
  /// - 判断标签是否热门
  ///
  /// - Note: 某些 API 端点可能不返回历史数据，此时为空数组
  public let history: [History]

  // MARK: - 计算属性
  
  /// 总使用次数
  ///
  /// 计算过去 7 天内该标签被使用的总次数。
  ///
  /// 计算方式：
  /// - 遍历 history 数组
  /// - 将每天的 uses 相加
  /// - 返回总和
  ///
  /// 用途：
  /// - 显示标签的热度
  /// - 排序热门标签
  /// - 判断标签是否值得关注
  public var totalUses: Int {
    return history.compactMap { Int($0.uses) }.reduce(0, +)
  }

  /// 总使用人数
  ///
  /// 计算过去 7 天内使用该标签的不同用户数量。
  ///
  /// 计算方式：
  /// - 遍历 history 数组
  /// - 将每天的 accounts 相加
  /// - 返回总和
  ///
  /// 用途：
  /// - 显示标签的影响范围
  /// - 判断标签的活跃度
  /// - 与 totalUses 结合判断标签质量
  ///
  /// - Note: 一个用户可能在多天使用同一标签，所以这个数字可能有重复
  public var totalAccounts: Int {
    return history.compactMap { Int($0.accounts) }.reduce(0, +)
  }

  /// 自定义解码
  ///
  /// 处理可选字段和缺失字段的情况。
  ///
  /// 为什么需要自定义解码？
  /// - history 字段可能不存在（某些 API 端点不返回）
  /// - following 字段可能不存在（未登录时）
  /// - 需要为这些字段提供默认值
  /// - 避免解码失败导致整个对象无法使用
  ///
  /// 处理逻辑：
  /// 1. name 和 url 是必需的，直接解码
  /// 2. history 如果不存在，使用空数组
  /// 3. following 如果不存在，使用 false
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    url = try container.decode(String.self, forKey: .url)
    
    // 尝试解码 history，如果字段不存在则使用空数组
    do {
      history = try container.decode([History].self, forKey: .history)
    } catch DecodingError.keyNotFound {
      history = []
    }
    
    // 尝试解码 following，如果字段不存在则使用 false
    do {
      following = try container.decode(Bool.self, forKey: .following)
    } catch DecodingError.keyNotFound {
      following = false
    }
  }
}

/// 精选标签数据模型
///
/// 表示用户在个人资料中置顶的标签。
///
/// 精选标签特性：
/// - 显示在个人资料页的显眼位置
/// - 显示该用户使用该标签的帖子数量
/// - 最多可以置顶 10 个标签
/// - 帮助访客快速了解用户的兴趣
///
/// 使用场景：
/// - 个人资料页显示精选标签
/// - 点击标签查看该用户的相关帖子
/// - 管理自己的精选标签
///
/// 使用示例：
/// ```swift
/// ForEach(featuredTags) { tag in
///     HStack {
///         Text("#\(tag.name)")
///         Spacer()
///         Text("\(tag.statusesCountInt) 条帖子")
///     }
/// }
/// ```
public struct FeaturedTag: Codable, Identifiable {
  /// 精选标签的唯一标识符
  public let id: String
  
  /// 标签名称（不包含 # 符号）
  public let name: String
  
  /// 标签的 URL
  public let url: URL
  
  /// 该用户使用该标签的帖子数量（字符串格式）
  ///
  /// 为什么是字符串？
  /// - Mastodon API 可能返回字符串或数字
  /// - 使用字符串类型兼容两种情况
  /// - 使用 statusesCountInt 获取数字值
  public let statusesCount: String
  
  /// 帖子数量的整数值
  ///
  /// 将 statusesCount 字符串转换为整数。
  ///
  /// 用途：
  /// - 排序精选标签
  /// - 显示数字
  /// - 进行数值比较
  ///
  /// - Note: 如果转换失败，返回 0
  public var statusesCountInt: Int {
    Int(statusesCount) ?? 0
  }

  /// 编码键
  private enum CodingKeys: String, CodingKey {
    case id, name, url, statusesCount
  }

  /// 自定义解码
  ///
  /// 处理 statusesCount 可能是字符串或数字的情况。
  ///
  /// 为什么需要自定义解码？
  /// - 不同 Mastodon 实例可能返回不同类型
  /// - 有些返回字符串 "42"
  /// - 有些返回数字 42
  /// - 需要兼容两种情况
  ///
  /// 处理逻辑：
  /// 1. 先尝试解码为字符串
  /// 2. 如果失败（类型不匹配），解码为数字再转为字符串
  /// 3. 确保 statusesCount 总是字符串类型
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    url = try container.decode(URL.self, forKey: .url)
    
    // 尝试解码为字符串，如果失败则解码为数字再转为字符串
    do {
      statusesCount = try container.decode(String.self, forKey: .statusesCount)
    } catch DecodingError.typeMismatch {
      statusesCount = try String(container.decode(Int.self, forKey: .statusesCount))
    }
  }
}

// MARK: - Sendable 一致性

/// Tag 符合 Sendable 协议
extension Tag: Sendable {}

/// FeaturedTag 符合 Sendable 协议
extension FeaturedTag: Sendable {}
