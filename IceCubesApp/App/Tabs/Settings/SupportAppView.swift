// 文件功能：应用内支持页面，用户可通过打赏、订阅、恢复购买等方式支持开发者。
// 相关技术点：
// - SwiftUI 表单与分区：Form、Section 组织界面。
// - RevenueCat：第三方 IAP 订阅/打赏管理。
// - @State 状态管理：驱动 UI 响应。
// - @Environment：主题、URL 跳转等依赖注入。
// - 异步/并发：Task、async/await 处理购买流程。
// - 条件编译：适配 visionOS。
// - 本地化：LocalizedStringKey 支持多语言。
//
// 技术点详解：
// 1. RevenueCat：简化 IAP 订阅/打赏管理，统一用户信息获取与购买流程。
// 2. SwiftUI 表单：Form/Section 适合设置、打赏等分组场景。
// 3. @State：本地状态管理，自动驱动界面刷新。
// 4. @Environment：注入主题、openURL 等全局依赖。
// 5. async/await：简化异步购买流程。
// 6. 条件编译：#if !os(visionOS) 适配不同平台。
// 7. 本地化：LocalizedStringKey 支持多语言界面。
import DesignSystem
// 导入设计系统，包含主题、控件等
import Env
// 导入环境依赖模块
import RevenueCat
// 导入 RevenueCat IAP 管理库
import SwiftUI

// 导入 SwiftUI 框架

// 主线程下定义支持页面视图
@MainActor
struct SupportAppView: View {
  // 打赏类型枚举，支持多种金额和订阅
  enum Tip: String, CaseIterable {
    case one, two, three, four, supporter

    // 通过产品 ID 初始化枚举
    init(productId: String) {
      self = .init(rawValue: String(productId.split(separator: ".")[2]))!
    }

    // 获取产品 ID
    var productId: String {
      "icecubes.tipjar.\(rawValue)"
    }

    // 标题本地化 key
    var title: LocalizedStringKey {
      switch self {
      case .one:
        "settings.support.one.title"
      case .two:
        "settings.support.two.title"
      case .three:
        "settings.support.three.title"
      case .four:
        "settings.support.four.title"
      case .supporter:
        "settings.support.supporter.title"
      }
    }

    // 副标题本地化 key
    var subtitle: LocalizedStringKey {
      switch self {
      case .one:
        "settings.support.one.subtitle"
      case .two:
        "settings.support.two.subtitle"
      case .three:
        "settings.support.three.subtitle"
      case .four:
        "settings.support.four.subtitle"
      case .supporter:
        "settings.support.supporter.subtitle"
      }
    }
  }

  // 注入主题
  @Environment(Theme.self) private var theme

  // 注入 URL 跳转能力
  @Environment(\.openURL) private var openURL

  // 是否正在加载商品
  @State private var loadingProducts: Bool = false
  // 商品列表
  @State private var products: [StoreProduct] = []
  // 订阅商品
  @State private var subscription: StoreProduct?
  // 用户信息
  @State private var customerInfo: CustomerInfo?
  // 是否正在处理购买
  @State private var isProcessingPurchase: Bool = false
  // 购买成功弹窗
  @State private var purchaseSuccessDisplayed: Bool = false
  // 购买失败弹窗
  @State private var purchaseErrorDisplayed: Bool = false

  // 主体视图
  var body: some View {
    Form {
      aboutSection
      subscriptionSection
      tipsSection
      restorePurchase
      linksSection
    }
    // 设置导航标题
    .navigationTitle("settings.support.navigation-title")
    #if !os(visionOS)
      // 隐藏表单默认背景
      .scrollContentBackground(.hidden)
      // 设置整体背景色为主题次背景色
      .background(theme.secondaryBackgroundColor)
    #endif
    // 购买成功弹窗
    .alert(
      "settings.support.alert.title", isPresented: $purchaseSuccessDisplayed,
      actions: {
        Button {
          purchaseSuccessDisplayed = false
        } label: {
          Text("alert.button.ok")
        }
      },
      message: {
        Text("settings.support.alert.message")
      }
    )
    // 购买失败弹窗
    .alert(
      "alert.error", isPresented: $purchaseErrorDisplayed,
      actions: {
        Button {
          purchaseErrorDisplayed = false
        } label: {
          Text("alert.button.ok")
        }
      },
      message: {
        Text("settings.support.alert.error.message")
      }
    )
    // 页面出现时加载商品和用户信息
    .onAppear {
      loadingProducts = true
      fetchStoreProducts()
      refreshUserInfo()
    }
  }

  // 购买商品
  private func purchase(product: StoreProduct) async {
    if !isProcessingPurchase {
      isProcessingPurchase = true
      do {
        let result = try await Purchases.shared.purchase(product: product)
        if !result.userCancelled {
          purchaseSuccessDisplayed = true
        }
      } catch {
        purchaseErrorDisplayed = true
      }
      isProcessingPurchase = false
    }
  }

  // 获取商品列表
  private func fetchStoreProducts() {
    Purchases.shared.getProducts(Tip.allCases.map(\.productId)) { products in
      subscription = products.first(where: { $0.productIdentifier == Tip.supporter.productId })
      self.products = products.filter { $0.productIdentifier != Tip.supporter.productId }.sorted(
        by: { $0.price < $1.price })
      withAnimation {
        loadingProducts = false
      }
    }
  }

  // 刷新用户信息
  private func refreshUserInfo() {
    Purchases.shared.getCustomerInfo { info, _ in
      customerInfo = info
    }
  }

  // 生成购买按钮
  private func makePurchaseButton(product: StoreProduct) -> some View {
    Button {
      Task {
        await purchase(product: product)
        refreshUserInfo()
      }
    } label: {
      if isProcessingPurchase {
        ProgressView()
      } else {
        Text(product.localizedPriceString)
      }
    }
    .buttonStyle(.bordered)
  }

  // 关于分区
  private var aboutSection: some View {
    Section {
      HStack(alignment: .top, spacing: 12) {
        VStack(spacing: 18) {
          Image("avatar")
            .resizable()
            .frame(width: 50, height: 50)
            .cornerRadius(4)
          Image("icon0")
            .resizable()
            .frame(width: 50, height: 50)
            .cornerRadius(4)
        }
        Text("settings.support.message-from-dev")
      }
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  // 订阅分区
  private var subscriptionSection: some View {
    Section {
      if loadingProducts {
        loadingPlaceholder
      } else if let subscription {
        HStack {
          if customerInfo?.entitlements["Supporter"]?.isActive == true {
            Text(Image(systemName: "checkmark.seal.fill"))
              .foregroundColor(theme.tintColor)
              .baselineOffset(-1)
              + Text("settings.support.supporter.subscribed")
              .font(.scaledSubheadline)
          } else {
            VStack(alignment: .leading) {
              Text(Image(systemName: "checkmark.seal.fill"))
                .foregroundColor(theme.tintColor)
                .baselineOffset(-1)
                + Text(Tip.supporter.title)
                .font(.scaledSubheadline)
              Text(Tip.supporter.subtitle)
                .font(.scaledFootnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            makePurchaseButton(product: subscription)
          }
        }
        .padding(.vertical, 8)
      }
    } footer: {
      if customerInfo?.entitlements.active.isEmpty == true {
        Text("settings.support.supporter.subscription-info")
      }
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  // 打赏分区
  private var tipsSection: some View {
    Section {
      if loadingProducts {
        loadingPlaceholder
      } else {
        ForEach(products, id: \.productIdentifier) { product in
          let tip = Tip(productId: product.productIdentifier)
          HStack {
            VStack(alignment: .leading) {
              Text(tip.title)
                .font(.scaledSubheadline)
              Text(tip.subtitle)
                .font(.scaledFootnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            makePurchaseButton(product: product)
          }
          .padding(.vertical, 8)
        }
      }
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  // 恢复购买分区
  private var restorePurchase: some View {
    Section {
      HStack {
        Spacer()
        Button {
          Purchases.shared.restorePurchases { info, _ in
            customerInfo = info
          }
        } label: {
          Text("settings.support.restore-purchase.button")
        }.buttonStyle(.bordered)
        Spacer()
      }
    } footer: {
      Text("settings.support.restore-purchase.explanation")
    }
    #if !os(visionOS)
      .listRowBackground(theme.secondaryBackgroundColor)
    #endif
  }

  // 链接分区
  private var linksSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 16) {
        Button {
          openURL(URL(string: "https://github.com/Dimillian/IceCubesApp/blob/main/PRIVACY.MD")!)
        } label: {
          Text("settings.support.privacy-policy")
        }
        .buttonStyle(.borderless)
        Button {
          openURL(URL(string: "https://github.com/Dimillian/IceCubesApp/blob/main/TERMS.MD")!)
        } label: {
          Text("settings.support.terms-of-use")
        }
        .buttonStyle(.borderless)
      }
    }
    #if !os(visionOS)
      .listRowBackground(theme.secondaryBackgroundColor)
    #endif
  }

  // 加载占位视图
  private var loadingPlaceholder: some View {
    HStack {
      VStack(alignment: .leading) {
        Text("placeholder.loading.short")
          .font(.scaledSubheadline)
        Text("settings.support.placeholder.loading-subtitle")
          .font(.scaledFootnote)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 8)
    }
    .redacted(reason: .placeholder)
    .allowsHitTesting(false)
  }
}
