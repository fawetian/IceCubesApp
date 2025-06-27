/*
 * DeepLClient.swift
 * IceCubesApp - DeepL 翻译服务客户端
 *
 * 功能描述：
 * 与 DeepL 翻译 API 集成的客户端，提供文本翻译服务
 * 支持免费和付费版本的 API，自动选择合适的端点进行翻译
 *
 * 技术点：
 * 1. URLSession 网络请求 - HTTP API 调用
 * 2. JSONDecoder 解码 - JSON 数据解析
 * 3. Sendable 协议 - 并发安全标记
 * 4. URLComponents - URL 组件构建
 * 5. 表单数据编码 - application/x-www-form-urlencoded
 * 6. 条件端点选择 - 免费/付费 API 切换
 * 7. 自定义错误类型 - DeepLError 错误处理
 * 8. 计算属性 - 动态配置计算
 * 9. 字符串解码 - URL 百分号编码处理
 * 10. 异步翻译 - async/await 异步操作
 *
 * 技术点详解：
 * - URLSession：使用系统网络库进行 HTTP 请求
 * - JSONDecoder：将 JSON 响应解码为 Response 对象
 * - Sendable：标记类型在并发环境中安全使用
 * - URLComponents：安全构建带查询参数的 URL
 * - 表单编码：使用 application/x-www-form-urlencoded 格式
 * - API 端点切换：根据用户 API 类型选择不同端点
 * - keyDecodingStrategy：JSON 键名从 snake_case 转换
 * - removingPercentEncoding：解码 URL 编码的文本
 * - 错误处理：自定义 DeepLError 提供清晰的错误信息
 * - 授权头：使用 DeepL-Auth-Key 格式的认证
 */

// 导入 Foundation 框架，提供网络和数据处理功能
import Foundation
// 导入 Models 模块，提供 Translation 数据模型
import Models

// DeepL 翻译服务客户端
public struct DeepLClient: Sendable {
  // DeepL 客户端自定义错误类型
  public enum DeepLError: Error {
    // 未找到翻译结果
    case notFound
  }

  // 用户的 DeepL API 密钥
  private var deeplUserAPIKey: String?
  // 是否使用免费版 API
  private var deeplUserAPIFree: Bool

  // 计算属性：根据 API 类型构建端点 URL
  private var endpoint: String {
    "https://api\(deeplUserAPIFree && (deeplUserAPIKey != nil) ? "-free" : "").deepl.com/v2/translate"
  }

  // 计算属性：构建授权头的值
  private var authorizationHeaderValue: String {
    "DeepL-Auth-Key \(deeplUserAPIKey ?? "")"
  }

  // DeepL API 响应数据结构
  public struct Response: Decodable {
    // 翻译结果数据结构
    public struct Translation: Decodable {
      // 检测到的源语言
      public let detectedSourceLanguage: String
      // 翻译后的文本
      public let text: String
    }

    // 翻译结果数组
    public let translations: [Translation]
  }

  // 私有计算属性：JSON 解码器配置
  private var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    // 设置键名转换策略，从 snake_case 转换为 camelCase
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  // 初始化方法
  public init(userAPIKey: String?, userAPIFree: Bool) {
    // 设置用户 API 密钥
    deeplUserAPIKey = userAPIKey
    // 设置是否使用免费版
    deeplUserAPIFree = userAPIFree
  }

  // 执行翻译请求
  public func request(target: String, text: String) async throws -> Translation {
    // 创建 URL 组件
    var components = URLComponents(string: endpoint)!
    // 创建查询参数数组
    var queryItems: [URLQueryItem] = []
    // 添加要翻译的文本参数
    queryItems.append(.init(name: "text", value: text))
    // 添加目标语言参数（转为大写）
    queryItems.append(.init(name: "target_lang", value: target.uppercased()))
    // 设置查询参数
    components.queryItems = queryItems

    // 创建网络请求
    var request = URLRequest(url: components.url!)
    // 设置 HTTP 方法为 POST
    request.httpMethod = "POST"
    // 设置授权头
    request.setValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
    // 设置内容类型为表单编码
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    // 执行网络请求
    let (result, _) = try await URLSession.shared.data(for: request)
    // 解码响应数据
    let response = try decoder.decode(Response.self, from: result)

    // 获取第一个翻译结果
    if let translation = response.translations.first {
      // 创建并返回 Translation 对象
      return .init(
        // 翻译内容（移除 URL 编码）
        content: translation.text.removingPercentEncoding ?? "",
        // 检测到的源语言
        detectedSourceLanguage: translation.detectedSourceLanguage,
        // 翻译服务提供商
        provider: "DeepL.com")
    }
    // 如果没有翻译结果，抛出未找到错误
    throw DeepLError.notFound
  }
}
