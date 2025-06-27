/*
 * NotificationExt.swift
 * IceCubesApp - 通知模型扩展
 * 
 * 功能描述：
 * 为 Mastodon 通知模型添加合并逻辑，定义不同类型通知的分组策略
 * 实现通知的智能合并，提升通知列表的可读性和用户体验
 *
 * 技术点：
 * 1. Extension 扩展 - 为现有类型添加新功能
 * 2. Switch 模式匹配 - 根据通知类型选择策略
 * 3. where 子句 - 在 case 中添加条件判断
 * 4. 字符串插值 - 动态构建合并标识符
 * 5. nil coalescing - ?? 操作符提供默认值
 * 6. 布尔逻辑 - 判断通知是否可合并
 * 7. 枚举原始值 - 获取类型的字符串表示
 * 8. 可选值处理 - 安全访问可选属性
 * 9. 条件返回 - 根据不同条件返回结果
 * 10. 唯一性判断 - 通过 ID 比较确定分组
 *
 * 技术点详解：
 * - Extension：扩展现有模型而不修改源码，遵循开闭原则
 * - Switch + where：组合模式匹配和条件判断，提供灵活的分支逻辑
 * - 字符串插值：使用 \() 语法动态构建标识符字符串
 * - 可选值处理：status?.id 安全访问可选属性，避免崩溃
 * - 合并策略：不同通知类型采用不同的分组逻辑
 * - 关注通知：按类型分组，显示"X个人关注了你"
 * - 转发/点赞：按状态分组，显示"X个人转发了你的帖子"
 * - 其他通知：不分组，保持独立显示
 * - 唯一性判断：通过 ID 比较确定是否可合并
 * - 三元逻辑：支持分组、不分组、条件分组三种策略
 */

//
//  NotificationExt.swift
//
//
//  Created by Jérôme Danthinne on 31/01/2023.
//

// 导入 Models 模块，提供 Notification 等数据模型
import Models

// 为通知模型添加合并功能的扩展
extension Notification {
  // 生成合并标识符，相同标识符的通知会被合并显示
  func consolidationId(selectedType: Models.Notification.NotificationType?) -> String? {
    // 检查是否为支持的通知类型
    guard let supportedType else { return nil }

    switch supportedType {
    // 关注通知：当未选择关注类型过滤时，按类型分组
    case .follow where selectedType != .follow:
      // 总是将关注者分组，使用类型进行分组
      return supportedType.rawValue
    // 转发和点赞通知：按相关状态 ID 分组
    case .reblog, .favourite:
      // 将转发和点赞按状态分组，使用类型 + 相关状态 ID
      return "\(supportedType.rawValue)-\(status?.id ?? "")"
    // 其他通知类型：使用通知 ID，不进行合并
    default:
      // 不合并其余类型，使用通知 ID 本身确保唯一性
      return id
    }
  }

  // 判断通知是否可以被合并
  func isConsolidable(selectedType: Models.Notification.NotificationType?) -> Bool {
    // 只有当合并 ID 不等于通知 ID（唯一）本身时，通知才可合并
    consolidationId(selectedType: selectedType) != id
  }
}
