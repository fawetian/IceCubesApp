// 文件功能说明：
// 该文件定义了应用账户视图组件，用于显示 Mastodon 账户信息，支持紧凑和完整两种显示模式，包括头像、用户名、通知徽章等，并提供账户切换和设置导航功能。
// 技术点：
// 1. @MainActor 属性 —— 确保视图在主线程运行。
// 2. @Environment 环境对象 —— 获取主题、路由、账户管理器等全局状态。
// 3. @State 状态管理 —— 管理视图模型。
// 4. @Binding 属性绑定 —— 控制父视图的显示状态。
// 5. @ViewBuilder 视图构建器 —— 条件构建不同的视图布局。
// 6. Task 异步任务 —— 异步获取账户信息。
// 7. ZStack 层叠布局 —— 实现头像上的状态指示器。
// 8. 条件渲染 —— 根据不同状态显示不同内容。
// 9. Transaction 动画事务 —— 控制账户切换动画。
// 10. HapticManager 触觉反馈 —— 提供用户交互反馈。
//
// 技术点详解：
// - @MainActor：确保所有 UI 更新都在主线程执行
// - @Environment：从环境中获取共享的主题、路由、账户管理器等对象
// - @State：管理本地的视图模型状态
// - @Binding：与父视图双向绑定，控制显示状态
// - @ViewBuilder：允许根据条件构建不同的视图结构
// - Task：使用 Swift 并发异步获取账户数据
// - ZStack：创建层叠布局，在头像上显示状态指示器
// - 条件渲染：根据账户状态、模式等条件显示不同内容
// - Transaction：禁用动画以避免账户切换时的视觉干扰
// - 触觉反馈：为不同的用户操作提供相应的触觉体验

// 引入设计系统模块，提供主题和视觉组件
import DesignSystem
// 引入表情文本组件，支持自定义表情显示
import EmojiText
// 引入环境配置模块，包含全局状态管理
import Env
// 引入 SwiftUI 框架
import SwiftUI

// 应用账户视图组件，确保在主线程运行
@MainActor
public struct AppAccountView: View {
  // 从环境中获取当前主题
  @Environment(Theme.self) private var theme
  // 从环境中获取路由路径对象
  @Environment(RouterPath.self) private var routerPath
  // 从环境中获取应用账户管理器
  @Environment(AppAccountsManager.self) private var appAccounts
  // 从环境中获取用户偏好设置
  @Environment(UserPreferences.self) private var preferences

  // 视图模型状态
  @State var viewModel: AppAccountViewModel

  // 控制父视图显示状态的绑定
  @Binding var isParentPresented: Bool

  // 公共初始化器
  public init(viewModel: AppAccountViewModel, isParentPresented: Binding<Bool>) {
    self.viewModel = viewModel
    _isParentPresented = isParentPresented
  }

  // 视图主体
  public var body: some View {
    // 根据视图模型的模式选择显示样式
    Group {
      if viewModel.isCompact {
        // 紧凑模式视图
        compactView
      } else {
        // 完整模式视图
        fullView
      }
    }
    .onAppear {
      // 视图出现时异步获取账户信息
      Task {
        await viewModel.fetchAccount()
      }
    }
  }

  // 紧凑模式视图构建器
  @ViewBuilder
  private var compactView: some View {
    HStack {
      // 如果有账户信息则显示头像，否则显示加载指示器
      if let account = viewModel.account {
        AvatarView(account.avatar)
      } else {
        ProgressView()
      }
    }
  }

  // 完整模式视图
  private var fullView: some View {
    // 可点击的账户按钮
    Button {
      // 判断是否为当前账户
      if appAccounts.currentAccount.id == viewModel.appAccount.id,
        let account = viewModel.account
      {
        // 当前账户的点击行为
        if viewModel.isInSettings {
          // 在设置中时导航到账户设置页面
          routerPath.navigate(
            to: .accountSettingsWithAccount(account: account, appAccount: viewModel.appAccount))
          HapticManager.shared.fireHaptic(.buttonPress)
        } else {
          // 不在设置中时导航到账户详情页面
          isParentPresented = false
          routerPath.navigate(to: .accountDetailWithAccount(account: account))
          HapticManager.shared.fireHaptic(.buttonPress)
        }
      } else {
        // 非当前账户的点击行为：切换账户
        var transation = Transaction()
        // 禁用动画以避免视觉干扰
        transation.disablesAnimations = true
        withTransaction(transation) {
          // 切换到选中的账户
          appAccounts.currentAccount = viewModel.appAccount
          // 播放成功提示的触觉反馈
          HapticManager.shared.fireHaptic(.notification(.success))
        }
      }
    } label: {
      // 按钮标签内容
      HStack {
        // 如果有账户信息
        if let account = viewModel.account {
          // 头像区域，包含状态指示器
          ZStack(alignment: .topTrailing) {
            // 用户头像
            AvatarView(account.avatar)

            // 如果是当前账户，显示选中标记
            if viewModel.appAccount.id == appAccounts.currentAccount.id {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white, .green)
                .offset(x: 5, y: -5)
            }
            // 如果需要显示徽章且有未读通知
            else if viewModel.showBadge,
              let token = viewModel.appAccount.oauthToken,
              let notificationsCount = preferences.notificationsCount[token],
              notificationsCount > 0
            {
              // 通知计数徽章
              ZStack {
                // 红色圆形背景
                Circle()
                  .fill(.red)
                // 通知数字文本
                Text(notificationsCount > 99 ? "99+" : String(notificationsCount))
                  .foregroundColor(.white)
                  .font(.system(size: 9))
              }
              .frame(width: 20, height: 20)
              .offset(x: 5, y: -5)
            }
          }
        } else {
          // 加载中状态：显示进度指示器和账户名
          ProgressView()
          Text(viewModel.appAccount.accountName ?? viewModel.acct)
            .font(.scaledSubheadline)
            .foregroundStyle(Color.secondary)
            .padding(.leading, 6)
        }

        // 用户信息区域
        VStack(alignment: .leading) {
          if let account = viewModel.account {
            // 显示用户的显示名称（支持自定义表情）
            EmojiTextApp(.init(stringValue: account.safeDisplayName), emojis: account.emojis)
              .foregroundColor(theme.labelColor)
            // 显示用户名@服务器地址
            Text("\(account.username)@\(viewModel.appAccount.server)")
              .font(.scaledSubheadline)
              .emojiText.size(Font.scaledSubheadlineFont.emojiSize)
              .emojiText.baselineOffset(Font.scaledSubheadlineFont.emojiBaselineOffset)
              .foregroundStyle(Color.secondary)
          }
        }

        // 如果在设置中，显示右箭头指示器
        if viewModel.isInSettings {
          Spacer()
          Image(systemName: "chevron.right")
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}
