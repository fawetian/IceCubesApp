// 文件功能：应用图标选择器，用户可从多组设计师作品中选择自定义应用图标。
// 相关技术点：
// - SwiftUI 网格布局：LazyVGrid 自适应网格显示图标。
// - @State 状态管理：跟踪当前选中图标。
// - @Environment：主题注入。
// - UIApplication API：设置应用备用图标。
// - 枚举与协议：Icon 枚举实现 CaseIterable、Identifiable。
// - 条件编译：适配 visionOS。
// - 扩展与本地化：String 扩展支持本地化。
//
// 技术点详解：
// 1. 备用图标：iOS 10.3+ 支持动态更换应用图标。
// 2. LazyVGrid：延迟加载网格，性能优化，支持自适应列宽。
// 3. GridItem：网格项配置，adaptive 自适应宽度。
// 4. UIApplication.setAlternateIconName：系统 API 设置备用图标。
// 5. ZStack：层叠布局，用于添加选中状态标识。
// 6. buttonStyle(.plain)：移除按钮默认样式。
// 7. 本地化字符串：NSLocalizedString 支持多语言。
import DesignSystem
// 导入设计系统，包含主题、控件等
import SwiftUI

// 导入 SwiftUI 框架

// 主线程下定义图标选择器视图
@MainActor
struct IconSelectorView: View {
  // 图标枚举，包含所有可用的应用图标
  enum Icon: Int, CaseIterable, Identifiable {
    // 实现 Identifiable 协议，提供唯一标识
    var id: String {
      "\(rawValue)"
    }

    // 通过字符串初始化图标枚举
    init(string: String) {
      if string == "AppIcon" {
        self = .primary
      } else {
        self = .init(rawValue: Int(String(string.replacing("AppIconAlternate", with: "")))!)!
      }
    }

    // 定义所有图标选项
    case primary = 0
    case alt1, alt2, alt3, alt4
    
    // Unused icons.
    case alt5, alt6, alt7, alt8
    case alt9, alt10, alt11, alt12, alt13
    case alt14, alt15, alt17, atl18, alt19
    
    case alt16, alt20, alt21
    case alt22, alt23, alt24, alt25, alt26
    case alt27, alt28, alt29
    case alt30, alt31, alt32, alt33, alt34, alt35, alt36
    case alt37
    case alt38
    case alt39, alt40, alt41, alt42, alt43
    case alt44, alt45
    case alt46, alt47, alt48
    case alt49

    // 获取应用图标名称
    var appIconName: String {
      return "AppIconAlternate\(rawValue)"
    }

    // 获取预览图像名称
    var previewImageName: String {
      return "AppIconAlternate\(rawValue)-image"
    }
  }

  // 图标选择器数据结构，按设计师分组
  struct IconSelector: Identifiable {
    var id = UUID()
    let title: String
    let icons: [Icon]

    // 静态数据：所有图标分组
    static let items = [
      // 官方图标组
      IconSelector(
        title: "settings.app.icon.official".localized,
        icons: [
          .primary, .alt46, .alt1, .alt3, .alt4
        ]),
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Erich Jurgens",
        icons: [
          .alt2
        ]),
      // Albert Kinng 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Albert Kinng",
        icons: [.alt22, .alt23, .alt24, .alt25, .alt26]),
      // Dan van Moll 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Dan van Moll",
        icons: [.alt27, .alt28, .alt29]),
      // Chanhwi Joo 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Chanhwi Joo (GitHub @te6-in)",
        icons: [.alt30, .alt31, .alt32, .alt33, .alt34, .alt35, .alt36]),
      // W. Kovács Ágnes 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) W. Kovács Ágnes (@wildgica)",
        icons: [.alt37]),
      // Duncan Horne 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Duncan Horne", icons: [.alt38]),
      // BeAware 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) BeAware@social.beaware.live",
        icons: [.alt39, .alt40, .alt41, .alt42, .alt43]),
      // Simone Margio 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Simone Margio",
        icons: [.alt44, .alt45]),
      // Peter Broqvist 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Peter Broqvist (@PKB)",
        icons: [.alt47, .alt48]),
      // Oz Tsori 设计的图标
      IconSelector(
        title: "\("settings.app.icon.designed-by".localized) Oz Tsori (@oztsori)", icons: [.alt49]),
    ]
  }

  // 注入主题
  @Environment(Theme.self) private var theme
  // 当前选中的图标状态
  @State private var currentIcon =
    UIApplication.shared.alternateIconName ?? Icon.primary.appIconName

  // 网格列配置：自适应宽度，最小 125，最大 1024
  private let columns = [GridItem(.adaptive(minimum: 125, maximum: 1024))]

  // 主体视图
  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        // 遍历所有图标分组
        ForEach(IconSelector.items) { item in
          Section {
            // 创建图标网格视图
            makeIconGridView(icons: item.icons)
          } header: {
            // 分组标题
            Text(item.title)
              .font(.scaledHeadline)
          }
        }
      }
      .padding(6)
      // 设置导航标题
      .navigationTitle("settings.app.icon.navigation-title")
    }
    #if !os(visionOS)
      // 设置背景色为主题主背景色
      .background(theme.primaryBackgroundColor)
    #endif
  }

  // 创建图标网格视图
  private func makeIconGridView(icons: [Icon]) -> some View {
    LazyVGrid(columns: columns, spacing: 6) {
      // 遍历图标数组
      ForEach(icons) { icon in
        // 图标选择按钮
        Button {
          // 更新当前选中图标
          currentIcon = icon.appIconName
          // 设置应用图标
          if icon.rawValue == Icon.primary.rawValue {
            // 恢复默认图标
            UIApplication.shared.setAlternateIconName(nil)
          } else {
            // 设置备用图标
            UIApplication.shared.setAlternateIconName(icon.appIconName) { err in
              guard let err else { return }
              // 错误处理：打印图标设置失败信息
              assertionFailure("\(err.localizedDescription) - Icon name: \(icon.appIconName)")
            }
          }
        } label: {
          // 图标显示区域，使用层叠布局
          ZStack(alignment: .bottomTrailing) {
            // 图标预览图片
            Image(icon.previewImageName)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(minHeight: 125, maxHeight: 1024)
              .cornerRadius(6)
              .shadow(radius: 3)
            // 选中状态标识
            if icon.appIconName == currentIcon {
              Image(systemName: "checkmark.seal.fill")
                .padding(4)
                .tint(.green)
            }
          }
        }
        // 移除按钮默认样式
        .buttonStyle(.plain)
      }
    }
  }
}

// String 扩展：添加本地化支持
extension String {
  // 获取本地化字符串
  var localized: String {
    NSLocalizedString(self, comment: "")
  }
}
