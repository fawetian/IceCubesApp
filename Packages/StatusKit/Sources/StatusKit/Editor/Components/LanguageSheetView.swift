/*
 * LanguageSheetView.swift
 * IceCubesApp - 语言选择面板
 *
 * 功能描述：
 * 显示所有可用语言的列表，用户可以搜索并选择帖子的语言
 * 支持最近使用的语言、搜索过滤和本地化显示
 *
 * 核心功能：
 * 1. 语言列表 - 显示所有可用的语言
 * 2. 最近使用 - 优先显示最近使用的语言
 * 3. 搜索功能 - 按语言名称搜索
 * 4. 本地化显示 - 显示语言的本地名称和翻译名称
 * 5. 选择标记 - 当前选择的语言显示勾选标记
 * 6. 自动关闭 - 选择后自动关闭面板
 * 7. 导航栏 - 标题和取消按钮
 * 8. 主题适配 - 使用主题颜色
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @Environment - 环境依赖注入
 * 3. @State - 本地状态管理
 * 4. @Binding - 双向数据绑定
 * 5. NavigationStack - 导航容器
 * 6. List - 列表视图
 * 7. Section - 分组显示
 * 8. searchable - 搜索功能
 * 9. ForEach - 遍历数据
 * 10. 计算属性 - 动态过滤语言列表
 *
 * 视图层次：
 * - NavigationStack
 *   - List
 *     - Section（最近使用）
 *       - ForEach（最近使用的语言）
 *     - Section（其他语言）
 *       - ForEach（其他语言）
 *
 * 语言显示格式：
 * - 有本地名称和翻译名称：显示 "本地名称 (翻译名称)"
 * - 只有 ISO 代码：显示大写的 ISO 代码
 * - 例如："中文 (Chinese)" 或 "ZH"
 *
 * 搜索逻辑：
 * - 按本地名称搜索
 * - 按翻译名称搜索
 * - 不区分大小写
 * - 前缀匹配
 *
 * 使用场景：
 * - 点击语言按钮打开面板
 * - 搜索并选择语言
 * - 查看最近使用的语言
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 用户偏好设置
 * - Models: 语言数据模型
 */

import DesignSystem
import Env
import Models
import SwiftUI

extension StatusEditor {
  /// 语言选择面板
  ///
  /// 显示所有可用语言的列表。
  ///
  /// 主要功能：
  /// - **语言列表**：显示所有可用的语言
  /// - **最近使用**：优先显示最近使用的语言
  /// - **搜索功能**：按语言名称搜索
  /// - **本地化显示**：显示语言的本地名称和翻译名称
  ///
  /// 使用示例：
  /// ```swift
  /// LanguageSheetView(
  ///     viewModel: viewModel,
  ///     isPresented: $isPresented
  /// )
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: 选择语言后会自动关闭面板
  @MainActor
  struct LanguageSheetView: View {
    /// 主题设置
    @Environment(Theme.self) private var theme
    /// 用户偏好设置
    @Environment(UserPreferences.self) private var preferences

    /// 语言搜索文本
    @State private var languageSearch: String = ""

    /// 编辑器 ViewModel
    var viewModel: ViewModel
    /// 是否显示面板
    @Binding var isPresented: Bool

    var body: some View {
      NavigationStack {
        List {
          if languageSearch.isEmpty {
            if !recentlyUsedLanguages.isEmpty {
              Section("status.editor.language-select.recently-used") {
                languageSheetSection(languages: recentlyUsedLanguages)
              }
            }
            Section {
              languageSheetSection(languages: otherLanguages)
            }
          } else {
            languageSheetSection(languages: languageSearchResult(query: languageSearch))
          }
        }
        .searchable(text: $languageSearch, placement: .navigationBarDrawer)
        .toolbar {
          CancelToolbarItem()
        }
        .navigationTitle("status.editor.language-select.navigation-title")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(theme.secondaryBackgroundColor)
      }
    }

    /// 语言文本视图
    ///
    /// 根据可用信息显示语言名称。
    ///
    /// - Parameters:
    ///   - isoCode: ISO 语言代码
    ///   - nativeName: 本地名称（如 "中文"）
    ///   - name: 翻译名称（如 "Chinese"）
    /// - Returns: 语言文本视图
    @ViewBuilder
    private func languageTextView(
      isoCode: String,
      nativeName: String?,
      name: String?
    ) -> some View {
      if let nativeName, let name {
        // 显示 "本地名称 (翻译名称)"
        Text("\(nativeName) (\(name))")
      } else {
        // 只显示大写的 ISO 代码
        Text(isoCode.uppercased())
      }
    }

    /// 语言列表区域
    ///
    /// 显示一组语言的列表项。
    ///
    /// - Parameter languages: 语言列表
    /// - Returns: 语言列表视图
    private func languageSheetSection(languages: [Language]) -> some View {
      ForEach(languages) { language in
        HStack {
          languageTextView(
            isoCode: language.isoCode,
            nativeName: language.nativeName,
            name: language.localizedName
          ).tag(language.isoCode)
          Spacer()
          if language.isoCode == viewModel.selectedLanguage {
            Image(systemName: "checkmark")
          }
        }
        .listRowBackground(theme.primaryBackgroundColor)
        .contentShape(Rectangle())
        .onTapGesture {
          viewModel.selectedLanguage = language.isoCode
          viewModel.hasExplicitlySelectedLanguage = true
          close()
        }
      }
    }

    /// 最近使用的语言列表
    ///
    /// 从用户偏好设置中获取最近使用的语言。
    private var recentlyUsedLanguages: [Language] {
      preferences.recentlyUsedLanguages.compactMap { isoCode in
        Language.allAvailableLanguages.first { $0.isoCode == isoCode }
      }
    }

    /// 其他语言列表
    ///
    /// 过滤掉最近使用的语言，返回其他所有语言。
    private var otherLanguages: [Language] {
      Language.allAvailableLanguages.filter {
        !preferences.recentlyUsedLanguages.contains($0.isoCode)
      }
    }

    /// 语言搜索结果
    ///
    /// 根据搜索查询过滤语言列表。
    ///
    /// - Parameter query: 搜索查询文本
    /// - Returns: 匹配的语言列表
    private func languageSearchResult(query: String) -> [Language] {
      Language.allAvailableLanguages.filter { language in
        guard !query.isEmpty else { return true }
        // 按本地名称或翻译名称搜索（前缀匹配，不区分大小写）
        return language.nativeName?.lowercased().hasPrefix(query.lowercased()) == true
          || language.localizedName?.lowercased().hasPrefix(query.lowercased()) == true
      }
    }

    /// 关闭面板
    private func close() {
      isPresented.toggle()
    }
  }
}
