// 文件功能说明：
// 该文件为 IceCubesApp 的场景扩展，定义了主窗口、编辑器窗口、媒体窗口等多场景支持，并处理推送、意图、主题、环境注入等。
// 技术点：
// 1. SwiftUI 多场景（Scene/WindowGroup/SceneBuilder）—— 支持多窗口和多类型场景。
// 2. 环境注入（.environment）—— 依赖注入各类单例和服务。
// 3. 主题应用（.applyTheme）—— 动态切换主题。
// 4. 路由弹窗、媒体预览、通知处理、意图处理。
// 5. 兼容 macCatalyst/visionOS 多平台适配。
// 6. SwiftUI 的 .onAppear/.onChange/.sheet 等生命周期和交互修饰符。
// 7. AppIntents 深度集成。
//
// 下面为每行代码详细注释：
// 引入 AppIntents 框架
import AppIntents
// 引入环境配置模块
import Env
// 引入媒体 UI 相关模块
import MediaUI
// 引入状态管理相关模块
import StatusKit
// 引入 SwiftUI 框架
import SwiftUI

// 扩展 IceCubesApp，添加多场景支持
extension IceCubesApp {
  // 主窗口场景
  var appScene: some Scene {
    WindowGroup(id: "MainWindow") {
      // 主界面视图
      AppView(selectedTab: $selectedTab, appRouterPath: $appRouterPath)
        .applyTheme(theme)
        .onAppear {
          // 初始化环境与服务
          setNewClientsInEnv(client: appAccountsManager.currentClient)
          setupRevenueCat()
          refreshPushSubs()
        }
        // 注入各种环境对象
        .environment(appAccountsManager)
        .environment(appAccountsManager.currentClient)
        .environment(quickLook)
        .environment(currentAccount)
        .environment(currentInstance)
        .environment(userPreferences)
        .environment(theme)
        .environment(watcher)
        .environment(pushNotificationsService)
        .environment(appIntentService)
        .environment(\.isSupporter, isSupporter)
        // 媒体预览弹窗
        .sheet(item: $quickLook.selectedMediaAttachment) { selectedMediaAttachment in
          if let namespace = quickLook.namespace {
            MediaUIView(
              selectedAttachment: selectedMediaAttachment,
              attachments: quickLook.mediaAttachments
            )
            .navigationTransition(.zoom(sourceID: selectedMediaAttachment.id, in: namespace))
            .presentationBackground(theme.primaryBackgroundColor)
            .presentationCornerRadius(16)
            .presentationSizing(.page)
            .withEnvironments()
          } else {
            EmptyView()
          }
        }
        // 处理推送通知
        .onChange(of: pushNotificationsService.handledNotification) { _, newValue in
          if newValue != nil {
            pushNotificationsService.handledNotification = nil
            if appAccountsManager.currentAccount.oauthToken?.accessToken
              != newValue?.account.token.accessToken,
              let account = appAccountsManager.availableAccounts.first(where: {
                $0.oauthToken?.accessToken == newValue?.account.token.accessToken
              })
            {
              appAccountsManager.currentAccount = account
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedTab = .notifications
                pushNotificationsService.handledNotification = newValue
              }
            } else {
              selectedTab = .notifications
            }
          }
        }
        // 处理 AppIntent
        .onChange(of: appIntentService.handledIntent) { _, _ in
          if let intent = appIntentService.handledIntent?.intent {
            handleIntent(intent)
            appIntentService.handledIntent = nil
          }
        }
        // 注入模型容器
        .withModelContainer()
    }
    // 注入菜单命令
    .commands {
      appMenu
    }
    // 监听场景生命周期变化
    .onChange(of: scenePhase) { _, newValue in
      handleScenePhase(scenePhase: newValue)
    }
    // 监听账号切换
    .onChange(of: appAccountsManager.currentClient) { _, newValue in
      setNewClientsInEnv(client: newValue)
      if newValue.isAuth {
        watcher.watch(streams: [.user, .direct])
      }
    }
    #if targetEnvironment(macCatalyst)
      .windowResize()
    #elseif os(visionOS)
      .defaultSize(width: 800, height: 1200)
    #endif
  }

  // 其他窗口场景（如编辑器、媒体预览）
  @SceneBuilder
  var otherScenes: some Scene {
    // 编辑器窗口
    WindowGroup(for: WindowDestinationEditor.self) { destination in
      Group {
        switch destination.wrappedValue {
        case let .newStatusEditor(visibility):
          StatusEditor.MainView(mode: .new(text: nil, visibility: visibility))
        case let .prefilledStatusEditor(text, visibility):
          StatusEditor.MainView(mode: .new(text: text, visibility: visibility))
        case let .editStatusEditor(status):
          StatusEditor.MainView(mode: .edit(status: status))
        case let .quoteStatusEditor(status):
          StatusEditor.MainView(mode: .quote(status: status))
        case let .replyToStatusEditor(status):
          StatusEditor.MainView(mode: .replyTo(status: status))
        case let .mentionStatusEditor(account, visibility):
          StatusEditor.MainView(mode: .mention(account: account, visibility: visibility))
        case let .quoteLinkStatusEditor(link):
          StatusEditor.MainView(mode: .quoteLink(link: link))
        case .none:
          EmptyView()
        }
      }
      .withEnvironments()
      .environment(\.isCatalystWindow, true)
      .environment(RouterPath())
      .withModelContainer()
      .applyTheme(theme)
      .frame(minWidth: 300, minHeight: 400)
    }
    .defaultSize(width: 600, height: 800)
    .windowResizability(.contentMinSize)

    // 媒体窗口
    WindowGroup(for: WindowDestinationMedia.self) { destination in
      Group {
        switch destination.wrappedValue {
        case let .mediaViewer(attachments, selectedAttachment):
          MediaUIView(
            selectedAttachment: selectedAttachment,
            attachments: attachments)
        case .none:
          EmptyView()
        }
      }
      .withEnvironments()
      .withModelContainer()
      .applyTheme(theme)
      .environment(\.isCatalystWindow, true)
      .frame(minWidth: 300, minHeight: 400)
    }
    .defaultSize(width: 1200, height: 1000)
    .windowResizability(.contentMinSize)
  }

  // 处理 AppIntent 的私有方法
  private func handleIntent(_: any AppIntent) {
    if let postIntent = appIntentService.handledIntent?.intent as? PostIntent {
      #if os(visionOS) || os(macOS)
        openWindow(
          value: WindowDestinationEditor.prefilledStatusEditor(
            text: postIntent.content ?? "",
            visibility: userPreferences.postVisibility))
      #else
        appRouterPath.presentedSheet = .prefilledStatusEditor(
          text: postIntent.content ?? "",
          visibility: userPreferences.postVisibility)
      #endif
    } else if let tabIntent = appIntentService.handledIntent?.intent as? TabIntent {
      selectedTab = tabIntent.tab.toAppTab
    } else if let imageIntent = appIntentService.handledIntent?.intent as? PostImageIntent,
      let urls = imageIntent.images?.compactMap({ $0.fileURL })
    {
      appRouterPath.presentedSheet = .imageURL(
        urls: urls,
        caption: imageIntent.caption,
        altTexts: imageIntent.altText.map { [$0] },
        visibility: userPreferences.postVisibility)
    }
  }
}

// 扩展 Scene，支持窗口大小调整
extension Scene {
  func windowResize() -> some Scene {
    return self.windowResizability(.contentSize)
  }
}
