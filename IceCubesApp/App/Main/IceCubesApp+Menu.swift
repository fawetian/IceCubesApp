// 文件功能说明：
// 该文件为 IceCubesApp 的菜单命令扩展，定义了应用菜单栏的自定义命令（如设置、新建窗口、新建发帖、字体调整、时间线切换、帮助等）。
// 技术点：
// 1. SwiftUI Commands/CommandGroup/CommandMenu —— 自定义菜单栏命令。
// 2. @CommandsBuilder —— 构建多命令组合。
// 3. KeyboardShortcut —— 键盘快捷键绑定。
// 4. NotificationCenter —— 通过通知实现时间线刷新等功能。
// 5. 多平台适配（macCatalyst/iOS）。
// 6. SwiftUI 环境变量与路由弹窗控制。
//
// 下面为每行代码详细注释：
// 引入环境配置模块
import Env
// 引入 SwiftUI 框架
import SwiftUI

// 扩展 IceCubesApp，添加菜单命令
extension IceCubesApp {
  // 使用命令构建器，定义应用菜单
  @CommandsBuilder
  var appMenu: some Commands {
    // 替换系统设置菜单
    CommandGroup(replacing: .appSettings) {
      Button("menu.settings") {
        // 打开设置弹窗
        appRouterPath.presentedSheet = .settings
      }
      .keyboardShortcut(",", modifiers: .command)
    }
    // 替换新建菜单
    CommandGroup(replacing: .newItem) {
      Button("menu.new-window") {
        // 打开新主窗口
        openWindow(id: "MainWindow")
      }
      .keyboardShortcut("n", modifiers: .shift)
      Button("menu.new-post") {
        #if targetEnvironment(macCatalyst)
          // macCatalyst 下新建发帖窗口
          openWindow(
            value: WindowDestinationEditor.newStatusEditor(
              visibility: userPreferences.postVisibility))
        #else
          // 其他平台弹出发帖编辑器
          appRouterPath.presentedSheet = .newStatusEditor(
            visibility: userPreferences.postVisibility)
        #endif
      }
      .keyboardShortcut("n", modifiers: .command)
    }
    // 替换文本格式菜单，添加字体调整
    CommandGroup(replacing: .textFormatting) {
      Menu("menu.font") {
        Button("menu.font.bigger") {
          // 字体放大，最大 1.5 倍
          if theme.fontSizeScale < 1.5 {
            theme.fontSizeScale += 0.1
          }
        }
        Button("menu.font.smaller") {
          // 字体缩小，最小 0.5 倍
          if theme.fontSizeScale > 0.5 {
            theme.fontSizeScale -= 0.1
          }
        }
      }
    }
    // 新增时间线菜单，支持刷新/切换不同时间线
    CommandMenu("tab.timeline") {
      Button("timeline.latest") {
        NotificationCenter.default.post(name: .refreshTimeline, object: nil)
      }
      .keyboardShortcut("r", modifiers: .command)
      Button("timeline.home") {
        NotificationCenter.default.post(name: .homeTimeline, object: nil)
      }
      .keyboardShortcut("h", modifiers: .shift)
      Button("timeline.trending") {
        NotificationCenter.default.post(name: .trendingTimeline, object: nil)
      }
      .keyboardShortcut("t", modifiers: .shift)
      Button("timeline.federated") {
        NotificationCenter.default.post(name: .federatedTimeline, object: nil)
      }
      .keyboardShortcut("f", modifiers: .shift)
      Button("timeline.local") {
        NotificationCenter.default.post(name: .localTimeline, object: nil)
      }
      .keyboardShortcut("l", modifiers: .shift)
    }
    // 替换帮助菜单，添加 GitHub 帮助入口
    CommandGroup(replacing: .help) {
      Button("menu.help.github") {
        let url = URL(string: "https://github.com/Dimillian/IceCubesApp/issues")!
        UIApplication.shared.open(url)
      }
    }
  }
}
