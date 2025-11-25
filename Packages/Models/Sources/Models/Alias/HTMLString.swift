/*
 * HTMLString.swift
 * IceCubesApp - HTML 字符串解析和渲染
 *
 * 功能描述：
 * 将 Mastodon 的 HTML 内容转换为 SwiftUI 可显示的格式
 * 支持将 HTML 转换为 Markdown、纯文本和富文本属性字符串
 *
 * 核心功能：
 * 1. HTML 解析 - 使用 SwiftSoup 解析 HTML 内容
 * 2. Markdown 转换 - 将 HTML 转换为 Markdown 格式
 * 3. 纯文本提取 - 提取不含标签的纯文本
 * 4. 属性字符串 - 生成 SwiftUI 可渲染的 AttributedString
 * 5. 链接提取 - 提取所有链接并分类（URL、提及、标签）
 * 6. 标签移除 - 自动移除末尾的标签段落
 * 7. 状态 URL 提取 - 提取帖子引用的 URL
 * 8. 特殊字符转义 - Markdown 特殊字符的转义处理
 * 9. 列表处理 - 支持有序和无序列表
 * 10. 格式保持 - 保持原始 HTML 的格式和结构
 *
 * 技术点：
 * 1. SwiftSoup - HTML 解析库
 * 2. AttributedString - SwiftUI 富文本
 * 3. NSRegularExpression - 正则表达式匹配
 * 4. Codable - 编解码支持
 * 5. @unchecked Sendable - 并发安全（未检查）
 * 6. 递归解析 - 处理嵌套 HTML 结构
 * 7. 正则转义 - Markdown 特殊字符转义
 * 8. URL 编码 - 非 ASCII 字符的 URL 处理
 * 9. 自定义解码 - 支持两种解码格式
 * 10. 内容清理 - 移除不可见和省略内容
 *
 * 支持的 HTML 标签：
 * - p: 段落（转换为双换行）
 * - br: 换行（转换为单换行）
 * - a: 链接（转换为 Markdown 链接）
 * - strong/b: 加粗（转换为 **text**）
 * - em/i: 斜体（转换为 _text_）
 * - blockquote: 引用（转换为 `text`）
 * - ul: 无序列表（转换为 • 列表）
 * - ol: 有序列表（转换为数字列表）
 * - li: 列表项
 *
 * 特殊 CSS 类：
 * - invisible: 不显示的内容
 * - ellipsis: 省略号标记
 * - quote-inline: 内联引用（被移除）
 * - hashtag: 标签链接
 *
 * Markdown 转义字符：
 * - \ ` _ * ~ [ ] - 这些字符会被转义
 * - 冒号之间的下划线不转义（自定义表情）
 *
 * 链接类型：
 * - url: 普通链接
 * - mention: 用户提及（@username）
 * - hashtag: 标签（#tag）
 *
 * 末尾标签处理：
 * - 自动检测末尾的纯标签段落
 * - 从 Markdown 和纯文本中移除
 * - 设置 hadTrailingTags 标记
 *
 * 使用场景：
 * - 帖子内容渲染
 * - 用户简介显示
 * - 通知内容展示
 * - 搜索结果显示
 *
 * 依赖关系：
 * - SwiftSoup: HTML 解析
 * - Foundation: 基础类型
 * - SwiftUI: AttributedString
 */

import Foundation
import SwiftSoup
import SwiftUI

/// 编码键枚举
///
/// 定义 HTMLString 的编解码键。
private enum CodingKeys: CodingKey {
  /// HTML 原始值
  case htmlValue
  /// Markdown 格式
  case asMarkdown
  /// 纯文本格式
  case asRawText
  /// 状态 URL 列表
  case statusesURLs
  /// 链接列表
  case links
  /// 是否有末尾标签
  case hadTrailingTags
}

/// HTML 字符串
///
/// 封装 HTML 内容并提供多种格式转换。
///
/// 主要功能：
/// - **HTML 解析**：解析 HTML 并转换为多种格式
/// - **链接提取**：提取并分类所有链接
/// - **格式转换**：支持 Markdown、纯文本、属性字符串
/// - **特殊处理**：自动移除末尾标签段落
///
/// 使用示例：
/// ```swift
/// // 从解码器创建（常用）
/// let htmlString = try decoder.decode(HTMLString.self, from: data)
///
/// // 显示富文本内容
/// Text(htmlString.asSafeMarkdownAttributedString)
///
/// // 获取纯文本
/// let text = htmlString.asRawText
///
/// // 访问链接
/// for link in htmlString.links {
///     switch link.type {
///     case .mention:
///         // 处理用户提及
///     case .hashtag:
///         // 处理标签
///     case .url:
///         // 处理普通链接
///     }
/// }
/// ```
///
/// - Note: 使用 @unchecked Sendable 以支持并发环境
/// - Important: HTML 解析可能耗时，建议在后台线程执行
public struct HTMLString: Codable, Equatable, Hashable, @unchecked Sendable {
  /// HTML 原始值
  public var htmlValue: String = ""

  /// Markdown 格式的字符串
  public var asMarkdown: String = ""

  /// 纯文本格式（移除所有 HTML 标签）
  public var asRawText: String = ""

  /// 帖子引用的 URL 列表
  public var statusesURLs = [URL]()

  /// 提取的链接列表（包括 URL、提及、标签）
  public private(set) var links = [Link]()

  /// 是否有末尾的标签段落被移除
  public private(set) var hadTrailingTags = false

  /// 安全的 Markdown 属性字符串（用于 SwiftUI 显示）
  public var asSafeMarkdownAttributedString: AttributedString = .init()

  /// 主正则表达式（用于转义 Markdown 特殊字符）
  private var main_regex: NSRegularExpression?

  /// 下划线正则表达式（排除表情符号中的下划线）
  private var underscore_regex: NSRegularExpression?

  /// 从解码器初始化
  ///
  /// 支持两种解码格式：
  /// 1. 单值容器：直接解码 HTML 字符串（需要解析）
  /// 2. 键值容器：解码预处理的数据（已包含 Markdown 等）
  ///
  /// - Parameter decoder: 解码器
  /// - Throws: 解码错误
  public init(from decoder: Decoder) {
    var alreadyDecoded = false
    do {
      let container = try decoder.singleValueContainer()
      htmlValue = try container.decode(String.self)
    } catch {
      do {
        alreadyDecoded = true
        let container = try decoder.container(keyedBy: CodingKeys.self)
        htmlValue = try container.decode(String.self, forKey: .htmlValue)
        asMarkdown = try container.decode(String.self, forKey: .asMarkdown)
        asRawText = try container.decode(String.self, forKey: .asRawText)
        statusesURLs = try container.decode([URL].self, forKey: .statusesURLs)
        links = try container.decode([Link].self, forKey: .links)
        hadTrailingTags = (try? container.decode(Bool.self, forKey: .hadTrailingTags)) ?? false
      } catch {
        htmlValue = ""
      }
    }

    if !alreadyDecoded {
      // https://daringfireball.net/projects/markdown/syntax
      // Pre-escape \ ` _ * ~ and [ as these are the only
      // characters the markdown parser uses when it renders
      // to attributed text. Note that ~ for strikethrough is
      // not documented in the syntax docs but is used by
      // AttributedString.
      main_regex = try? NSRegularExpression(
        pattern: "([\\*\\`\\~\\[\\\\])", options: .caseInsensitive)
      // don't escape underscores that are between colons, they are most likely custom emoji
      underscore_regex = try? NSRegularExpression(
        pattern: "(?!\\B:[^:]*)(_)(?![^:]*:\\B)", options: .caseInsensitive)

      asMarkdown = ""
      do {
        let document: Document = try SwiftSoup.parse(htmlValue)
        var listCounters: [Int] = []
        handleNode(node: document, listCounters: &listCounters)

        document.outputSettings(OutputSettings().prettyPrint(pretty: false))
        try document.select("p.quote-inline").remove()
        try document.select("br").after("\n")
        try document.select("p").after("\n\n")
        let html = try document.html()
        var text =
          try SwiftSoup.clean(
            html, "", Whitelist.none(), OutputSettings().prettyPrint(pretty: false)) ?? ""
        // Remove the two last line break added after the last paragraph.
        if text.hasSuffix("\n\n") {
          _ = text.removeLast()
          _ = text.removeLast()
        }
        asRawText = (try? Entities.unescape(text)) ?? text

        if asMarkdown.hasPrefix("\n") {
          _ = asMarkdown.removeFirst()
        }

        // Remove trailing hashtags
        removeTrailingTags(doc: document)

        // Regenerate attributed string after extracting tags
        do {
          let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
          asSafeMarkdownAttributedString = try AttributedString(
            markdown: asMarkdown, options: options)
        } catch {
          asSafeMarkdownAttributedString = AttributedString(stringLiteral: asMarkdown)
        }

      } catch {
        asRawText = htmlValue
      }
    } else {
      do {
        let options = AttributedString.MarkdownParsingOptions(
          allowsExtendedAttributes: true,
          interpretedSyntax: .inlineOnlyPreservingWhitespace)
        asSafeMarkdownAttributedString = try AttributedString(
          markdown: asMarkdown, options: options)
      } catch {
        asSafeMarkdownAttributedString = AttributedString(stringLiteral: htmlValue)
      }
    }
  }

  /// 从字符串值初始化
  ///
  /// 使用简单的字符串值创建 HTMLString。
  ///
  /// - Parameters:
  ///   - stringValue: 字符串值
  ///   - parseMarkdown: 是否解析为 Markdown（默认 false）
  public init(stringValue: String, parseMarkdown: Bool = false) {
    htmlValue = stringValue
    asMarkdown = stringValue
    asRawText = stringValue
    statusesURLs = []

    if parseMarkdown {
      do {
        let options = AttributedString.MarkdownParsingOptions(
          allowsExtendedAttributes: true,
          interpretedSyntax: .inlineOnlyPreservingWhitespace)
        asSafeMarkdownAttributedString = try AttributedString(
          markdown: asMarkdown, options: options)
      } catch {
        asSafeMarkdownAttributedString = AttributedString(stringLiteral: htmlValue)
      }
    } else {
      asSafeMarkdownAttributedString = AttributedString(stringLiteral: htmlValue)
    }
  }

  /// 编码到编码器
  ///
  /// 将所有属性编码为键值对。
  ///
  /// - Parameter encoder: 编码器
  /// - Throws: 编码错误
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(htmlValue, forKey: .htmlValue)
    try container.encode(asMarkdown, forKey: .asMarkdown)
    try container.encode(asRawText, forKey: .asRawText)
    try container.encode(statusesURLs, forKey: .statusesURLs)
    try container.encode(links, forKey: .links)
    try container.encode(hadTrailingTags, forKey: .hadTrailingTags)
  }

  /// 移除末尾的标签段落
  ///
  /// 检测并移除 HTML 文档末尾的纯标签段落。
  /// 这些标签通常是 Mastodon 自动添加的，不属于正文内容。
  ///
  /// 检测逻辑：
  /// 1. 检查 Markdown 是否包含 # 字符
  /// 2. 找到最后一个非空段落
  /// 3. 检查原始 HTML 中该段落是否只包含标签链接
  /// 4. 如果是，从 Markdown 和纯文本中移除该段落
  ///
  /// - Parameter doc: SwiftSoup 文档对象
  private mutating func removeTrailingTags(doc: Document) {
    // Fast bail-outs
    if !asMarkdown.contains("#") { return }

    // Split markdown by double newlines to get paragraphs (same as building logic)
    let paragraphs = asMarkdown.split(separator: "\n\n", omittingEmptySubsequences: false).map(
      String.init)
    guard
      let lastIndex = paragraphs.lastIndex(where: {
        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      })
    else {
      return
    }

    // Inspect original HTML last paragraph to ensure it is hashtags-only
    // and not a quote-inline. This avoids regex backtracking on large inputs.
    let isLastParagraphTagsOnly: Bool = {
      do {
        let paras = try doc.select("p:not(.quote-inline)")
        guard let lastP = paras.array().last else { return false }
        var hasAtLeastOneHashtag = false
        for child in lastP.getChildNodes() {
          let name = child.nodeName()
          if name == "#text" {
            // Allow whitespace-only text
            let txt = child.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !txt.isEmpty { return false }
          } else if name == "a" {
            // Accept only anchors that look like hashtag links
            let cls = (try? child.attr("class")) ?? ""
            if !cls.contains("hashtag") { return false }
            hasAtLeastOneHashtag = true
          } else {
            // Any other element means mixed content
            return false
          }
        }
        return hasAtLeastOneHashtag
      } catch {
        return false
      }
    }()

    guard isLastParagraphTagsOnly else { return }

    // Remove the last non-empty paragraph from both markdown and raw text
    hadTrailingTags = true
    let updatedMarkdownParagraphs = Array(paragraphs.prefix(lastIndex))
    asMarkdown = updatedMarkdownParagraphs.joined(separator: "\n\n")

    let rawParagraphs = asRawText.split(separator: "\n\n", omittingEmptySubsequences: false).map(
      String.init)
    if lastIndex < rawParagraphs.count {
      let updatedRawParagraphs = Array(rawParagraphs.prefix(lastIndex))
      asRawText = updatedRawParagraphs.joined(separator: "\n\n")
    }
  }

  /// 处理 HTML 节点（递归）
  ///
  /// 递归遍历 HTML 节点树，将每个节点转换为 Markdown 格式。
  ///
  /// 支持的节点类型：
  /// - p: 段落（添加双换行）
  /// - br: 换行（添加单换行）
  /// - a: 链接（转换为 [text](url)）
  /// - strong/b: 加粗（转换为 **text**）
  /// - em/i: 斜体（转换为 _text_）
  /// - blockquote: 引用（转换为 `text`）
  /// - ul/ol: 列表（无序/有序）
  /// - li: 列表项（• 或数字）
  /// - #text: 文本节点（转义特殊字符）
  ///
  /// - Parameters:
  ///   - node: 要处理的节点
  ///   - indent: 缩进级别（用于列表）
  ///   - skipParagraph: 是否跳过段落换行
  ///   - listCounters: 有序列表计数器数组
  private mutating func handleNode(
    node: SwiftSoup.Node,
    indent: Int? = 0,
    skipParagraph: Bool = false,
    listCounters: inout [Int]
  ) {
    do {
      if let className = try? node.attr("class") {
        if className == "invisible" {
          // don't display
          return
        }

        if className == "ellipsis" {
          // descend into this one now and
          // append the ellipsis
          for nn in node.getChildNodes() {
            handleNode(node: nn, indent: indent, listCounters: &listCounters)
          }
          asMarkdown += "…"
          return
        }
      }

      if node.nodeName() == "p" {
        if let className = try? node.attr("class"), className == "quote-inline" {
          return
        }
        if asMarkdown.count > 0 && !skipParagraph {
          asMarkdown += "\n\n"
        }
      } else if node.nodeName() == "br" {
        if asMarkdown.count > 0 {  // ignore first opening <br>
          asMarkdown += "\n"
        }
        if (indent ?? 0) > 0 {
          asMarkdown += "\n"
        }
      } else if node.nodeName() == "a" {
        let href = try node.attr("href")
        if href != "" {
          if let url = URL(string: href) {
            if Int(url.lastPathComponent) != nil {
              statusesURLs.append(url)
            } else if url.host() == "www.threads.net" || url.host() == "threads.net",
              url.pathComponents.count == 4,
              url.pathComponents[2] == "post"
            {
              statusesURLs.append(url)
            }
          }
        }
        asMarkdown += "["
        let start = asMarkdown.endIndex
        // descend into this node now so we can wrap the
        // inner part of the link in the right markup
        for nn in node.getChildNodes() {
          handleNode(node: nn, listCounters: &listCounters)
        }
        let finish = asMarkdown.endIndex

        var linkRef = href

        // Try creating a URL from the string. If it fails, try URL encoding
        //   the string first.
        var url = URL(string: href)
        if url == nil {
          url = URL(string: href, encodePath: true)
        }
        if let linkUrl = url {
          linkRef = linkUrl.absoluteString
          let displayString = asMarkdown[start..<finish]
          links.append(Link(linkUrl, displayString: String(displayString)))
        }

        asMarkdown += "]("
        asMarkdown += linkRef
        asMarkdown += ")"

        return
      } else if node.nodeName() == "#text" {
        var txt = node.description

        txt = (try? Entities.unescape(txt)) ?? txt

        if let underscore_regex, let main_regex {
          //  This is the markdown escaper
          txt = main_regex.stringByReplacingMatches(
            in: txt, options: [], range: NSRange(location: 0, length: txt.count),
            withTemplate: "\\\\$1")
          txt = underscore_regex.stringByReplacingMatches(
            in: txt, options: [], range: NSRange(location: 0, length: txt.count),
            withTemplate: "\\\\$1")
        }
        // Strip newlines and line separators - they should be being sent as <br>s
        asMarkdown += txt.replacingOccurrences(of: "\n", with: "").replacingOccurrences(
          of: "\u{2028}", with: "")
      } else if node.nodeName() == "blockquote" {
        asMarkdown += "\n\n`"
        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, listCounters: &listCounters)
        }
        asMarkdown += "`"
        return
      } else if node.nodeName() == "strong" || node.nodeName() == "b" {
        asMarkdown += "**"
        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, listCounters: &listCounters)
        }
        asMarkdown += "**"
        return
      } else if node.nodeName() == "em" || node.nodeName() == "i" {
        asMarkdown += "_"
        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, listCounters: &listCounters)
        }
        asMarkdown += "_"
        return
      } else if node.nodeName() == "ul" || node.nodeName() == "ol" {

        if skipParagraph {
          asMarkdown += "\n"
        } else {
          asMarkdown += "\n\n"
        }

        var listCounters = listCounters

        if node.nodeName() == "ol" {
          listCounters.append(1)  // Start numbering for a new ordered list
        }

        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: (indent ?? 0) + 1, listCounters: &listCounters)
        }

        if node.nodeName() == "ol" {
          listCounters.removeLast()
        }

        return
      } else if node.nodeName() == "li" {
        asMarkdown += "   "
        if let indent, indent > 1 {
          for _ in 0..<indent {
            asMarkdown += "   "
          }
          asMarkdown += "- "
        }

        if listCounters.isEmpty {
          asMarkdown += "• "
        } else {
          let currentIndex = listCounters.count - 1
          asMarkdown += "\(listCounters[currentIndex]). "
          listCounters[currentIndex] += 1
        }

        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, skipParagraph: true, listCounters: &listCounters)
        }
        asMarkdown += "\n"
        return
      }

      for n in node.getChildNodes() {
        handleNode(node: n, indent: indent, listCounters: &listCounters)
      }
    } catch {}
  }

  /// 链接结构体
  ///
  /// 表示 HTML 中提取的一个链接。
  ///
  /// 链接会根据显示文本自动分类为：
  /// - **提及**：以 @ 开头（@username）
  /// - **标签**：以 # 开头（#hashtag）
  /// - **URL**：普通链接
  public struct Link: Codable, Hashable, Identifiable {
    /// 唯一标识符（使用 hashValue）
    public var id: Int { hashValue }

    /// 链接 URL
    public let url: URL

    /// 显示字符串（链接文本）
    public let displayString: String

    /// 链接类型
    public let type: LinkType

    /// 链接标题（用于显示）
    public let title: String

    /// 初始化链接
    ///
    /// 根据显示字符串自动判断链接类型。
    ///
    /// - Parameters:
    ///   - url: 链接 URL
    ///   - displayString: 显示字符串
    init(_ url: URL, displayString: String) {
      self.url = url
      self.displayString = displayString

      switch displayString.first {
      case "@":
        type = .mention
        title = displayString
      case "#":
        type = .hashtag
        title = String(displayString.dropFirst())
      default:
        type = .url
        var hostNameUrl = url.host ?? url.absoluteString
        if hostNameUrl.hasPrefix("www.") {
          hostNameUrl = String(hostNameUrl.dropFirst(4))
        }
        title = hostNameUrl
      }
    }

    /// 链接类型枚举
    public enum LinkType: String, Codable {
      /// 普通 URL 链接
      case url
      /// 用户提及（@username）
      case mention
      /// 标签（#hashtag）
      case hashtag
    }
  }
}

/// URL 扩展
///
/// 添加支持非 ASCII 字符的 URL 初始化方法。
extension URL {
  /// 从字符串创建 URL，支持路径编码
  ///
  /// 在 URL 中使用非 ASCII 字符是常见的，尽管这些字符在技术上是无效的。
  /// 所有现代浏览器都会自动编码这些字符。
  /// 但是，使用未编码的字符创建 URL 对象会返回 nil，
  /// 因此需要在创建 URL 对象之前编码无效字符。
  ///
  /// - Parameters:
  ///   - string: URL 字符串
  ///   - encodePath: 是否编码路径部分
  ///
  /// - Note: 显示给用户时应使用未编码的版本
  public init?(string: String, encodePath: Bool) {
    var encodedUrlString = ""
    if encodePath,
      string.starts(with: "http://") || string.starts(with: "https://"),
      var startIndex = string.firstIndex(of: "/")
    {
      startIndex = string.index(startIndex, offsetBy: 1)

      // We don't want to encode the host portion of the URL
      if var startIndex = string[startIndex...].firstIndex(of: "/") {
        encodedUrlString = String(string[...startIndex])
        while let endIndex = string[string.index(after: startIndex)...].firstIndex(of: "/") {
          let componentStartIndex = string.index(after: startIndex)
          encodedUrlString =
            encodedUrlString
            + (string[componentStartIndex...endIndex].addingPercentEncoding(
              withAllowedCharacters: .urlPathAllowed) ?? "")
          startIndex = endIndex
        }

        // The last part of the path may have a query string appended to it
        let componentStartIndex = string.index(after: startIndex)
        if let queryStartIndex = string[componentStartIndex...].firstIndex(of: "?") {
          encodedUrlString =
            encodedUrlString
            + (string[componentStartIndex..<queryStartIndex].addingPercentEncoding(
              withAllowedCharacters: .urlPathAllowed) ?? "")
          encodedUrlString =
            encodedUrlString
            + (string[queryStartIndex...].addingPercentEncoding(
              withAllowedCharacters: .urlQueryAllowed) ?? "")
        } else {
          encodedUrlString =
            encodedUrlString
            + (string[componentStartIndex...].addingPercentEncoding(
              withAllowedCharacters: .urlPathAllowed) ?? "")
        }
      }
    }
    if encodedUrlString.isEmpty {
      encodedUrlString = string
    }
    self.init(string: encodedUrlString)
  }
}
