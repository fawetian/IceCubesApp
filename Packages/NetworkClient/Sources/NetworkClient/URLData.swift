/*
 * URLData.swift
 * IceCubesApp - Data URL 编码扩展
 *
 * 功能描述：
 * 扩展 Data 类型，提供 Base64 URL 编码功能，用于生成 URL 安全的 Base64 编码字符串
 * 符合 RFC 4648 Base64url 编码规范，确保编码结果在 URL 中安全使用
 *
 * 技术点：
 * 1. Extension 扩展 - 为现有类型添加新功能
 * 2. Base64 编码 - 数据的 Base64 编码转换
 * 3. URL 安全编码 - 替换 Base64 中的 URL 不安全字符
 * 4. 字符串替换 - replacingOccurrences 方法
 * 5. 方法链调用 - 连续的字符串操作
 * 6. RFC 4648 标准 - Base64url 编码规范
 * 7. 字符映射 - URL 安全字符转换
 * 8. 填充移除 - 去除 Base64 填充字符
 * 9. 数据编码 - 二进制数据到文本的转换
 * 10. 网络安全 - URL 传输安全处理
 *
 * 技术点详解：
 * - Extension：Swift 的扩展机制，为 Data 类型添加编码方法
 * - base64EncodedString()：Foundation 提供的 Base64 编码方法
 * - URL 安全字符替换：+ → -、/ → _，避免 URL 解析问题
 * - 填充字符移除：移除 = 字符，简化 URL 长度
 * - base64UrlEncodedString：符合 RFC 4648 Base64url 标准
 * - 方法链：连续调用 replacingOccurrences 实现多个替换
 * - URL 编码标准：确保编码结果在 URL 查询参数中安全
 * - 字符集安全：避免 URL 保留字符引起的问题
 * - 编码优化：生成更紧凑的 URL 安全编码
 * - 网络传输：适用于 JWT、API 参数等场景
 */

// 导入 Foundation 框架，提供 Data 类型和 Base64 编码功能
import Foundation

// 扩展 Data 类型，添加 URL 安全的 Base64 编码功能
extension Data {
  // 生成 URL 安全的 Base64 编码字符串
  func base64UrlEncodedString() -> String {
    // 先进行标准 Base64 编码
    base64EncodedString()
      // 将 + 替换为 -（URL 安全）
      .replacingOccurrences(of: "+", with: "-")
      // 将 / 替换为 _（URL 安全）
      .replacingOccurrences(of: "/", with: "_")
      // 移除填充字符 =（URL 安全）
      .replacingOccurrences(of: "=", with: "")
  }
}
