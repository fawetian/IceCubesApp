/*
 * Theme.swift
 * IceCubesApp - 主题系统
 *
 * 文件功能：
 * 管理应用的全局主题设置，包括颜色方案、字体、布局和显示样式。
 *
 * 核心职责：
 * - 提供颜色集切换和自定义颜色设置
 * - 管理头像位置、形状和状态显示样式
 * - 控制字体选择和缩放
 * - 持久化所有主题设置到 UserDefaults
 * - 计算对比色以确保可访问性
 *
 * 技术要点：
 * - @Observable + @MainActor 确保 UI 线程安全
 * - @AppStorage 自动持久化设置
 * - 单例模式 (shared) 全局访问
 * - didSet 观察器同步内存与存储
 * - 亮度计算确保色彩对比度
 *
 * 使用场景：
 * - 应用启动时初始化主题
 * - 设置页面修改主题选项
 * - 所有视图通过 @Environment(Theme.self) 访问
 *
 * 依赖关系：
 * - SwiftUI: Color、@AppStorage
 * - Combine: 响应式更新（虽然现在主要用 @Observable）
 */

import Combine
import SwiftUI

/// 应用主题管理类。
///
/// 单例模式，管理所有主题相关设置和颜色方案。
@MainActor
@Observable
public final class Theme {
  /// 主题存储类（封装所有 @AppStorage 属性）。
  final class ThemeStorage {
    /// UserDefaults 存储键枚举。
    enum ThemeKey: String {
      case colorScheme, tint, label, primaryBackground, secondaryBackground
      case avatarPosition2, avatarShape2, statusActionsDisplay, statusDisplayStyle
      case selectedSet, selectedScheme
      case followSystemColorSchme
      case displayFullUsernameTimeline
      case lineSpacing
      case statusActionSecondary
      case contentGradient
      case compactLayoutPadding
    }

    @AppStorage("is_previously_set") public var isThemePreviouslySet: Bool = false
    @AppStorage(ThemeKey.selectedScheme.rawValue) public var selectedScheme: ColorScheme = .dark
    @AppStorage(ThemeKey.tint.rawValue) public var tintColor: Color = .black
    @AppStorage(ThemeKey.primaryBackground.rawValue) public var primaryBackgroundColor: Color =
      .white
    @AppStorage(ThemeKey.secondaryBackground.rawValue) public var secondaryBackgroundColor: Color =
      .gray
    @AppStorage(ThemeKey.label.rawValue) public var labelColor: Color = .black
    @AppStorage(ThemeKey.avatarPosition2.rawValue) var avatarPosition: AvatarPosition = .leading
    @AppStorage(ThemeKey.avatarShape2.rawValue) var avatarShape: AvatarShape = .circle
    @AppStorage(ThemeKey.selectedSet.rawValue) var storedSet: ColorSetName = .iceCubeDark
    @AppStorage(ThemeKey.statusActionsDisplay.rawValue) public var statusActionsDisplay:
      StatusActionsDisplay = .full
    @AppStorage(ThemeKey.statusDisplayStyle.rawValue) public var statusDisplayStyle:
      StatusDisplayStyle = .large
    @AppStorage(ThemeKey.followSystemColorSchme.rawValue) public var followSystemColorScheme: Bool =
      true
    @AppStorage(ThemeKey.displayFullUsernameTimeline.rawValue) public var displayFullUsername:
      Bool = false
    @AppStorage(ThemeKey.lineSpacing.rawValue) public var lineSpacing: Double = 1.2
    @AppStorage(ThemeKey.statusActionSecondary.rawValue) public var statusActionSecondary:
      StatusActionSecondary = .share
    @AppStorage(ThemeKey.compactLayoutPadding.rawValue) public var compactLayoutPadding: Bool = true
    @AppStorage("font_size_scale") public var fontSizeScale: Double = 1
    @AppStorage("chosen_font") public var chosenFontData: Data?

    init() {}
  }

  /// 字体类型枚举。
  public enum FontState: Int, CaseIterable {
    /// 系统默认字体。
    case system
    /// Open Dyslexic 字体（辅助阅读障碍）。
    case openDyslexic
    /// Atkinson Hyperlegible 字体（高可读性）。
    case hyperLegible
    /// SF Rounded 字体（圆角系统字体）。
    case SFRounded
    /// 自定义字体。
    case custom

    /// 返回本地化标题。
    public var title: LocalizedStringKey {
      switch self {
      case .system:
        "settings.display.font.system"
      case .openDyslexic:
        "Open Dyslexic"
      case .hyperLegible:
        "Hyper Legible"
      case .SFRounded:
        "SF Rounded"
      case .custom:
        "settings.display.font.custom"
      }
    }
  }

  /// 头像位置枚举。
  public enum AvatarPosition: String, CaseIterable {
    /// 左侧显示头像（默认）。
    case leading
    /// 顶部显示头像。
    case top

    /// 返回本地化描述。
    public var description: LocalizedStringKey {
      switch self {
      case .leading:
        "enum.avatar-position.leading"
      case .top:
        "enum.avatar-position.top"
      }
    }
  }

  /// 次要状态操作枚举（分享或书签）。
  public enum StatusActionSecondary: String, CaseIterable {
    /// 分享按钮。
    case share
    /// 书签按钮。
    case bookmark

    /// 返回本地化描述。
    public var description: LocalizedStringKey {
      switch self {
      case .share:
        "status.action.share-title"
      case .bookmark:
        "status.action.bookmark"
      }
    }
  }

  /// 头像形状枚举。
  public enum AvatarShape: String, CaseIterable {
    /// 圆形头像。
    case circle
    /// 圆角矩形头像。
    case rounded

    /// 返回本地化描述。
    public var description: LocalizedStringKey {
      switch self {
      case .circle:
        "enum.avatar-shape.circle"
      case .rounded:
        "enum.avatar-shape.rounded"
      }
    }
  }

  /// 状态操作显示模式枚举。
  public enum StatusActionsDisplay: String, CaseIterable {
    /// 完整显示（按钮 + 数字）。
    case full
    /// 离散显示（仅按钮）。
    case discret
    /// 不显示操作按钮。
    case none

    /// 返回本地化描述。
    public var description: LocalizedStringKey {
      switch self {
      case .full:
        "enum.status-actions-display.all"
      case .discret:
        "enum.status-actions-display.only-buttons"
      case .none:
        "enum.status-actions-display.no-buttons"
      }
    }
  }

  /// 状态显示样式枚举。
  public enum StatusDisplayStyle: String, CaseIterable {
    /// 大号显示（默认）。
    case large
    /// 中号显示。
    case medium
    /// 紧凑显示。
    case compact

    /// 返回本地化描述。
    public var description: LocalizedStringKey {
      switch self {
      case .large:
        "enum.status-display-style.large"
      case .medium:
        "enum.status-display-style.medium"
      case .compact:
        "enum.status-display-style.compact"
      }
    }
  }

  /// 缓存的自定义字体对象。
  private var _cachedChoosenFont: UIFont?
  /// 用户选择的自定义字体（使用 NSKeyedArchiver 序列化）。
  public var chosenFont: UIFont? {
    get {
      if let _cachedChoosenFont {
        return _cachedChoosenFont
      }
      guard let chosenFontData,
        let font = try? NSKeyedUnarchiver.unarchivedObject(
          ofClass: UIFont.self, from: chosenFontData)
      else { return nil }

      _cachedChoosenFont = font
      return font
    }
    set {
      if let font = newValue,
        let data = try? NSKeyedArchiver.archivedData(
          withRootObject: font, requiringSecureCoding: false)
      {
        chosenFontData = data
      } else {
        chosenFontData = nil
      }
      _cachedChoosenFont = nil
    }
  }

  /// 主题存储实例。
  let themeStorage = ThemeStorage()

  /// 是否曾经设置过主题（用于首次启动检测）。
  public var isThemePreviouslySet: Bool {
    didSet {
      themeStorage.isThemePreviouslySet = isThemePreviouslySet
    }
  }

  /// 选择的颜色方案（深色/浅色）。
  public var selectedScheme: ColorScheme {
    didSet {
      themeStorage.selectedScheme = selectedScheme
    }
  }

  /// 主题色（强调色）。
  public var tintColor: Color {
    didSet {
      themeStorage.tintColor = tintColor
      computeContrastingTintColor()
    }
  }

  /// 主背景色。
  public var primaryBackgroundColor: Color {
    didSet {
      themeStorage.primaryBackgroundColor = primaryBackgroundColor
      computeContrastingTintColor()
    }
  }

  /// 次背景色（卡片、分隔等）。
  public var secondaryBackgroundColor: Color {
    didSet {
      themeStorage.secondaryBackgroundColor = secondaryBackgroundColor
    }
  }

  /// 标签文本颜色。
  public var labelColor: Color {
    didSet {
      themeStorage.labelColor = labelColor
      computeContrastingTintColor()
    }
  }

  /// 对比主题色（自动计算以确保可访问性）。
  public private(set) var contrastingTintColor: Color

  /// 计算对比主题色（选择与 tintColor 对比度更高的颜色）。
  ///
  /// 使用亮度算法判断 labelColor 和 primaryBackgroundColor 哪个与 tintColor 对比度更好。
  private func computeContrastingTintColor() {
    func luminance(_ color: Color.Resolved) -> Float {
      return 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
    }

    let resolvedTintColor = tintColor.resolve(in: .init())
    let resolvedLabelColor = labelColor.resolve(in: .init())
    let resolvedPrimaryBackgroundColor = primaryBackgroundColor.resolve(in: .init())

    let tintLuminance = luminance(resolvedTintColor)
    let labelLuminance = luminance(resolvedLabelColor)
    let primaryBackgroundLuminance = luminance(resolvedPrimaryBackgroundColor)

    if abs(tintLuminance - labelLuminance) > abs(tintLuminance - primaryBackgroundLuminance) {
      contrastingTintColor = labelColor
    } else {
      contrastingTintColor = primaryBackgroundColor
    }
  }

  public var avatarPosition: AvatarPosition {
    didSet {
      themeStorage.avatarPosition = avatarPosition
    }
  }

  public var avatarShape: AvatarShape {
    didSet {
      themeStorage.avatarShape = avatarShape
    }
  }

  private var storedSet: ColorSetName {
    didSet {
      themeStorage.storedSet = storedSet
    }
  }

  public var statusActionsDisplay: StatusActionsDisplay {
    didSet {
      themeStorage.statusActionsDisplay = statusActionsDisplay
    }
  }

  public var statusDisplayStyle: StatusDisplayStyle {
    didSet {
      themeStorage.statusDisplayStyle = statusDisplayStyle
    }
  }

  public var statusActionSecondary: StatusActionSecondary {
    didSet {
      themeStorage.statusActionSecondary = statusActionSecondary
    }
  }

  public var followSystemColorScheme: Bool {
    didSet {
      themeStorage.followSystemColorScheme = followSystemColorScheme
    }
  }

  public var displayFullUsername: Bool {
    didSet {
      themeStorage.displayFullUsername = displayFullUsername
    }
  }

  public var lineSpacing: Double {
    didSet {
      themeStorage.lineSpacing = lineSpacing
    }
  }

  public var fontSizeScale: Double {
    didSet {
      themeStorage.fontSizeScale = fontSizeScale
    }
  }

  public private(set) var chosenFontData: Data? {
    didSet {
      themeStorage.chosenFontData = chosenFontData
    }
  }

  public var compactLayoutPadding: Bool {
    didSet {
      themeStorage.compactLayoutPadding = compactLayoutPadding
    }
  }

  /// 当前选择的颜色集名称。
  public var selectedSet: ColorSetName = .iceCubeDark

  /// 全局单例。
  public static let shared = Theme()

  /// 恢复默认主题设置。
  public func restoreDefault() {
    applySet(set: themeStorage.selectedScheme == .dark ? .iceCubeDark : .iceCubeLight)
    isThemePreviouslySet = true
    avatarPosition = .leading
    avatarShape = .circle
    storedSet = selectedSet
    statusActionsDisplay = .full
    statusDisplayStyle = .large
    followSystemColorScheme = true
    displayFullUsername = false
    lineSpacing = 1.2
    fontSizeScale = 1
    chosenFontData = nil
    statusActionSecondary = .share
  }

  private init() {
    isThemePreviouslySet = themeStorage.isThemePreviouslySet
    selectedScheme = themeStorage.selectedScheme
    tintColor = themeStorage.tintColor
    primaryBackgroundColor = themeStorage.primaryBackgroundColor
    secondaryBackgroundColor = themeStorage.secondaryBackgroundColor
    labelColor = themeStorage.labelColor
    contrastingTintColor = .red  // real work done in computeContrastingTintColor()
    avatarPosition = themeStorage.avatarPosition
    avatarShape = themeStorage.avatarShape
    storedSet = themeStorage.storedSet
    statusActionsDisplay = themeStorage.statusActionsDisplay
    statusDisplayStyle = themeStorage.statusDisplayStyle
    followSystemColorScheme = themeStorage.followSystemColorScheme
    displayFullUsername = themeStorage.displayFullUsername
    lineSpacing = themeStorage.lineSpacing
    fontSizeScale = themeStorage.fontSizeScale
    chosenFontData = themeStorage.chosenFontData
    statusActionSecondary = themeStorage.statusActionSecondary
    compactLayoutPadding = themeStorage.compactLayoutPadding
    selectedSet = storedSet

    computeContrastingTintColor()
  }

  /// 所有可用的颜色集。
  public static var allColorSet: [ColorSet] {
    [
      IceCubeDark(),
      IceCubeLight(),
      IceCubeNeonDark(),
      IceCubeNeonLight(),
      DesertDark(),
      DesertLight(),
      NemesisDark(),
      NemesisLight(),
      MediumLight(),
      MediumDark(),
      ConstellationLight(),
      ConstellationDark(),
      ThreadsLight(),
      ThreadsDark(),
    ]
  }

  /// 应用指定的颜色集。
  ///
  /// - Parameter set: 颜色集名称。
  public func applySet(set: ColorSetName) {
    selectedSet = set
    setColor(withName: set)
  }

  /// 根据颜色集名称设置所有颜色属性。
  ///
  /// - Parameter name: 颜色集名称。
  public func setColor(withName name: ColorSetName) {
    let colorSet = Theme.allColorSet.filter { $0.name == name }.first ?? IceCubeDark()
    selectedScheme = colorSet.scheme
    tintColor = colorSet.tintColor
    primaryBackgroundColor = colorSet.primaryBackgroundColor
    secondaryBackgroundColor = colorSet.secondaryBackgroundColor
    labelColor = colorSet.labelColor
    storedSet = name
  }
}
