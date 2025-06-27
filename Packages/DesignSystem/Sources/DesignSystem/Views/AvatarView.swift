/*
 * AvatarView.swift
 * IceCubesApp - 头像视图组件
 *
 * 功能描述：
 * 提供一个功能完整的头像显示组件，支持网络图片加载、占位符显示、多种尺寸配置和形状适配
 * 集成 Nuke 图片加载库，支持图片缓存、预处理和自适应圆角/圆形显示
 *
 * 技术点：
 * 1. Nuke 图片加载 - 高性能的网络图片加载和缓存库
 * 2. NukeUI LazyImage - SwiftUI 的懒加载图片组件
 * 3. 图片预处理 - resize 处理器优化内存使用
 * 4. 多平台适配 - macCatalyst 的尺寸差异处理
 * 5. 主题系统集成 - 动态头像形状适配
 * 6. FrameConfig 配置 - 预定义的尺寸和圆角配置
 * 7. 占位符系统 - 加载失败和无头像的备用显示
 * 8. @MainActor 并发 - 确保 UI 更新在主线程
 * 9. PreviewProvider - SwiftUI 预览和测试数据
 *
 * 技术点详解：
 * - Nuke：第三方图片加载库，提供内存和磁盘缓存、图片预处理、取消请求等功能
 * - NukeUI LazyImage：Nuke 的 SwiftUI 集成组件，支持懒加载和状态管理
 * - 图片预处理：通过 resize 处理器在加载时调整图片尺寸，减少内存占用
 * - 多平台适配：使用条件编译为 macCatalyst 提供不同的默认尺寸
 * - 主题系统集成：根据全局主题设置动态调整头像显示形状
 * - FrameConfig 配置：使用静态配置简化不同场景的头像尺寸管理
 * - 占位符系统：为网络加载失败或无头像情况提供一致的备用显示
 * - @MainActor 并发：确保所有 UI 相关操作都在主线程执行，避免并发问题
 * - PreviewProvider：提供 SwiftUI 预览功能，包含测试数据和交互演示
 */

// 导入 Models 模块，提供数据模型定义
import Models
// 导入 Nuke 图片加载库，提供网络图片加载和缓存功能
import Nuke
// 导入 NukeUI，提供 SwiftUI 集成的图片组件
import NukeUI
// 导入 SwiftUI 框架，提供视图构建功能
import SwiftUI

// 使用 @MainActor 确保头像视图在主线程上运行
@MainActor
// 定义公共的头像视图结构体，用于显示用户头像
public struct AvatarView: View {
  // 从环境中获取主题设置，用于适配头像形状
  @Environment(Theme.self) private var theme

  // 存储头像图片的 URL，可选类型
  public let avatar: URL?
  // 存储头像的尺寸和圆角配置
  public let config: FrameConfig

  // 视图主体，定义头像的 UI 结构
  public var body: some View {
    // 检查是否有头像 URL
    if let avatar {
      // 有头像时显示网络图片
      AvatarImage(avatar, config: adaptiveConfig)
        // 设置视图框架尺寸
        .frame(width: config.width, height: config.height)
    } else {
      // 无头像时显示占位符
      AvatarPlaceHolder(config: adaptiveConfig)
    }
  }

  // 计算适应性配置，根据主题和配置类型调整圆角
  private var adaptiveConfig: FrameConfig {
    // 计算圆角半径
    let cornerRadius: CGFloat =
      // 如果是徽章类型或主题设置为圆形
      if config == .badge || theme.avatarShape == .circle {
        // 使用圆形（宽度的一半作为圆角）
        config.width / 2
      } else {
        // 使用配置中的圆角值
        config.cornerRadius
      }
    // 返回新的配置对象
    return FrameConfig(width: config.width, height: config.height, cornerRadius: cornerRadius)
  }

  // 公共初始化方法，创建头像视图实例
  public init(_ avatar: URL? = nil, config: FrameConfig = .status) {
    // 设置头像 URL
    self.avatar = avatar
    // 设置尺寸配置
    self.config = config
  }

  // 使用 @MainActor 确保框架配置在主线程上定义
  @MainActor
  // 定义头像框架配置结构体，支持相等性比较和并发安全
  public struct FrameConfig: Equatable, Sendable {
    // 存储头像尺寸
    public let size: CGSize
    // 计算属性：获取宽度
    public var width: CGFloat { size.width }
    // 计算属性：获取高度
    public var height: CGFloat { size.height }
    // 存储圆角半径
    let cornerRadius: CGFloat

    // 内部初始化方法，创建框架配置
    init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 4) {
      // 创建尺寸对象
      size = CGSize(width: width, height: height)
      // 设置圆角半径
      self.cornerRadius = cornerRadius
    }

    // 预定义配置：账户页面使用的大头像
    public static let account = FrameConfig(width: 80, height: 80)
    // 根据平台设置不同的状态头像尺寸
    #if targetEnvironment(macCatalyst)
      // macCatalyst 平台使用较大尺寸
      public static let status = FrameConfig(width: 48, height: 48)
    #else
      // 其他平台使用标准尺寸
      public static let status = FrameConfig(width: 40, height: 40)
    #endif
    // 预定义配置：嵌入式小头像
    public static let embed = FrameConfig(width: 34, height: 34)
    // 预定义配置：徽章头像（圆形）
    public static let badge = FrameConfig(width: 28, height: 28, cornerRadius: 14)
    // 预定义配置：圆角徽章头像
    public static let badgeRounded = FrameConfig(width: 28, height: 28)
    // 预定义配置：列表小头像（圆形）
    public static let list = FrameConfig(width: 20, height: 20, cornerRadius: 10)
    // 预定义配置：转发标记用的微型头像（圆形）
    public static let boost = FrameConfig(width: 12, height: 12, cornerRadius: 6)
  }
}

// 定义 SwiftUI 预览提供者
struct AvatarView_Previews: PreviewProvider {
  // 预览内容
  static var previews: some View {
    // 使用预览包装器
    PreviewWrapper()
      // 添加内边距
      .padding()
      // 设置预览布局为适应内容大小
      .previewLayout(.sizeThatFits)
  }
}

// 预览包装器视图，用于演示头像组件
struct PreviewWrapper: View {
  // 控制头像形状的状态变量
  @State private var isCircleAvatar = false

  // 预览视图主体
  var body: some View {
    // 垂直布局，左对齐
    VStack(alignment: .leading) {
      // 显示示例头像
      AvatarView(Self.account.avatar)
        // 设置主题环境
        .environment(Theme.shared)
      // 头像形状切换开关
      Toggle("Avatar Shape", isOn: $isCircleAvatar)
    }
    // 监听开关状态变化
    .onChange(of: isCircleAvatar) {
      // 根据开关状态设置主题中的头像形状
      Theme.shared.avatarShape = isCircleAvatar ? .circle : .rounded
    }
    // 视图出现时初始化主题设置
    .onAppear {
      // 设置初始头像形状
      Theme.shared.avatarShape = isCircleAvatar ? .circle : .rounded
    }
  }

  // 静态的示例账户数据，用于预览
  private static let account = Account(
    // 生成随机 ID
    id: UUID().uuidString,
    // 用户名
    username: "@clattner_llvm",
    // 显示名称
    displayName: "Chris Lattner",
    // 头像 URL
    avatar: URL(
      string: "https://pbs.twimg.com/profile_images/1484209565788897285/1n6Viahb_400x400.jpg")!,
    // 背景图片 URL
    header: URL(string: "https://pbs.twimg.com/profile_banners/2543588034/1656822255/1500x500")!,
    // 完整账户标识
    acct: "clattner_llvm@example.com",
    // 用户简介
    note: .init(
      stringValue:
        "Building beautiful things @Modular_AI 🔥, lifting the world of production AI/ML software into a new phase of innovation.  We're hiring! 🚀🧠"
    ),
    // 账户创建时间
    createdAt: ServerDate(),
    // 关注者数量
    followersCount: 77100,
    // 关注数量
    followingCount: 167,
    // 帖子数量
    statusesCount: 123,
    // 最后发帖时间
    lastStatusAt: nil,
    // 自定义字段
    fields: [],
    // 是否锁定账户
    locked: false,
    // 自定义表情
    emojis: [],
    // 个人网站 URL
    url: URL(string: "https://nondot.org/sabre/")!,
    // 账户来源信息
    source: nil,
    // 是否为机器人账户
    bot: false,
    // 是否可被发现
    discoverable: true
  )
}

// 头像图片视图，处理网络图片加载和显示
struct AvatarImage: View {
  // 从环境中获取编辑状态，用于占位符显示
  @Environment(\.redactionReasons) private var reasons

  // 存储头像 URL
  public let avatar: URL
  // 存储配置信息
  public let config: AvatarView.FrameConfig

  // 视图主体
  var body: some View {
    // 检查是否处于占位符模式
    if reasons == .placeholder {
      // 显示占位符
      AvatarPlaceHolder(config: config)
    } else {
      // 使用 LazyImage 加载网络图片
      LazyImage(
        // 创建图片请求，包含预处理器
        request: ImageRequest(url: avatar, processors: [.resize(size: config.size)])
      ) { state in
        // 检查图片加载状态
        if let image = state.image {
          // 图片加载成功时显示图片
          image
            // 设置为可调整大小
            .resizable()
            // 按比例缩放适应
            .scaledToFit()
            // 应用圆角裁剪
            .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))
            // 添加边框
            .overlay(
              RoundedRectangle(cornerRadius: config.cornerRadius)
                .stroke(.primary.opacity(0.25), lineWidth: 1)
            )
        } else {
          // 图片加载失败或加载中时显示边框占位符
          RoundedRectangle(cornerRadius: config.cornerRadius)
            .stroke(.primary.opacity(0.25), lineWidth: 1)
        }
      }
    }
  }

  // 初始化方法
  init(_ avatar: URL, config: AvatarView.FrameConfig) {
    // 设置头像 URL
    self.avatar = avatar
    // 设置配置
    self.config = config
  }
}

// 头像占位符视图，用于无头像或加载失败时显示
struct AvatarPlaceHolder: View {
  // 存储配置信息
  let config: AvatarView.FrameConfig

  // 视图主体
  var body: some View {
    // 创建圆角矩形占位符
    RoundedRectangle(cornerRadius: config.cornerRadius)
      // 填充灰色
      .fill(.gray)
      // 设置尺寸
      .frame(width: config.width, height: config.height)
  }
}
