// 文件功能：帖子编辑器 ViewModel - 管理编辑器的状态和业务逻辑
//
// 核心职责：
// - 管理帖子内容的编辑状态
// - 处理媒体附件的上传和管理
// - 管理投票选项和设置
// - 处理敏感内容警告（CW）
// - 执行帖子发布操作
// - 管理草稿的保存和恢复
// - 处理文本输入和格式化
// - 管理语言检测和选择
// - 处理提及、标签、链接的自动补全
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架
// - @MainActor：确保所有操作在主线程
// - NSObject：继承以支持 UITextViewDelegate
// - Identifiable：支持在列表中使用
// - Combine：处理异步事件流
// - PhotosPickerItem：处理照片选择
// - AVFoundation：处理视频和音频
// - NaturalLanguage：语言检测
//
// 编辑模式：
// - new：创建新帖子
// - replyTo：回复其他帖子
// - edit：编辑已发布的帖子
// - quote：引用其他帖子
// - mention：提及特定用户
// - shareExtension：从分享扩展创建
//
// 状态管理：
// - 帖子内容：statusText（富文本）
// - 媒体附件：mediaContainers（图片、视频）
// - 投票选项：pollOptions、pollDuration
// - 敏感内容：spoilerOn、spoilerText
// - 发布状态：isPosting、postingProgress
// - 草稿状态：草稿自动保存和恢复
//
// 媒体处理：
// - 支持最多 4 个媒体附件
// - 自动压缩图片
// - 视频转码和压缩
// - Alt 文本（无障碍描述）
// - 媒体编辑（裁剪、旋转）
//
// 文本处理：
// - 自动检测提及（@username）
// - 自动检测标签（#hashtag）
// - 自动检测链接
// - URL 长度计算（Mastodon 限制）
// - 字符计数（考虑 URL 和 CW）
// - 表情符号支持
//
// 投票功能：
// - 2-4 个投票选项
// - 单选或多选
// - 投票时长（5分钟到7天）
// - 投票结果隐藏选项
//
// 草稿管理：
// - 自动保存草稿
// - 恢复未完成的帖子
// - 草稿列表管理
// - 草稿删除
//
// 语言检测：
// - 自动检测帖子语言
// - 手动选择语言
// - 语言确认对话框
//
// 发布流程：
// 1. 验证内容（长度、媒体等）
// 2. 上传媒体附件
// 3. 创建投票（如果有）
// 4. 发布帖子
// 5. 处理错误和重试
// 6. 清理草稿
//
// 错误处理：
// - 网络错误
// - 媒体上传失败
// - 内容验证失败
// - 服务器错误
//
// 性能优化：
// - 延迟加载媒体预览
// - 智能文本处理
// - 批量上传媒体
// - 取消未完成的操作
//
// 依赖关系：
// - 依赖：Models、Env、NetworkClient、DesignSystem
// - 被依赖：MainView、EditorView
//
// 使用场景：
// - 创建新帖子
// - 回复其他用户
// - 编辑已发布的帖子
// - 创建帖子串（thread）
// - 从分享扩展分享内容

import AVFoundation
import Combine
import DesignSystem
import Env
import Models
import NaturalLanguage
import NetworkClient
import PhotosUI
import SwiftUI

#if !targetEnvironment(macCatalyst)
  import FoundationModels
#endif

extension StatusEditor {
  /// 帖子编辑器 ViewModel
  ///
  /// 管理帖子编辑器的所有状态和业务逻辑。
  ///
  /// 主要功能：
  /// - **内容编辑**：管理帖子文本、格式化、字符计数
  /// - **媒体管理**：上传、编辑、删除媒体附件
  /// - **投票创建**：配置投票选项和设置
  /// - **草稿管理**：自动保存和恢复草稿
  /// - **发布操作**：执行帖子发布和错误处理
  ///
  /// 状态属性：
  /// - `statusText`：帖子内容（富文本）
  /// - `mediaContainers`：媒体附件列表
  /// - `pollOptions`：投票选项
  /// - `spoilerText`：敏感内容警告
  /// - `isPosting`：是否正在发布
  ///
  /// 使用示例：
  /// ```swift
  /// // 创建新帖子的 ViewModel
  /// let viewModel = StatusEditor.ViewModel(mode: .new)
  ///
  /// // 设置内容
  /// viewModel.statusText = NSMutableAttributedString(string: "Hello Mastodon!")
  ///
  /// // 添加媒体
  /// viewModel.mediaPickers = [photoItem]
  ///
  /// // 发布
  /// await viewModel.postStatus()
  /// ```
  ///
  /// - Note: 所有操作必须在主线程执行（@MainActor）
  /// - Important: 使用 @Observable 而非 @ObservableObject，这是 Swift 6 的新特性
  /// - SeeAlso: `StatusEditor.MainView` - 使用此 ViewModel 的主视图
  @MainActor
  @Observable public class ViewModel: NSObject, Identifiable {
    // MARK: - 标识符

    /// ViewModel 的唯一标识符
    ///
    /// 用于在列表中区分不同的编辑器实例（帖子串）。
    public let id = UUID()

    // MARK: - 编辑模式

    /// 编辑模式
    ///
    /// 决定编辑器的行为和初始状态：
    /// - `.new`：创建新帖子
    /// - `.replyTo(status)`：回复指定帖子
    /// - `.edit(status)`：编辑已发布的帖子
    /// - `.quote(status)`：引用指定帖子
    /// - `.mention(account)`：提及指定用户
    /// - `.shareExtension(items)`：从分享扩展创建
    var mode: Mode

    // MARK: - 依赖注入

    /// Mastodon 客户端
    ///
    /// 用于执行 API 操作（发布帖子、上传媒体等）。
    var client: MastodonClient?

    /// 当前账户
    ///
    /// 当前正在使用的 Mastodon 账户。
    /// 当账户切换时，清空媒体附件（因为媒体需要重新上传）。
    var currentAccount: Account? {
      didSet {
        if itemsProvider != nil {
          mediaContainers = []
        }
      }
    }

    /// 主题
    ///
    /// 提供颜色、字体等主题配置。
    var theme: Theme?

    /// 用户偏好设置
    ///
    /// 包含用户的各种偏好设置（默认可见性、语言等）。
    var preferences: UserPreferences?

    /// 当前实例
    ///
    /// 当前 Mastodon 实例的配置和限制（字符限制、媒体限制等）。
    var currentInstance: CurrentInstance?

    /// 语言确认对话框的语言
    ///
    /// 存储检测到的语言和用户选择的语言，用于显示确认对话框。
    /// - detected：自动检测到的语言
    /// - selected：用户选择的语言
    var languageConfirmationDialogLanguages: (detected: String, selected: String)?

    // MARK: - 文本编辑

    /// UITextView 引用
    ///
    /// 底层的 UIKit 文本视图，用于高级文本编辑功能。
    /// 设置 pasteDelegate 以处理粘贴操作（如粘贴图片）。
    var textView: UITextView? {
      didSet {
        textView?.pasteDelegate = self
      }
    }

    /// 选中的文本范围
    ///
    /// 当前光标位置或选中的文本范围。
    /// 用于插入文本、表情符号等操作。
    var selectedRange: NSRange {
      get {
        guard let textView else {
          return .init(location: 0, length: 0)
        }
        return textView.selectedRange
      }
      set {
        textView?.selectedRange = newValue
      }
    }

    /// 标记的文本范围
    ///
    /// 输入法正在编辑的文本范围（如中文拼音输入）。
    /// 用于处理多字节字符的输入。
    var markedTextRange: UITextRange? {
      guard let textView else {
        return nil
      }
      return textView.markedTextRange
    }

    /// 帖子文本内容
    ///
    /// 使用富文本（NSMutableAttributedString）支持：
    /// - 提及（@username）的高亮
    /// - 标签（#hashtag）的高亮
    /// - 链接的高亮
    /// - 自定义表情符号
    ///
    /// 当文本改变时：
    /// 1. 处理文本格式化（高亮提及、标签等）
    /// 2. 检查嵌入内容（引用的帖子）
    /// 3. 更新 UITextView 的显示
    /// 4. 恢复光标位置
    var statusText = NSMutableAttributedString(string: "") {
      didSet {
        let range = selectedRange
        processText()
        checkEmbed()
        textView?.attributedText = statusText
        selectedRange = range
      }
    }

    // MARK: - 字符计数

    /// URL 长度调整值
    ///
    /// Mastodon 将所有 URL 计为固定长度（23 字符），
    /// 此值用于调整实际 URL 长度和计数长度的差异。
    private var urlLengthAdjustments: Int = 0

    /// URL 的最大计数长度
    ///
    /// Mastodon 规定所有 URL 都计为 23 个字符，
    /// 无论实际长度是多少。
    private let maxLengthOfUrl = 23

    /// 敏感内容警告的字符数
    ///
    /// 如果启用了 CW，返回警告文本的字符数。
    private var spoilerTextCount: Int {
      spoilerOn ? spoilerText.utf16.count : 0
    }

    /// 剩余可用字符数
    ///
    /// 计算公式：实例限制 - 帖子文本长度 - CW 文本长度 - URL 调整
    ///
    /// 负数表示超出限制。
    var statusTextCharacterLength: Int {
      urlLengthAdjustments - statusText.string.utf16.count - spoilerTextCount
    }

    // MARK: - 分享扩展

    /// 分享项提供者
    ///
    /// 从分享扩展传入的内容项（文本、图片、链接等）。
    private var itemsProvider: [NSItemProvider]?

    /// 备份的帖子文本
    ///
    /// 用于在某些操作失败时恢复原始文本。
    var backupStatusText: NSAttributedString?

    // MARK: - 投票功能

    /// 是否显示投票
    ///
    /// 控制投票编辑界面的显示。
    var showPoll: Bool = false

    /// 投票类型
    ///
    /// - oneVote：单选投票
    /// - multiple：多选投票
    var pollVotingFrequency = PollVotingFrequency.oneVote

    /// 投票时长
    ///
    /// 投票的有效期（5分钟到7天）。
    var pollDuration = Duration.oneDay

    /// 投票选项
    ///
    /// 投票的选项列表（2-4 个选项）。
    /// 默认有两个空选项。
    var pollOptions: [String] = ["", ""]

    // MARK: - 敏感内容警告（CW）

    /// 是否启用敏感内容警告
    ///
    /// 启用后，帖子内容会被折叠，只显示警告文本。
    var spoilerOn: Bool = false

    /// 敏感内容警告文本
    ///
    /// 显示在折叠内容上方的警告文字。
    /// 例如："剧透警告"、"政治内容"等。
    var spoilerText: String = ""

    // MARK: - 发布状态

    /// 发布进度
    ///
    /// 0.0 到 1.0 之间的值，表示发布进度。
    /// 主要用于媒体上传的进度显示。
    var postingProgress: Double = 0.0

    /// 发布计时器
    ///
    /// 用于模拟发布进度的计时器。
    var postingTimer: Timer?

    /// 是否正在发布
    ///
    /// true：正在发布帖子
    /// false：未在发布
    ///
    /// 发布时禁用编辑和发布按钮。
    var isPosting: Bool = false

    // MARK: - 媒体附件

    /// 照片选择器项
    ///
    /// 用户从照片库选择的照片/视频项。
    ///
    /// 限制：
    /// - 最多 4 个媒体附件
    /// - 超过 4 个时自动截断
    ///
    /// 当值改变时：
    /// 1. 限制数量不超过 4 个
    /// 2. 移除已删除的媒体容器
    /// 3. 为新添加的项准备上传
    var mediaPickers: [PhotosPickerItem] = [] {
      didSet {
        if mediaPickers.count > 4 {
          mediaPickers = mediaPickers.prefix(4).map { $0 }
        }

        let removedIDs =
          oldValue
          .filter { !mediaPickers.contains($0) }
          .compactMap(\.itemIdentifier)
        mediaContainers.removeAll { removedIDs.contains($0.id) }

        let newPickerItems = mediaPickers.filter { !oldValue.contains($0) }
        if !newPickerItems.isEmpty {
          isMediasLoading = true
          for item in newPickerItems {
            prepareToPost(for: item)
          }
        }
      }
    }

    /// 是否正在加载媒体
    ///
    /// true：正在从照片库加载媒体
    /// false：加载完成
    ///
    /// 加载时显示进度指示器。
    var isMediasLoading: Bool = false

    /// 媒体容器列表
    ///
    /// 存储已加载的媒体及其元数据：
    /// - 图片/视频数据
    /// - Alt 文本（无障碍描述）
    /// - 上传状态
    /// - 错误信息
    var mediaContainers: [MediaContainer] = []

    /// 回复的帖子
    ///
    /// 如果是回复模式，存储被回复的帖子。
    var replyToStatus: Status?

    /// 嵌入的帖子
    ///
    /// 如果是引用模式，存储被引用的帖子。
    var embeddedStatus: Status?

    // MARK: - 自定义表情

    /// 自定义表情容器
    ///
    /// 按分类组织的自定义表情列表。
    /// 用于表情选择器。
    var customEmojiContainer: [CategorizedEmojiContainer] = []

    // MARK: - 错误处理

    /// 发布错误信息
    ///
    /// 发布失败时的错误描述。
    var postingError: String?

    /// 是否显示发布错误警告
    ///
    /// 控制错误警告对话框的显示。
    var showPostingErrorAlert: Bool = false

    // MARK: - 验证和状态

    /// 是否可以发布
    ///
    /// 满足以下任一条件即可发布：
    /// - 帖子文本不为空
    /// - 至少有一个媒体附件
    var canPost: Bool {
      statusText.length > 0 || !mediaContainers.isEmpty
    }

    /// 是否应该禁用投票按钮
    ///
    /// Mastodon 不允许同时包含媒体和投票。
    /// 有媒体时禁用投票按钮。
    var shouldDisablePollButton: Bool {
      !mediaContainers.isEmpty
    }

    /// 所有媒体是否都有描述
    ///
    /// 检查所有媒体附件是否都添加了 Alt 文本。
    /// 用于无障碍提醒。
    var allMediaHasDescription: Bool {
      var everyMediaHasAltText = true
      for mediaContainer in mediaContainers {
        if ((mediaContainer.mediaAttachment?.description) == nil)
          || mediaContainer.mediaAttachment?.description?.count == 0
        {
          everyMediaHasAltText = false
        }
      }

      return everyMediaHasAltText
    }

    /// 是否应该显示关闭警告
    ///
    /// 当有未保存的内容时，关闭编辑器前显示警告。
    ///
    /// 条件：
    /// - 帖子文本不为空（去除空白字符后）
    /// - 不在分享扩展中（分享扩展不需要警告）
    /// - 排除自动添加的提及文本
    var shouldDisplayDismissWarning: Bool {
      var modifiedStatusText = statusText.string.trimmingCharacters(in: .whitespaces)

      if let mentionString, modifiedStatusText.hasPrefix(mentionString) {
        modifiedStatusText = String(modifiedStatusText.dropFirst(mentionString.count))
      }

      return !modifiedStatusText.isEmpty && !mode.isInShareExtension
    }

    /// 容器 ID 到 Alt 文本的映射
    ///
    /// 存储从 Intents 传入的初始 Alt 文本。
    /// 用于恢复媒体的无障碍描述。
    var containerIdToAltText: [String: String] = [:]

    // MARK: - 可见性和语言

    /// 帖子可见性
    ///
    /// 默认为公开（.pub）。
    /// 可选值：public、unlisted、private、direct
    var visibility: Models.Visibility = .pub

    /// 提及建议列表
    ///
    /// 输入 @ 时显示的用户建议。
    var mentionsSuggestions: [Account] = []

    /// 标签建议列表
    ///
    /// 输入 # 时显示的标签建议。
    var tagsSuggestions: [Tag] = []

    /// 是否内联显示最近使用的标签
    ///
    /// true：在输入框下方显示最近标签
    /// false：不显示
    var showRecentsTagsInline: Bool = false

    /// 选择的语言
    ///
    /// 帖子的语言代码（ISO 639-1）。
    /// 例如："en"、"zh"、"ja"
    var selectedLanguage: String?

    /// 是否明确选择了语言
    ///
    /// true：用户手动选择了语言
    /// false：使用自动检测的语言
    var hasExplicitlySelectedLanguage: Bool = false

    /// 当前建议的文本范围
    ///
    /// 正在显示建议时的文本范围（@ 或 # 的位置）。
    private var currentSuggestionRange: NSRange?

    /// 嵌入帖子的 URL
    ///
    /// 被引用帖子的 URL，用于在帖子中显示引用链接。
    private var embeddedStatusURL: URL? {
      URL(string: embeddedStatus?.reblog?.url ?? embeddedStatus?.url ?? "")
    }

    /// 提及字符串
    ///
    /// 回复时自动添加的提及文本（@username）。
    private var mentionString: String?

    /// 建议任务
    ///
    /// 用于获取提及和标签建议的异步任务。
    /// 可以取消以避免不必要的网络请求。
    private var suggestedTask: Task<Void, Never>?

    init(mode: Mode) {
      self.mode = mode

      #if !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *), Assistant.isAvailable {
          Assistant.prewarm()
        }
      #endif
    }

    // MARK: - 语言检测和选择

    /// 设置初始语言选择
    ///
    /// 根据编辑模式和用户偏好设置初始语言。
    ///
    /// 语言选择优先级：
    /// 1. **编辑或引用模式**：使用原帖的语言
    /// 2. **用户偏好**：使用用户设置的默认语言
    /// 3. **账户语言**：使用账户的语言设置
    ///
    /// - Parameter preference: 用户偏好的语言代码
    ///
    /// 语言代码格式：
    /// - ISO 639-1 标准（两字母代码）
    /// - 例如："en"、"zh"、"ja"、"es"
    ///
    /// 使用场景：
    /// - 编辑器初始化时
    /// - 账户切换时
    /// - 用户更改语言偏好时
    ///
    /// - Note: 语言用于帖子的语言标记，帮助用户过滤内容
    func setInitialLanguageSelection(preference: String?) {
      switch mode {
      case .edit(let status), .quote(let status):
        selectedLanguage = status.language
      default:
        break
      }

      selectedLanguage = selectedLanguage ?? preference ?? currentAccount?.source?.language
    }

    /// 评估语言选择
    ///
    /// 检测帖子语言并与用户选择的语言比较。
    /// 如果检测到的语言与选择的语言不同，显示确认对话框。
    ///
    /// 检测逻辑：
    /// 1. 使用 NaturalLanguage 框架检测文本语言
    /// 2. 与用户选择的语言比较
    /// 3. 如果不同，设置确认对话框数据
    /// 4. 如果相同或无法检测，清除对话框
    ///
    /// 确认对话框：
    /// - 显示检测到的语言
    /// - 显示用户选择的语言
    /// - 让用户确认或更改
    ///
    /// 使用场景：
    /// - 用户完成输入后
    /// - 准备发布前
    /// - 语言选择改变时
    ///
    /// 为什么需要确认：
    /// - 自动检测可能不准确
    /// - 用户可能使用多种语言
    /// - 避免错误的语言标记
    ///
    /// - Note: 只在检测语言与选择语言不同时显示对话框
    /// - SeeAlso: `detectLanguage(text:)` - 语言检测方法
    func evaluateLanguages() {
      if let detectedLang = detectLanguage(text: statusText.string),
        let selectedLanguage,
        selectedLanguage != "",
        selectedLanguage != detectedLang
      {
        languageConfirmationDialogLanguages = (detected: detectedLang, selected: selectedLanguage)
      } else {
        languageConfirmationDialogLanguages = nil
      }
    }

    // MARK: - 发布方法

    /// 发布帖子
    ///
    /// 执行完整的帖子发布流程，包括验证、上传媒体、创建投票、发布帖子等。
    ///
    /// 发布流程：
    /// 1. **验证内容**：
    ///    - 检查是否所有媒体都有 Alt 文本（如果用户设置要求）
    ///    - 验证帖子内容不为空或有媒体附件
    ///
    /// 2. **准备数据**：
    ///    - 创建投票数据（如果有投票）
    ///    - 收集媒体 ID 和属性
    ///    - 构建 StatusData 对象
    ///
    /// 3. **发布帖子**：
    ///    - 新帖子：POST /api/v1/statuses
    ///    - 编辑帖子：PUT /api/v1/statuses/:id
    ///    - 回复、引用等都使用 POST
    ///
    /// 4. **后处理**：
    ///    - 发送实时事件（通知其他视图更新）
    ///    - 保存语言选择
    ///    - 触发触觉反馈
    ///    - 清理状态
    ///
    /// 5. **错误处理**：
    ///    - 捕获服务器错误
    ///    - 捕获验证错误
    ///    - 显示错误警告
    ///    - 触发错误触觉反馈
    ///
    /// - Returns: 发布成功返回 Status 对象，失败返回 nil
    ///
    /// - Throws:
    ///   - `PostError.missingAltText`：缺少 Alt 文本
    ///   - `ServerError`：服务器返回的错误
    ///
    /// 使用示例：
    /// ```swift
    /// if let status = await viewModel.postStatus() {
    ///     print("发布成功：\(status.id)")
    ///     // 关闭编辑器
    /// } else {
    ///     print("发布失败")
    ///     // 显示错误信息
    /// }
    /// ```
    ///
    /// 进度显示：
    /// - 使用 `postingProgress` 属性显示进度条
    /// - 使用计时器模拟进度（0-100%）
    /// - 实际进度取决于网络速度和媒体大小
    ///
    /// 实时事件：
    /// - 发布成功后通过 StreamWatcher 发送事件
    /// - 其他视图（时间线等）会自动更新
    /// - 编辑帖子会发送编辑事件
    ///
    /// - Note: 此方法必须在主线程调用（@MainActor）
    /// - Important: 发布前确保已上传所有媒体附件
    /// - SeeAlso: `prepareToPost(for:)` - 准备媒体上传
    func postStatus() async -> Status? {
      guard let client else { return nil }
      do {
        if !allMediaHasDescription && UserPreferences.shared.appRequireAltText {
          throw PostError.missingAltText
        }

        if postingTimer == nil {
          Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
              if self.postingProgress < 100 {
                self.postingProgress += 0.5
              }
              if self.postingProgress >= 100 {
                self.postingTimer?.invalidate()
                self.postingTimer = nil
              }
            }
          }
        }
        isPosting = true
        let postStatus: Status?
        var pollData: StatusData.PollData?
        if let pollOptions = getPollOptionsForAPI() {
          pollData = .init(
            options: pollOptions,
            multiple: pollVotingFrequency.canVoteMultipleTimes,
            expires_in: pollDuration.rawValue)
        }
        // Fallback: include any pending containerIdToAltText in mediaAttributes if media got uploaded
        if !containerIdToAltText.isEmpty {
          for c in mediaContainers {
            if let desc = containerIdToAltText[c.id], let id = c.mediaAttachment?.id {
              mediaAttributes.append(.init(id: id, description: desc, thumbnail: nil, focus: nil))
            }
          }
        }
        let data = StatusData(
          status: statusText.string,
          visibility: visibility,
          inReplyToId: mode.replyToStatus?.id,
          spoilerText: spoilerOn ? spoilerText : nil,
          mediaIds: mediaContainers.compactMap { $0.mediaAttachment?.id },
          poll: pollData,
          language: selectedLanguage,
          mediaAttributes: mediaAttributes,
          quotedStatusId: embeddedStatus?.id)
        switch mode {
        case .new, .replyTo, .quote, .mention, .shareExtension, .quoteLink, .imageURL:
          postStatus = try await client.post(endpoint: Statuses.postStatus(json: data))
          if let postStatus {
            StreamWatcher.shared.emmitPostEvent(for: postStatus)
          }
        case .edit(let status):
          postStatus = try await client.put(
            endpoint: Statuses.editStatus(id: status.id, json: data))
          if let postStatus {
            StreamWatcher.shared.emmitEditEvent(for: postStatus)
          }
        }

        postingTimer?.invalidate()
        postingTimer = nil

        withAnimation {
          postingProgress = 99.0
        }
        try await Task.sleep(for: .seconds(0.5))
        HapticManager.shared.fireHaptic(.notification(.success))

        if hasExplicitlySelectedLanguage, let selectedLanguage {
          preferences?.markLanguageAsSelected(isoCode: selectedLanguage)
        }
        isPosting = false

        return postStatus
      } catch {
        if let error = error as? Models.ServerError {
          postingError = error.error
          showPostingErrorAlert = true
        }
        if let postError = error as? PostError {
          postingError = postError.description
          showPostingErrorAlert = true
        }
        isPosting = false
        HapticManager.shared.fireHaptic(.notification(.error))
        return nil
      }
    }

    // MARK: - Status Text manipulations

    func insertStatusText(text: String) {
      let string = statusText
      string.mutableString.insert(text, at: selectedRange.location)
      statusText = string
      selectedRange = NSRange(location: selectedRange.location + text.utf16.count, length: 0)
      processText()
    }

    // MARK: - 文本处理方法

    /// 替换指定范围的文本
    ///
    /// 在指定的文本范围内替换为新文本。
    ///
    /// 处理流程：
    /// 1. 删除指定范围的字符
    /// 2. 在相同位置插入新文本
    /// 3. 更新 statusText
    /// 4. 移动光标到新文本末尾
    /// 5. 触发 textViewDidChange 回调
    ///
    /// - Parameters:
    ///   - text: 新文本
    ///   - inRange: 要替换的文本范围
    ///
    /// 使用场景：
    /// - 插入提及（@username）
    /// - 插入标签（#hashtag）
    /// - 插入表情符号
    /// - 自动补全
    ///
    /// 光标位置：
    /// - 替换后光标移动到新文本末尾
    /// - 方便用户继续输入
    ///
    /// - Note: 会触发 statusText 的 didSet，自动处理文本格式化
    func replaceTextWith(text: String, inRange: NSRange) {
      let string = statusText
      string.mutableString.deleteCharacters(in: inRange)
      string.mutableString.insert(text, at: inRange.location)
      statusText = string
      selectedRange = NSRange(location: inRange.location + text.utf16.count, length: 0)
      if let textView {
        textView.delegate?.textViewDidChange?(textView)
      }
    }

    /// 替换全部文本
    ///
    /// 用新文本替换整个帖子内容。
    ///
    /// - Parameter text: 新文本
    ///
    /// 使用场景：
    /// - AI 助手重写文本
    /// - 恢复草稿
    /// - 清空内容
    ///
    /// 光标位置：
    /// - 移动到文本末尾
    ///
    /// - Note: 会触发 statusText 的 didSet，自动处理文本格式化
    func replaceTextWith(text: String) {
      statusText = .init(string: text)
      selectedRange = .init(location: text.utf16.count, length: 0)
    }

    /// 准备帖子文本
    ///
    /// 根据编辑模式初始化帖子内容和相关状态。
    ///
    /// 不同模式的处理：
    ///
    /// **1. 新建帖子（.new）**：
    /// - 设置初始文本（如果提供）
    /// - 设置可见性
    /// - 光标移到文本末尾
    ///
    /// **2. 分享扩展（.shareExtension）**：
    /// - 处理分享的内容项
    /// - 默认可见性为公开
    /// - 自动提取文本和媒体
    ///
    /// **3. 图片 URL（.imageURL）**：
    /// - 从 URL 加载图片
    /// - 设置标题文本
    /// - 添加 Alt 文本（如果提供）
    /// - 设置可见性
    ///
    /// **4. 回复（.replyTo）**：
    /// - 自动添加被回复用户的提及
    /// - 添加原帖中其他被提及用户
    /// - 继承原帖的可见性（或更私密）
    /// - 继承敏感内容警告
    /// - 光标移到提及文本末尾
    ///
    /// **5. 提及（.mention）**：
    /// - 添加指定用户的提及
    /// - 设置可见性
    /// - 光标移到提及后
    ///
    /// **6. 编辑（.edit）**：
    /// - 加载原帖内容
    /// - 转换提及为完整格式（@username@instance）
    /// - 加载媒体附件
    /// - 加载敏感内容警告
    /// - 保持原可见性
    ///
    /// **7. 引用（.quote）**：
    /// - 存储被引用的帖子
    /// - 如果实例支持引用，使用原生功能
    /// - 否则在文本中添加引用链接
    ///
    /// **8. 引用链接（.quoteLink）**：
    /// - 在文本中添加链接
    ///
    /// 提及处理：
    /// - 自动排除当前用户（不提及自己）
    /// - 保持提及的完整格式（@username@instance）
    /// - 在提及后添加空格
    ///
    /// 可见性继承：
    /// - 回复时使用用户偏好设置
    /// - 不能比原帖更公开
    /// - 例如：回复私密帖子时，只能是私密或私信
    ///
    /// - Note: 此方法在编辑器初始化时调用
    /// - Important: 不同模式有不同的初始化逻辑
    /// - SeeAlso: `Mode` - 编辑模式枚举
    func prepareStatusText() {
      switch mode {
      case .new(let text, let visibility):
        if let text {
          statusText = .init(string: text)
          selectedRange = .init(location: text.utf16.count, length: 0)
        }
        self.visibility = visibility
      case .shareExtension(let items):
        itemsProvider = items
        visibility = .pub
        processItemsProvider(items: items)
      case .imageURL(let urls, let caption, let altTexts, let visibility):
        Task {
          let containers = await Self.makeImageContainer(from: urls)
          if let altTexts {
            for (i, c) in containers.enumerated() where i < altTexts.count {
              let desc = altTexts[i].trimmingCharacters(in: .whitespacesAndNewlines)
              if !desc.isEmpty {
                containerIdToAltText[c.id] = desc
              }
            }
          }
          for container in containers {
            prepareToPost(for: container)
          }
        }
        if let caption, !caption.isEmpty {
          statusText = .init(string: caption)
          selectedRange = .init(location: caption.utf16.count, length: 0)
        }
        self.visibility = visibility
      case .replyTo(let status):
        var mentionString = ""
        if (status.reblog?.account.acct ?? status.account.acct) != currentAccount?.acct {
          mentionString = "@\(status.reblog?.account.acct ?? status.account.acct)"
        }
        for mention in status.mentions where mention.acct != currentAccount?.acct {
          if !mentionString.isEmpty {
            mentionString += " "
          }
          mentionString += "@\(mention.acct)"
        }
        if !mentionString.isEmpty {
          mentionString += " "
        }
        replyToStatus = status
        visibility = UserPreferences.shared.getReplyVisibility(of: status)
        statusText = .init(string: mentionString)
        selectedRange = .init(location: mentionString.utf16.count, length: 0)
        if !mentionString.isEmpty {
          self.mentionString = mentionString.trimmingCharacters(in: .whitespaces)
        }
        if !status.spoilerText.asRawText.isEmpty {
          spoilerOn = true
          spoilerText = status.spoilerText.asRawText
        }
      case .mention(let account, let visibility):
        statusText = .init(string: "@\(account.acct) ")
        self.visibility = visibility
        selectedRange = .init(location: statusText.string.utf16.count, length: 0)
      case .edit(let status):
        var rawText = status.content.asRawText.escape()
        for mention in status.mentions {
          rawText = rawText.replacingOccurrences(
            of: "@\(mention.username)", with: "@\(mention.acct)")
        }
        statusText = .init(string: rawText)
        selectedRange = .init(location: statusText.string.utf16.count, length: 0)
        spoilerOn = !status.spoilerText.asRawText.isEmpty
        spoilerText = status.spoilerText.asRawText
        visibility = status.visibility
        mediaContainers = status.mediaAttachments.map {
          MediaContainer.uploaded(
            id: UUID().uuidString,
            attachment: $0,
            originalImage: nil
          )
        }
      case .quote(let status):
        embeddedStatus = status
        if currentInstance?.isQuoteSupported == true {
          // Do nothing
        } else if let url = embeddedStatusURL {
          statusText = .init(
            string: "\n\nFrom: @\(status.reblog?.account.acct ?? status.account.acct)\n\(url)")
          selectedRange = .init(location: 0, length: 0)
        }
      case .quoteLink(let link):
        statusText = .init(string: "\n\n\(link)")
        selectedRange = .init(location: 0, length: 0)
      }
    }

    /// 处理文本格式化
    ///
    /// 自动检测和高亮文本中的特殊元素。
    ///
    /// 处理流程：
    /// 1. **重置样式**：将所有文本重置为默认样式
    /// 2. **检测标签**：使用正则表达式匹配 #hashtag
    /// 3. **检测提及**：使用正则表达式匹配 @username
    /// 4. **检测链接**：使用正则表达式匹配 URL
    /// 5. **应用高亮**：为匹配的文本应用主题色
    /// 6. **触发自动补全**：如果光标在标签或提及后，显示建议
    /// 7. **计算 URL 长度**：调整字符计数（Mastodon 将 URL 计为 23 字符）
    /// 8. **移除链接属性**：防止自动链接干扰
    ///
    /// 正则表达式模式：
    /// - **标签**：`(#+[\w0-9(_)]{0,})`
    ///   - 匹配 #tag、#标签123 等
    ///   - 支持下划线和数字
    ///
    /// - **提及**：`(@+[a-zA-Z0-9(_).-]{1,})`
    ///   - 匹配 @username、@user.name 等
    ///   - 支持点号、下划线、连字符
    ///
    /// - **链接**：`(?i)https?://(?:www\.)?\\S+(?:/|\\b)`
    ///   - 匹配 http:// 和 https:// 链接
    ///   - 不区分大小写
    ///
    /// 高亮样式：
    /// - 标签和提及：使用主题色
    /// - 链接：使用主题色 + 下划线
    ///
    /// 自动补全触发：
    /// - 光标在标签或提及末尾时
    /// - 自动加载建议列表
    /// - 显示匹配的用户或标签
    ///
    /// URL 长度调整：
    /// - Mastodon 将所有 URL 计为 23 字符
    /// - 计算实际长度和固定长度的差值
    /// - 用于准确的字符计数
    ///
    /// - Note: 在输入法编辑时（markedTextRange 不为 nil）不处理
    /// - Important: 每次文本改变时自动调用（statusText 的 didSet）
    /// - SeeAlso: `loadAutoCompleteResults(query:)` - 加载自动补全建议
    private func processText() {
      guard markedTextRange == nil else { return }
      statusText.addAttributes(
        [
          .foregroundColor: UIColor(Theme.shared.labelColor),
          .font: Font.scaledBodyUIFont,
          .backgroundColor: UIColor.clear,
          .underlineColor: UIColor.clear,
        ],
        range: NSMakeRange(0, statusText.string.utf16.count))
      let hashtagPattern = "(#+[\\w0-9(_)]{0,})"
      let mentionPattern = "(@+[a-zA-Z0-9(_).-]{1,})"
      let urlPattern = "(?i)https?://(?:www\\.)?\\S+(?:/|\\b)"

      do {
        let hashtagRegex = try NSRegularExpression(pattern: hashtagPattern, options: [])
        let mentionRegex = try NSRegularExpression(pattern: mentionPattern, options: [])
        let urlRegex = try NSRegularExpression(pattern: urlPattern, options: [])

        let range = NSMakeRange(0, statusText.string.utf16.count)
        var ranges = hashtagRegex.matches(
          in: statusText.string,
          options: [],
          range: range
        ).map(\.range)
        ranges.append(
          contentsOf: mentionRegex.matches(
            in: statusText.string,
            options: [],
            range: range
          ).map(\.range))

        let urlRanges = urlRegex.matches(
          in: statusText.string,
          options: [],
          range: range
        ).map(\.range)

        var foundSuggestionRange = false
        for nsRange in ranges {
          statusText.addAttributes(
            [.foregroundColor: UIColor(theme?.tintColor ?? .brand)],
            range: nsRange)
          if selectedRange.location == (nsRange.location + nsRange.length),
            let range = Range(nsRange, in: statusText.string)
          {
            foundSuggestionRange = true
            currentSuggestionRange = nsRange
            loadAutoCompleteResults(query: String(statusText.string[range]))
          }
        }

        if !foundSuggestionRange || ranges.isEmpty {
          resetAutoCompletion()
        }

        var totalUrlLength = 0
        var numUrls = 0

        for range in urlRanges {
          numUrls += 1
          totalUrlLength += range.length

          statusText.addAttributes(
            [
              .foregroundColor: UIColor(theme?.tintColor ?? .brand),
              .underlineStyle: NSUnderlineStyle.single.rawValue,
              .underlineColor: UIColor(theme?.tintColor ?? .brand),
            ],
            range: NSRange(location: range.location, length: range.length))
        }

        urlLengthAdjustments = totalUrlLength - (maxLengthOfUrl * numUrls)

        statusText.enumerateAttributes(in: range) { attributes, range, _ in
          if attributes[.link] != nil {
            statusText.removeAttribute(.link, range: range)
          }
        }
      } catch {}
    }

    // MARK: - Shar sheet / Item provider

    func processURLs(urls: [URL]) {
      isMediasLoading = true
      let items = urls.filter { $0.startAccessingSecurityScopedResource() }
        .compactMap { NSItemProvider(contentsOf: $0) }
      processItemsProvider(items: items)
    }

    func processGIFData(data: Data) {
      isMediasLoading = true
      let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).gif")
      try? data.write(to: url)
      let container = MediaContainer.pending(
        id: UUID().uuidString,
        gif: .init(url: url),
        preview: nil)
      prepareToPost(for: container)
    }

    func processCameraPhoto(image: UIImage) {
      let container = MediaContainer.pending(
        id: UUID().uuidString,
        image: image
      )
      prepareToPost(for: container)
    }

    private func processItemsProvider(items: [NSItemProvider]) {
      Task {
        var initialText: String = ""
        for item in items {
          if let identifier = item.registeredTypeIdentifiers.first {
            let handledItemType = UTTypeSupported(value: identifier)
            do {
              let compressor = Compressor()
              let content = try await handledItemType.loadItemContent(item: item)
              if let text = content as? String {
                initialText += "\(text) "
              } else if let image = content as? UIImage {
                let container = MediaContainer.pending(
                  id: UUID().uuidString,
                  image: image
                )
                prepareToPost(for: container)
              } else if let content = content as? ImageFileTranseferable,
                let compressedData = await compressor.compressImageFrom(url: content.url),
                let image = UIImage(data: compressedData)
              {
                let container = MediaContainer.pending(
                  id: UUID().uuidString,
                  image: image
                )
                prepareToPost(for: container)
              } else if let video = content as? MovieFileTranseferable {
                let container = MediaContainer.pending(
                  id: UUID().uuidString,
                  video: video,
                  preview: await Self.extractVideoPreview(from: video.url)
                )
                prepareToPost(for: container)
              } else if let gif = content as? GifFileTranseferable {
                let container = MediaContainer.pending(
                  id: UUID().uuidString,
                  gif: gif,
                  preview: nil
                )
                prepareToPost(for: container)
              }
            } catch {
              isMediasLoading = false
            }
          }
        }
        if !initialText.isEmpty {
          statusText = .init(string: "\n\n\(initialText)")
          selectedRange = .init(location: 0, length: 0)
        }
      }
    }

    // MARK: - Polls

    func resetPollDefaults() {
      pollOptions = ["", ""]
      pollDuration = .oneDay
      pollVotingFrequency = .oneVote
    }

    private func getPollOptionsForAPI() -> [String]? {
      let options = pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      return options.isEmpty ? nil : options
    }

    // MARK: - Embeds

    private func checkEmbed() {
      if let url = embeddedStatusURL,
        currentInstance?.isQuoteSupported == false,
        !statusText.string.contains(url.absoluteString)
      {
        embeddedStatus = nil
        mode = .new(text: nil, visibility: visibility)
      }
    }

    // MARK: - Autocomplete

    private func loadAutoCompleteResults(query: String) {
      guard let client else { return }
      var query = query
      suggestedTask?.cancel()
      suggestedTask = Task {
        do {
          var results: SearchResults?
          switch query.first {
          case "#":
            if query.utf8.count == 1 {
              withAnimation {
                showRecentsTagsInline = true
              }
              return
            }
            showRecentsTagsInline = false
            query.removeFirst()
            results = try await client.get(
              endpoint: Search.search(
                query: query,
                type: .hashtags,
                offset: 0,
                following: nil),
              forceVersion: .v2)
            guard !Task.isCancelled else {
              return
            }
            withAnimation {
              tagsSuggestions = results?.hashtags.sorted(by: { $0.totalUses > $1.totalUses }) ?? []
            }
          case "@":
            guard query.utf8.count > 1 else { return }
            query.removeFirst()
            let accounts: [Account] = try await client.get(
              endpoint: Search.accountsSearch(
                query: query,
                type: nil,
                offset: 0,
                following: nil),
              forceVersion: .v1)
            guard !Task.isCancelled else {
              return
            }
            withAnimation {
              mentionsSuggestions = accounts
            }
          default:
            break
          }
        } catch {}
      }
    }

    private func resetAutoCompletion() {
      if !tagsSuggestions.isEmpty || !mentionsSuggestions.isEmpty || currentSuggestionRange != nil
        || showRecentsTagsInline
      {
        withAnimation {
          tagsSuggestions = []
          mentionsSuggestions = []
          currentSuggestionRange = nil
          showRecentsTagsInline = false
        }
      }
    }

    func selectMentionSuggestion(account: Account) {
      if let range = currentSuggestionRange {
        replaceTextWith(text: "@\(account.acct) ", inRange: range)
      }
    }

    func selectHashtagSuggestion(tag: String) {
      if let range = currentSuggestionRange {
        var tag = tag
        if tag.hasPrefix("#") {
          tag.removeFirst()
        }
        replaceTextWith(text: "#\(tag) ", inRange: range)
      }
    }

    // MARK: - Assistant Prompt

    @available(iOS 26.0, *)
    func runAssistant(prompt: AIPrompt) async {
      #if !targetEnvironment(macCatalyst)
        let assistant = Assistant()
        var newStream: LanguageModelSession.ResponseStream<String>?
        switch prompt {
        case .correct:
          newStream = await assistant.correct(message: statusText.string)
        case .emphasize:
          newStream = await assistant.emphasize(message: statusText.string)
        case .fit:
          newStream = await assistant.shorten(message: statusText.string)
        case .rewriteWithTone(let tone):
          newStream = await assistant.adjustTone(message: statusText.string, to: tone)
        }

        if let newStream {
          backupStatusText = statusText
          do {
            for try await content in newStream {
              replaceTextWith(text: content.content)
            }
          } catch {
            if let backupStatusText {
              replaceTextWith(text: backupStatusText.string)
            }
          }
        }
      #endif
    }

    // MARK: - 媒体相关方法

    /// 查找媒体容器的索引
    ///
    /// 在 mediaContainers 数组中查找指定容器的索引位置。
    ///
    /// - Parameter container: 要查找的媒体容器
    /// - Returns: 容器的索引，如果未找到返回 nil
    private func indexOf(container: MediaContainer) -> Int? {
      mediaContainers.firstIndex(where: { $0.id == container.id })
    }

    /// 准备发布照片选择器项
    ///
    /// 从照片库选择的项目准备上传。
    ///
    /// 处理流程：
    /// 1. 创建媒体容器（从 PhotosPickerItem）
    /// 2. 添加到容器列表
    /// 3. 上传到服务器
    /// 4. 更新加载状态
    ///
    /// - Parameter pickerItem: 照片选择器项
    ///
    /// 支持的媒体类型：
    /// - 图片（JPEG、PNG、HEIC 等）
    /// - GIF 动图
    /// - 视频（MP4、MOV 等）
    ///
    /// 使用高优先级任务确保快速响应。
    ///
    /// - Note: 此方法是异步的，不会阻塞 UI
    /// - Important: 媒体会自动压缩以符合服务器限制
    func prepareToPost(for pickerItem: PhotosPickerItem) {
      Task(priority: .high) {
        if let container = await makeMediaContainer(from: pickerItem) {
          self.mediaContainers.append(container)
          await upload(container: container)
          self.isMediasLoading = false
        }
      }
    }

    /// 准备发布媒体容器
    ///
    /// 准备已创建的媒体容器上传。
    ///
    /// 处理流程：
    /// 1. 添加容器到列表
    /// 2. 上传到服务器
    /// 3. 如果有预设的 Alt 文本，添加描述
    /// 4. 清理临时数据
    /// 5. 更新加载状态
    ///
    /// - Parameter container: 媒体容器
    ///
    /// 使用场景：
    /// - 从分享扩展接收媒体
    /// - 从 Intents 接收媒体
    /// - 粘贴图片
    ///
    /// Alt 文本处理：
    /// - 如果 containerIdToAltText 中有对应的描述，自动添加
    /// - 添加后从映射中移除，避免重复
    ///
    /// - Note: 使用高优先级任务确保快速上传
    func prepareToPost(for container: MediaContainer) {
      Task(priority: .high) {
        self.mediaContainers.append(container)
        await upload(container: container)
        if let desc = containerIdToAltText[container.id], !desc.isEmpty {
          await addDescription(container: container, description: desc)
          containerIdToAltText.removeValue(forKey: container.id)
        }
        self.isMediasLoading = false
      }
    }

    nonisolated func makeMediaContainer(from pickerItem: PhotosPickerItem) async -> MediaContainer?
    {
      await withTaskGroup(of: MediaContainer?.self, returning: MediaContainer?.self) { taskGroup in
        taskGroup.addTask(priority: .high) { await Self.makeImageContainer(from: pickerItem) }
        taskGroup.addTask(priority: .high) { await Self.makeGifContainer(from: pickerItem) }
        taskGroup.addTask(priority: .high) { await Self.makeMovieContainer(from: pickerItem) }

        for await container in taskGroup {
          if let container {
            taskGroup.cancelAll()
            return container
          }
        }

        return nil
      }
    }

    private static func makeGifContainer(from pickerItem: PhotosPickerItem) async -> MediaContainer?
    {
      guard let gifFile = try? await pickerItem.loadTransferable(type: GifFileTranseferable.self)
      else { return nil }

      // Try to extract a preview image from the GIF
      let previewImage: UIImage? = nil  // GIFs typically show animated preview

      return MediaContainer.pending(
        id: pickerItem.itemIdentifier ?? UUID().uuidString,
        gif: gifFile,
        preview: previewImage
      )
    }

    private static func makeMovieContainer(from pickerItem: PhotosPickerItem) async
      -> MediaContainer?
    {
      guard
        let movieFile = try? await pickerItem.loadTransferable(type: MovieFileTranseferable.self)
      else { return nil }

      // Extract preview frame from video
      let previewImage = await extractVideoPreview(from: movieFile.url)

      return MediaContainer.pending(
        id: pickerItem.itemIdentifier ?? UUID().uuidString,
        video: movieFile,
        preview: previewImage
      )
    }

    private static func makeImageContainer(from pickerItem: PhotosPickerItem) async
      -> MediaContainer?
    {
      guard
        let imageFile = try? await pickerItem.loadTransferable(type: ImageFileTranseferable.self)
      else { return nil }

      let compressor = Compressor()

      guard let compressedData = await compressor.compressImageFrom(url: imageFile.url),
        let image = UIImage(data: compressedData)
      else { return nil }

      return MediaContainer.pending(
        id: pickerItem.itemIdentifier ?? UUID().uuidString,
        image: image
      )
    }

    private static func makeImageContainer(from urls: [URL]) async -> [MediaContainer] {
      var containers: [MediaContainer] = []

      for url in urls {
        let compressor = Compressor()
        _ = url.startAccessingSecurityScopedResource()
        if let compressedData = await compressor.compressImageFrom(url: url),
          let image = UIImage(data: compressedData)
        {
          containers.append(
            MediaContainer.pending(
              id: UUID().uuidString,
              image: image
            )
          )
        }

        url.stopAccessingSecurityScopedResource()
      }

      return containers
    }

    private static func extractVideoPreview(from url: URL) async -> UIImage? {
      let asset = AVURLAsset(url: url)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true

      return await withCheckedContinuation { continuation in
        generator.generateCGImageAsynchronously(for: .zero) { cgImage, _, error in
          if let cgImage = cgImage {
            continuation.resume(returning: UIImage(cgImage: cgImage))
          } else {
            continuation.resume(returning: nil)
          }
        }
      }
    }

    /// 上传媒体容器
    ///
    /// 将媒体容器中的内容上传到 Mastodon 服务器。
    ///
    /// 上传流程：
    /// 1. **验证状态**：只上传处于 pending 状态的容器
    /// 2. **更新状态**：设置为 uploading 状态
    /// 3. **压缩媒体**：
    ///    - 图片：压缩为 JPEG 格式
    ///    - 视频：转码和压缩
    ///    - GIF：保持原格式
    /// 4. **上传到服务器**：使用 multipart/form-data
    /// 5. **更新进度**：实时更新上传进度
    /// 6. **更新状态**：上传成功后设置为 uploaded 状态
    /// 7. **错误处理**：上传失败设置为 error 状态
    ///
    /// - Parameter container: 要上传的媒体容器
    ///
    /// 媒体类型处理：
    /// - **图片**：
    ///   - 压缩为 JPEG 格式
    ///   - 自动调整大小以符合服务器限制
    ///   - MIME 类型：image/jpeg
    ///
    /// - **视频**：
    ///   - 转码为 H.264 编码
    ///   - 压缩以减小文件大小
    ///   - 自动检测 MIME 类型
    ///
    /// - **GIF**：
    ///   - 保持原格式
    ///   - MIME 类型：image/gif
    ///
    /// 进度回调：
    /// - 使用闭包实时更新上传进度
    /// - 进度值范围：0.0 到 1.0
    /// - 在主线程更新 UI
    ///
    /// 错误处理：
    /// - 压缩失败：MediaError.compressionFailed
    /// - 上传失败：显示错误状态
    /// - 网络错误：自动重试或显示错误
    ///
    /// - Note: 此方法是异步的，不会阻塞 UI
    /// - Important: 上传前会自动压缩媒体以符合服务器限制
    /// - SeeAlso: `uploadMedia(data:mimeType:progress:)` - 实际的上传方法
    func upload(container: MediaContainer) async {
      guard let index = indexOf(container: container) else { return }
      let originalContainer = mediaContainers[index]

      // 只上传处于 pending 状态的容器
      guard case .pending(let content) = originalContainer.state else { return }

      // Set to uploading state
      mediaContainers[index] = MediaContainer(
        id: originalContainer.id,
        state: .uploading(content: content, progress: 0.0)
      )

      do {
        let compressor = Compressor()
        let uploadedMedia: MediaAttachment?

        switch content {
        case .image(let image):
          let imageData = try await compressor.compressImageForUpload(image)
          uploadedMedia = try await uploadMedia(data: imageData, mimeType: "image/jpeg") {
            [weak self] progress in
            guard let self else { return }
            Task { @MainActor in
              if let index = self.indexOf(container: originalContainer) {
                self.mediaContainers[index] = MediaContainer(
                  id: originalContainer.id,
                  state: .uploading(content: content, progress: progress)
                )
              }
            }
          }

        case .video(let transferable, _):
          let videoURL = transferable.url
          guard let compressedVideoURL = await compressor.compressVideo(videoURL),
            let data = try? Data(contentsOf: compressedVideoURL)
          else {
            throw MediaContainer.MediaError.compressionFailed
          }
          uploadedMedia = try await uploadMedia(data: data, mimeType: compressedVideoURL.mimeType())
          { [weak self] progress in
            guard let self else { return }
            Task { @MainActor in
              if let index = self.indexOf(container: originalContainer) {
                self.mediaContainers[index] = MediaContainer(
                  id: originalContainer.id,
                  state: .uploading(content: content, progress: progress)
                )
              }
            }
          }

        case .gif(let transferable, _):
          guard let gifData = transferable.data else {
            throw MediaContainer.MediaError.compressionFailed
          }
          uploadedMedia = try await uploadMedia(data: gifData, mimeType: "image/gif") {
            [weak self] progress in
            guard let self else { return }
            Task { @MainActor in
              if let index = self.indexOf(container: originalContainer) {
                self.mediaContainers[index] = MediaContainer(
                  id: originalContainer.id,
                  state: .uploading(content: content, progress: progress)
                )
              }
            }
          }
        }

        if let index = indexOf(container: originalContainer),
          let uploadedMedia
        {
          // Update to uploaded state
          mediaContainers[index] = MediaContainer.uploaded(
            id: originalContainer.id,
            attachment: uploadedMedia,
            originalImage: mode.isInShareExtension ? content.previewImage : nil
          )

          // Schedule refresh if URL is not ready
          if uploadedMedia.url == nil {
            scheduleAsyncMediaRefresh(mediaAttachement: uploadedMedia)
          }
        }
      } catch {
        if let index = indexOf(container: originalContainer) {
          // Update to failed state
          let mediaError: MediaContainer.MediaError
          if let serverError = error as? ServerError {
            mediaError = .uploadFailed(serverError)
          } else {
            mediaError = .compressionFailed
          }

          mediaContainers[index] = MediaContainer.failed(
            id: originalContainer.id,
            content: content,
            error: mediaError
          )
        }
      }
    }

    private func scheduleAsyncMediaRefresh(mediaAttachement: MediaAttachment) {
      Task {
        repeat {
          if let client,
            let index = mediaContainers.firstIndex(where: {
              $0.mediaAttachment?.id == mediaAttachement.id
            })
          {
            guard mediaContainers[index].mediaAttachment?.url == nil else {
              return
            }
            do {
              let newAttachement: MediaAttachment = try await client.get(
                endpoint: Media.media(
                  id: mediaAttachement.id,
                  json: nil))
              if newAttachement.url != nil {
                let oldContainer = mediaContainers[index]
                if case .uploaded(_, let originalImage) = oldContainer.state {
                  mediaContainers[index] = MediaContainer.uploaded(
                    id: oldContainer.id,
                    attachment: newAttachement,
                    originalImage: originalImage
                  )
                }
              }
            } catch {}
          }
          try? await Task.sleep(for: .seconds(5))
        } while !Task.isCancelled
      }
    }

    /// 添加媒体描述（Alt 文本）
    ///
    /// 为已上传的媒体添加无障碍描述文本。
    ///
    /// 处理流程：
    /// 1. 验证容器已上传
    /// 2. 调用 API 更新媒体描述
    /// 3. 更新本地容器状态
    ///
    /// - Parameters:
    ///   - container: 媒体容器
    ///   - description: Alt 文本描述
    ///
    /// Alt 文本的重要性：
    /// - 为视障用户提供图片描述
    /// - 提高内容的可访问性
    /// - 某些实例要求必须添加 Alt 文本
    ///
    /// API 调用：
    /// - PUT /api/v1/media/:id
    /// - 更新媒体附件的描述字段
    ///
    /// 使用场景：
    /// - 用户在媒体编辑界面添加描述
    /// - 从 Intents 恢复预设的描述
    /// - 编辑已有的描述
    ///
    /// - Note: 只能为已上传的媒体添加描述
    /// - Important: 建议为所有媒体添加 Alt 文本以提高可访问性
    func addDescription(container: MediaContainer, description: String) async {
      guard let client,
        let index = indexOf(container: container)
      else { return }

      let state = mediaContainers[index].state
      guard case .uploaded(let attachment, let originalImage) = state else { return }

      do {
        let media: MediaAttachment = try await client.put(
          endpoint: Media.media(
            id: attachment.id,
            json: .init(description: description)))
        mediaContainers[index] = MediaContainer.uploaded(
          id: mediaContainers[index].id,
          attachment: media,
          originalImage: originalImage
        )
      } catch {}
    }

    /// 媒体属性列表
    ///
    /// 存储待更新的媒体属性（描述、焦点等）。
    /// 在编辑帖子时使用，批量更新媒体属性。
    private var mediaAttributes: [StatusData.MediaAttribute] = []

    /// 编辑媒体描述
    ///
    /// 在编辑模式下更新媒体描述。
    /// 与 addDescription 不同，此方法不立即调用 API，
    /// 而是将更改添加到 mediaAttributes 列表，
    /// 在发布时一起提交。
    ///
    /// - Parameters:
    ///   - container: 媒体容器
    ///   - description: 新的描述文本
    ///
    /// 使用场景：
    /// - 编辑已发布的帖子
    /// - 批量更新多个媒体的描述
    ///
    /// - Note: 更改会在调用 postStatus() 时提交
    func editDescription(container: MediaContainer, description: String) async {
      guard let attachment = container.mediaAttachment else { return }
      if indexOf(container: container) != nil {
        mediaAttributes.append(
          StatusData.MediaAttribute(
            id: attachment.id, description: description, thumbnail: nil, focus: nil))
      }
    }

    /// 上传媒体数据
    ///
    /// 将媒体数据上传到 Mastodon 服务器的底层方法。
    ///
    /// - Parameters:
    ///   - data: 媒体数据（已压缩）
    ///   - mimeType: MIME 类型（image/jpeg、video/mp4 等）
    ///   - progressHandler: 进度回调（0.0 到 1.0）
    ///
    /// - Returns: 上传成功返回 MediaAttachment，失败返回 nil
    /// - Throws: 网络错误或服务器错误
    ///
    /// API 调用：
    /// - POST /api/v2/media
    /// - 使用 multipart/form-data 格式
    ///
    /// 进度回调：
    /// - 实时报告上传进度
    /// - 在后台线程调用
    /// - 需要切换到主线程更新 UI
    ///
    /// - Note: 此方法是私有的，由 upload(container:) 调用
    /// - Important: 数据应该已经压缩，以符合服务器限制
    private func uploadMedia(
      data: Data, mimeType: String, progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> MediaAttachment? {
      guard let client else { return nil }
      return try await client.mediaUpload(
        endpoint: Media.medias,
        version: .v2,
        method: "POST",
        mimeType: mimeType,
        filename: "file",
        data: data,
        progressHandler: progressHandler)
    }

    // MARK: - 自定义表情

    /// 获取自定义表情
    ///
    /// 从 Mastodon 实例获取自定义表情列表并按分类组织。
    ///
    /// 处理流程：
    /// 1. **获取表情列表**：调用 API 获取所有自定义表情
    /// 2. **按分类分组**：将表情按 category 分组
    /// 3. **排序分类**：
    ///    - "Custom" 分类排在最前面
    ///    - 其他分类按字母顺序排序
    /// 4. **创建容器**：为每个分类创建 EmojiContainer
    /// 5. **更新状态**：更新 customEmojiContainer
    ///
    /// API 调用：
    /// - GET /api/v1/custom_emojis
    /// - 返回实例的所有自定义表情
    ///
    /// 分类处理：
    /// - 如果表情没有分类，归入 "Custom"
    /// - "Custom" 分类始终显示在最前面
    /// - 其他分类按字母顺序排序
    ///
    /// 使用场景：
    /// - 编辑器初始化时
    /// - 用户打开表情选择器时
    /// - 切换账户或实例时
    ///
    /// 自定义表情的特点：
    /// - 每个实例可以定义自己的表情
    /// - 表情可以是静态图片或动画 GIF
    /// - 表情有短代码（如 :blobcat:）
    /// - 可以按分类组织（如 "动物"、"食物" 等）
    ///
    /// 表情选择器：
    /// - 按分类显示表情
    /// - 支持搜索和过滤
    /// - 点击插入到文本中
    ///
    /// - Note: 此方法是异步的，不会阻塞 UI
    /// - Important: 不同实例有不同的自定义表情
    /// - SeeAlso: `CategorizedEmojiContainer` - 分类表情容器
    func fetchCustomEmojis() async {
      typealias EmojiContainer = CategorizedEmojiContainer

      guard let client else { return }
      do {
        let customEmojis: [Emoji] = try await client.get(endpoint: CustomEmojis.customEmojis) ?? []
        var emojiContainers: [EmojiContainer] = []

        customEmojis.reduce([String: [Emoji]]()) { currentDict, emoji in
          var dict = currentDict
          let category = emoji.category ?? "Custom"

          if let emojis = dict[category] {
            dict[category] = emojis + [emoji]
          } else {
            dict[category] = [emoji]
          }

          return dict
        }.sorted(by: { lhs, rhs in
          if rhs.key == "Custom" {
            false
          } else if lhs.key == "Custom" {
            true
          } else {
            lhs.key < rhs.key
          }
        }).forEach { key, value in
          emojiContainers.append(.init(categoryName: key, emojis: value))
        }

        customEmojiContainer = emojiContainers
      } catch {}
    }
  }
}

// MARK: - DropDelegate

extension StatusEditor.ViewModel: DropDelegate {
  public func performDrop(info: DropInfo) -> Bool {
    let item = info.itemProviders(for: [.image, .video, .gif, .mpeg4Movie, .quickTimeMovie, .movie])
    processItemsProvider(items: item)
    return true
  }
}

// MARK: - UITextPasteDelegate

extension StatusEditor.ViewModel: UITextPasteDelegate {
  public func textPasteConfigurationSupporting(
    _: UITextPasteConfigurationSupporting,
    transform item: UITextPasteItem
  ) {
    if !item.itemProvider.registeredContentTypes(conformingTo: .image).isEmpty
      || !item.itemProvider.registeredContentTypes(conformingTo: .video).isEmpty
      || !item.itemProvider.registeredContentTypes(conformingTo: .gif).isEmpty
    {
      processItemsProvider(items: [item.itemProvider])
      item.setNoResult()
    } else {
      item.setDefaultResult()
    }
  }
}
