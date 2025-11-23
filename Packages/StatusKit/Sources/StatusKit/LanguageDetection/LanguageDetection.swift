/*
 * LanguageDetection.swift
 * IceCubesApp - 语言检测
 *
 * 功能描述：
 * 使用 NaturalLanguage 框架自动检测文本内容的语言类型
 * 过滤掉社交媒体特有的符号（标签、表情、提及），提高检测准确性
 *
 * 技术点：
 * 1. NaturalLanguage 框架 - 苹果的自然语言处理框架
 * 2. 正则表达式 - Regex 模式匹配和文本处理
 * 3. 字符串处理 - split、joined、trimmingCharacters
 * 4. 置信度算法 - 基于概率的语言识别
 * 5. 文本预处理 - 去除噪音提高检测精度
 * 6. 函数式编程 - 纯函数设计模式
 * 7. 可选值处理 - Optional 返回类型
 * 8. 数组操作 - map、reduce 等高阶函数
 * 9. 私有函数 - 模块内部实现细节封装
 * 10. Foundation 字符集 - 空白字符处理
 *
 * 技术点详解：
 * - NLLanguageRecognizer：核心语言识别器，分析文本语言特征
 * - Regex 过滤：移除 # 标签、: 表情、@ 提及等社交媒体噪音
 * - 文本清理：保留纯语言内容，提高识别准确性
 * - 置信度阈值：只在 85% 以上置信度时返回结果
 * - 语言假设：获取最可能的语言及其概率
 * - 字符串分割：使用正则表达式分割并重组文本
 * - 边界处理：去除首尾空白字符和换行符
 * - 错误处理：正则表达式编译失败时的容错机制
 * - 性能优化：局部变量减少重复计算
 * - 国际化支持：返回标准语言代码便于系统识别
 */

// 导入 Foundation 框架，提供基础字符串处理功能
import Foundation
// 导入 NaturalLanguage 框架，提供语言识别功能
import NaturalLanguage

// 私有函数：清理文本中的社交媒体特有符号，提取纯语言内容
private func stripToPureLanguage(inText: String) -> String {
  // 匹配 # 开头的标签（如 #iOS）
  guard let hashtagRegex = try? Regex("#[\\w]*"),
    // 匹配 : 包围的自定义表情（如 :smile:）
    let emojiRegex = try? Regex(":\\w*:"),
    // 匹配 @ 开头的用户提及（如 @username）
    let atRegex = try? Regex("@\\w*")
  else {
    // 正则表达式创建失败时，返回去除首尾空白的原文本
    return inText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // 初始化结果字符串
  var resultStr = inText

  // 遍历所有正则表达式，逐步清理文本
  for regex in [hashtagRegex, emojiRegex, atRegex] {
    // 使用正则表达式分割字符串，移除匹配的部分
    let splitArray = resultStr.split(separator: regex, omittingEmptySubsequences: true)
    // 重新拼接剩余的纯文本部分
    resultStr = splitArray.joined() as String
  }

  // 去除首尾的空白字符和换行符，返回清理后的文本
  return resultStr.trimmingCharacters(in: .whitespacesAndNewlines)
}

// 公共函数：检测给定文本的语言类型
func detectLanguage(text: String) -> String? {
  // 创建自然语言识别器实例
  let recognizer = NLLanguageRecognizer()

  // 预处理文本，移除社交媒体噪音
  let strippedText = stripToPureLanguage(inText: text)

  // 让识别器处理清理后的文本
  recognizer.processString(strippedText)

  // 获取最多1个语言假设及其置信度
  let hypotheses = recognizer.languageHypotheses(withMaximum: 1)

  // 只有在置信度大于等于85%时才返回检测结果
  if let (lang, confidence) = hypotheses.first, confidence >= 0.85 {
    // 返回语言的原始值（如 "en"、"zh" 等标准语言代码）
    return lang.rawValue
  } else {
    // 置信度不足时返回 nil，表示无法确定语言
    return nil
  }
}
