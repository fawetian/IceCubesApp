/*
 * InstanceSocialClient.swift
 * IceCubesApp - 实例社交客户端
 *
 * 功能描述：
 * 与 instances.social API 集成的客户端，用于搜索和发现 Mastodon 实例
 * 提供实例列表获取和关键词搜索功能，支持按用户数和状态数排序
 *
 * 技术点：
 * 1. URLSession 网络请求 - HTTP API 调用
 * 2. JSONDecoder 解码 - JSON 数据解析
 * 3. Sendable 协议 - 并发安全标记
 * 4. 字符串处理 - 关键词清理和URL构建
 * 5. 数组排序 - 多级排序算法
 * 6. Bearer 认证 - API 访问授权
 * 7. URL 查询参数 - 动态API参数构建
 * 8. 错误处理 - 优雅的异常处理
 * 9. 数据模型映射 - Response 到 InstanceSocial 转换
 * 10. 扩展方法 - Array 排序扩展
 *
 * 技术点详解：
 * - URLSession：使用系统网络库进行 HTTP 请求
 * - JSONDecoder：将 JSON 响应解码为 Swift 对象
 * - Sendable：标记类型在并发环境中安全使用
 * - Bearer 认证：使用预设的 API 密钥进行身份验证
 * - 查询参数：动态构建搜索和列表 API 的参数
 * - 多级排序：按用户数、状态数和关键词匹配进行排序
 * - keyDecodingStrategy：JSON 键名从 snake_case 转换为 camelCase
 * - 字符串清理：去除空白字符，确保搜索准确性
 * - 错误恢复：网络或解析失败时返回空数组
 * - 扩展设计：将排序逻辑封装为数组扩展方法
 */

// 导入 Foundation 框架，提供网络和数据处理功能
import Foundation
// 导入 Models 模块，提供 InstanceSocial 数据模型
import Models

// 实例社交网站客户端，用于搜索 Mastodon 实例
public struct InstanceSocialClient: Sendable {
  // API 授权令牌，用于访问 instances.social API
  private let authorization =
    "Bearer 8a4xx3D7Hzu1aFnf18qlkH8oU0oZ5ulabXxoS2FtQtwOy8G0DGQhr5PjTIjBnYAmFrSBuE2CcASjFocxJBonY8XGbLySB7MXd9ssrwlRHUXTQh3Z578lE1OfUtafvhML"
  // 获取实例列表的 API 端点
  private let listEndpoint =
    "https://instances.social/api/1.0/instances/list?count=1000&include_closed=false&include_dead=false&min_active_users=500"
  // 搜索实例的 API 端点
  private let searchEndpoint = "https://instances.social/api/1.0/instances/search"

  // API 响应数据结构
  struct Response: Decodable {
    // 实例数组
    let instances: [InstanceSocial]
  }

  // 公共初始化方法
  public init() {}

  // 根据关键词获取 Mastodon 实例列表
  public func fetchInstances(keyword: String) async -> [InstanceSocial] {
    // 清理关键词，去除首尾空白字符
    let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

    // 根据关键词是否为空选择不同的 API 端点
    let endpoint = keyword.isEmpty ? listEndpoint : searchEndpoint + "?q=\(keyword)"

    // 创建 URL，如果创建失败返回空数组
    guard let url = URL(string: endpoint) else { return [] }

    // 创建网络请求
    var request = URLRequest(url: url)
    // 设置授权头
    request.setValue(authorization, forHTTPHeaderField: "Authorization")

    // 执行网络请求，失败时返回空数组
    guard let (data, _) = try? await URLSession.shared.data(for: request) else { return [] }

    // 创建 JSON 解码器
    let decoder = JSONDecoder()
    // 设置键名转换策略
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    // 解码响应数据，失败时返回空数组
    guard let response = try? decoder.decode(Response.self, from: data) else { return [] }

    // 对结果进行排序并返回
    let result = response.instances.sorted(by: keyword)
    return result
  }
}

// 扩展 InstanceSocial 数组，添加排序功能
extension Array where Self.Element == InstanceSocial {
  // 根据关键词对实例进行排序
  fileprivate func sorted(by keyword: String) -> Self {
    // 清理关键词
    let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    // 创建数组副本
    var newArray = self

    // 第一级排序：按用户数量降序排列
    newArray.sort { (lhs: InstanceSocial, rhs: InstanceSocial) in
      // 尝试将字符串转换为整数
      guard
        let lhsNumber = Int(lhs.users),
        let rhsNumber = Int(rhs.users)
      else { return false }

      // 用户数多的排在前面
      return lhsNumber > rhsNumber
    }

    // 第二级排序：按状态数量降序排列
    newArray.sort { (lhs: InstanceSocial, rhs: InstanceSocial) in
      // 尝试将字符串转换为整数
      guard
        let lhsNumber = Int(lhs.statuses),
        let rhsNumber = Int(rhs.statuses)
      else { return false }

      // 状态数多的排在前面
      return lhsNumber > rhsNumber
    }

    // 第三级排序：如果有关键词，匹配的实例排在前面
    if !keyword.isEmpty {
      newArray.sort { (lhs: InstanceSocial, rhs: InstanceSocial) in
        // 如果左边实例包含关键词而右边不包含
        if lhs.name.contains(keyword),
          !rhs.name.contains(keyword)
        {
          // 左边实例排在前面
          return true
        }

        // 其他情况保持原顺序
        return false
      }
    }

    // 返回排序后的数组
    return newArray
  }
}
