/*
 * String.swift
 * IceCubesApp - String 扩展
 * 
 * 功能描述：
 * 扩展 String 类型，提供 HTML 转义和 Base64 URL 解码功能，用于处理网络数据中的编码转换
 * 支持将 HTML 实体转换为原始字符，以及 URL 安全 Base64 到标准 Base64 的转换
 *
 * 技术点：
 * 1. Extension 扩展 - 为现有类型添加新功能
 * 2. HTML 实体转义 - 将 HTML 实体转换为原始字符
 * 3. Base64 URL 解码 - 将 URL 安全的 Base64 转换为标准 Base64
 * 4. 字符串替换 - replacingOccurrences 方法
 * 5. 字符串追加 - append 方法
 * 6. 模运算 - % 操作符计算余数
 * 7. 字符串重复 - String(repeating:count:)
 * 8. 方法链调用 - 连续的字符串操作
 * 9. 字符填充 - Base64 编码长度补齐
 * 10. 字符串处理 - 多种字符串操作技术
 *
 * 技术点详解：
 * - Extension：Swift 的扩展机制，为现有类型添加新方法和计算属性
 * - HTML 实体转义：处理 &amp;、&lt;、&gt;、&quot;、&apos;、&#39; 等实体
 * - URL 安全字符还原：将 URL 安全的 - 和 _ 还原为标准 Base64 的 + 和 /
 * - Base64 填充：根据长度添加 = 字符补齐，确保长度是 4 的倍数
 * - 模运算：使用 % 4 计算需要填充的字符数量
 * - 方法链：连续调用 replacingOccurrences 实现多个替换操作
 * - 字符串重复：使用 String(repeating:count:) 生成填充字符
 * - 网络数据处理：处理来自 API 的编码数据
 * - 字符集转换：在不同编码标准间进行转换
 * - 安全编码：处理 URL 安全的编码格式
 */

// 导入 Foundation 框架，提供基础数据类型和字符串处理功能
import Foundation

// 扩展 String 类型，添加转义和编码转换功能
extension String {
  // HTML 转义方法，将 HTML 实体转换为原始字符
  public func escape() -> String {
    // 将 &amp; 转换为 &
    replacingOccurrences(of: "&amp;", with: "&")
      // 将 &lt; 转换为 <
      .replacingOccurrences(of: "&lt;", with: "<")
      // 将 &gt; 转换为 >
      .replacingOccurrences(of: "&gt;", with: ">")
      // 将 &quot; 转换为 "
      .replacingOccurrences(of: "&quot;", with: "\"")
      // 将 &apos; 转换为 '
      .replacingOccurrences(of: "&apos;", with: "'")
      // 将 &#39; 转换为 '
      .replacingOccurrences(of: "&#39;", with: "'")
  }

  // 将 URL 安全的 Base64 转换为标准 Base64
  public func URLSafeBase64ToBase64() -> String {
    // 先将 URL 安全字符替换为标准 Base64 字符
    var base64 = replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    // 计算字符串长度模 4 的余数
    let countMod4 = count % 4

    // 如果长度不是 4 的倍数，需要添加填充字符
    if countMod4 != 0 {
      // 添加相应数量的 = 字符作为填充
      base64.append(String(repeating: "=", count: 4 - countMod4))
    }

    // 返回标准 Base64 编码字符串
    return base64
  }
}
