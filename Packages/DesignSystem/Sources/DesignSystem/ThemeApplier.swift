// 文件功能说明：
// 该文件实现了主题应用器，负责将主题设置应用到整个应用的用户界面，包括颜色方案、色调、导航栏样式等全局视觉效果的统一管理。

// 技术点：
// 1. ViewModifier协议 —— SwiftUI自定义视图修饰符
// 2. @MainActor修饰符 —— 确保UI操作在主线程执行
// 3. @Environment环境值 —— 获取系统颜色方案状态
// 4. 条件编译 —— UIKit平台特定功能的条件导入
// 5. UIKit集成 —— 设置系统级UI样式和颜色
// 6. onChange修饰符 —— 响应主题属性变化
// 7. preferredColorScheme —— 控制SwiftUI颜色方案
// 8. UIAppearance代理 —— 全局UIKit组件样式设置
// 9. 窗口枚举 —— 遍历所有应用窗口应用设置
// 10. 主题首次设置逻辑 —— 应用安装后的默认主题初始化

// 技术点详解：
// 1. ViewModifier：SwiftUI协议，允许创建可重用的视图修饰器，封装复杂的样式逻辑
// 2. @MainActor：Swift并发安全特性，确保所有UI更新在主线程执行，避免崩溃
// 3. @Environment：SwiftUI环境系统，访问系统提供的环境值如颜色方案
// 4. 条件编译：#if canImport()检查平台能力，确保代码在不同平台正确编译
// 5. UIKit集成：通过UIColor、UIWindow等类设置系统级别的UI样式
// 6. onChange：SwiftUI修饰符，监听状态变化并执行相应的副作用操作
// 7. preferredColorScheme：SwiftUI修饰符，强制设置视图的颜色方案偏好
// 8. UIAppearance：UIKit的全局样式代理，设置所有同类组件的默认外观
// 9. 窗口枚举：通过UIApplication访问所有连接的场景和窗口，应用全局设置
// 10. 主题初始化：检测首次安装并设置默认主题，同时处理系统主题跟随逻辑

// 导入SwiftUI框架，提供视图修饰符和主题支持
import SwiftUI

// 条件导入UIKit，用于系统级UI样式设置
#if canImport(UIKit)
  import UIKit
#endif

// 扩展View类型，添加主题应用的便捷方法
extension View {
  // 公共方法：应用主题到视图
  @MainActor public func applyTheme(_ theme: Theme) -> some View {
    // 使用ThemeApplier修饰符包装视图
    modifier(ThemeApplier(theme: theme))
  }
}

// 主题应用器视图修饰符，负责将主题设置应用到UI
@MainActor
struct ThemeApplier: ViewModifier {
  // 从环境中获取系统颜色方案
  @Environment(\EnvironmentValues.colorScheme) var colorScheme

  // 要应用的主题对象
  var theme: Theme

  // 计算属性：确定实际使用的颜色方案
  var actualColorScheme: SwiftUI.ColorScheme? {
    if theme.followSystemColorScheme {
      // 如果跟随系统颜色方案，返回nil让系统决定
      return nil
    }
    // 否则根据主题设置返回对应的颜色方案
    return theme.selectedScheme == ColorScheme.dark ? .dark : .light
  }

  // ViewModifier协议要求的方法，定义如何修饰内容视图
  func body(content: Content) -> some View {
    content
      // 设置色调颜色
      .tint(theme.tintColor)
      // 设置首选颜色方案
      .preferredColorScheme(actualColorScheme)
      // UIKit平台特定设置
      #if canImport(UIKit)
        .onAppear {
          // 如果主题从未被设置过，设置默认主题（仅在安装后执行一次）
          if !theme.isThemePreviouslySet {
            // 根据当前系统颜色方案设置默认主题
            theme.applySet(set: colorScheme == .dark ? .iceCubeDark : .iceCubeLight)
            // 标记主题已被设置过
            theme.isThemePreviouslySet = true
          } else if theme.followSystemColorScheme, theme.isThemePreviouslySet,
            let sets =
              availableColorsSets
            .first(where: {
              // 查找匹配当前主题的颜色集合
              $0.light.name == theme.selectedSet || $0.dark.name == theme.selectedSet
            })
          {
            // 如果跟随系统颜色方案且已设置过主题，应用对应的颜色集
            theme.applySet(set: colorScheme == .dark ? sets.dark.name : sets.light.name)
          }
          // 设置窗口色调颜色
          setWindowTint(theme.tintColor)
          // 设置窗口用户界面样式
          setWindowUserInterfaceStyle(from: theme.selectedScheme)
          // 设置导航栏和工具栏颜色
          setBarsColor(theme.primaryBackgroundColor)
        }
        // 监听主题色调颜色变化
        .onChange(of: theme.tintColor) { _, newValue in
          setWindowTint(newValue)
        }
        // 监听主背景颜色变化
        .onChange(of: theme.primaryBackgroundColor) { _, newValue in
          setBarsColor(newValue)
        }
        // 监听主题颜色方案变化
        .onChange(of: theme.selectedScheme) { _, newValue in
          setWindowUserInterfaceStyle(from: newValue)
        }
        // 监听系统颜色方案变化
        .onChange(of: colorScheme) { _, newColorScheme in
          if theme.followSystemColorScheme,
            let sets =
              availableColorsSets
            .first(where: {
              // 查找匹配当前主题的颜色集合
              $0.light.name == theme.selectedSet || $0.dark.name == theme.selectedSet
            })
          {
            // 如果跟随系统颜色方案，根据新的系统方案应用对应主题
            theme.applySet(set: newColorScheme == .dark ? sets.dark.name : sets.light.name)
          }
        }
      #endif
  }

  // UIKit平台特定方法
  #if canImport(UIKit)
    // 根据颜色方案设置窗口用户界面样式
    private func setWindowUserInterfaceStyle(from colorScheme: ColorScheme) {
      guard !theme.followSystemColorScheme else {
        // 如果跟随系统颜色方案，设置为未指定让系统决定
        setWindowUserInterfaceStyle(.unspecified)
        return
      }
      // 根据颜色方案设置对应的用户界面样式
      switch colorScheme {
      case .dark:
        setWindowUserInterfaceStyle(.dark)
      case .light:
        setWindowUserInterfaceStyle(.light)
      }
    }

    // 设置所有窗口的用户界面样式
    private func setWindowUserInterfaceStyle(_ userInterfaceStyle: UIUserInterfaceStyle) {
      for window in allWindows() {
        // 覆盖窗口的用户界面样式
        window.overrideUserInterfaceStyle = userInterfaceStyle
      }
    }

    // 设置所有窗口的色调颜色
    private func setWindowTint(_ color: Color) {
      for window in allWindows() {
        // 将SwiftUI Color转换为UIColor并设置到窗口
        window.tintColor = UIColor(color)
      }
    }

    // 设置导航栏和工具栏的颜色
    private func setBarsColor(_ color: Color) {
      // 设置导航栏为半透明
      UINavigationBar.appearance().isTranslucent = true
      // 设置导航栏背景色调
      UINavigationBar.appearance().barTintColor = UIColor(color)
    }

    // 获取应用中的所有窗口
    private func allWindows() -> [UIWindow] {
      UIApplication.shared.connectedScenes
        // 过滤出窗口场景
        .compactMap { $0 as? UIWindowScene }
        // 提取所有窗口
        .flatMap(\.windows)
    }
  #endif
}
