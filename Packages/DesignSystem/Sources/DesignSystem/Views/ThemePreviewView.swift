/*
 * ThemePreviewView.swift
 * IceCubesApp - 主题预览视图
 *
 * 文件功能：
 * 提供主题颜色集选择界面，展示所有可用主题的预览卡片。
 *
 * 核心职责：
 * - 展示所有可用颜色集（浅色和深色配对）
 * - 提供主题卡片预览（颜色、背景、强调色）
 * - 支持点击切换主题
 * - 标记当前选中的主题
 *
 * 技术要点：
 * - ScrollView 网格布局
 * - ThemeBoxView 主题卡片组件
 * - onChange 监听主题变化
 * - onTapGesture 处理主题切换
 *
 * 使用场景：
 * - 设置页面的主题选择
 * - 预览和切换应用配色方案
 *
 * 依赖关系：
 * - Theme: 主题管理
 * - SwiftUI: 视图和布局
 */

import Combine
import SwiftUI

/// 主题预览视图。
///
/// 展示所有可用主题的预览卡片网格。
public struct ThemePreviewView: View {
  /// 卡片间距。
  private let gutterSpace: Double = 8
  /// 全局主题。
  @Environment(Theme.self) private var theme
  /// 关闭视图的函数。
  @Environment(\.dismiss) var dismiss

  /// 初始化方法。
  public init() {}

  /// 视图主体。
  public var body: some View {
    ScrollView {
      ForEach(availableColorsSets) { couple in
        HStack(spacing: gutterSpace) {
          ThemeBoxView(color: couple.light)
          ThemeBoxView(color: couple.dark)
        }
      }
    }
    .padding(4)
    .frame(maxHeight: .infinity)
    .background(theme.primaryBackgroundColor)
    .navigationTitle("design.theme.navigation-title")
  }
}

/// 主题卡片视图。
///
/// 展示单个颜色集的预览卡片。
struct ThemeBoxView: View {
  /// 全局主题。
  @Environment(Theme.self) private var theme
  /// 内部间距。
  private let gutterSpace = 8.0
  /// 是否选中状态。
  @State private var isSelected = false

  /// 要展示的颜色集。
  var color: ColorSet

  /// 视图主体。
  var body: some View {
    ZStack(alignment: .topTrailing) {
      Rectangle()
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(4)
        .shadow(radius: 2, x: 2, y: 4)
        .accessibilityHidden(true)

      VStack(spacing: gutterSpace) {
        Text(color.name.rawValue)
          .foregroundColor(color.tintColor)
          .font(.system(size: 20))
          .fontWeight(.bold)

        Text("design.theme.toots-preview")
          .foregroundColor(color.labelColor)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
          .background(color.primaryBackgroundColor)

        Text("#icecube, #techhub")
          .foregroundColor(color.tintColor)
        if isSelected {
          HStack {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
              .resizable()
              .frame(width: 20, height: 20)
              .foregroundColor(.green)
          }
        } else {
          HStack {
            Spacer()
            Circle()
              .strokeBorder(color.tintColor, lineWidth: 1)
              .background(Circle().fill(color.primaryBackgroundColor))
              .frame(width: 20, height: 20)
          }
        }
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(color.secondaryBackgroundColor)
      .font(.system(size: 15))
      .cornerRadius(4)
    }
    .onAppear {
      isSelected = theme.selectedSet.rawValue == color.name.rawValue
    }
    .onChange(of: theme.selectedSet) { _, newValue in
      isSelected = newValue.rawValue == color.name.rawValue
    }
    .onTapGesture {
      let currentScheme = theme.selectedScheme
      if color.scheme != currentScheme {
        theme.followSystemColorScheme = false
      }
      theme.applySet(set: color.name)
    }
  }
}
