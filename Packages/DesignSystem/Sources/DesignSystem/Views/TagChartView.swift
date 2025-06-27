// 文件功能说明：
// 该文件实现了标签图表视图组件，使用Swift Charts框架为Mastodon标签创建简洁的历史使用趋势图，展示标签在不同时间段的使用频率变化。

// 技术点：
// 1. Swift Charts框架 —— 苹果官方图表绘制库
// 2. AreaMark图表类型 —— 面积图表示法
// 3. @State状态管理 —— 本地状态数据存储
// 4. 数据排序处理 —— sorted方法和自定义比较逻辑
// 5. firstIndex查找 —— 数组索引查找方法
// 6. 字符串转整型 —— Int()可失败初始化器
// 7. 插值方法 —— catmullRom平滑曲线算法
// 8. 图表轴隐藏 —— chartXAxis和chartYAxis隐藏
// 9. 裁剪形状 —— clipShape圆角矩形裁剪
// 10. 图表配置 —— 图例隐藏和尺寸固定

// 技术点详解：
// 1. Swift Charts：iOS 16+引入的原生图表框架，提供声明式图表构建语法
// 2. AreaMark：Charts框架中的面积图标记，用于显示数据随时间变化的趋势
// 3. @State：SwiftUI状态管理，用于存储和管理组件内部的可变数据
// 4. 数据排序：使用sorted方法按日期对历史数据进行升序排列
// 5. firstIndex：Array方法，查找满足条件的第一个元素的索引位置
// 6. 可失败初始化：Int()构造器可能失败，使用nil合并运算符提供默认值
// 7. 插值方法：catmullRom算法创建平滑的曲线连接，避免锐角转折
// 8. 图表轴配置：隐藏X和Y轴标签，创建简洁的微型图表
// 9. 裁剪形状：使用圆角矩形裁剪图表边界，提供美观的视觉效果
// 10. 图表配置：固定尺寸和隐藏图例，适合在列表或卡片中嵌入显示

// 导入Charts框架，提供图表绘制功能
import Charts
// 导入Models模块，提供Tag和History数据模型
import Models
// 导入SwiftUI框架，提供视图构建功能
import SwiftUI

// 定义公共的标签图表视图，用于显示标签使用趋势
public struct TagChartView: View {
  // 存储排序后的历史数据状态
  @State private var sortedHistory: [History] = []

  // 公共初始化方法，接受标签数据并预处理历史信息
  public init(tag: Tag) {
    // 初始化状态，对标签历史数据按日期升序排序
    _sortedHistory = .init(
      initialValue: tag.history.sorted {
        // 将日期字符串转换为整数进行比较，无法转换时默认为0
        Int($0.day) ?? 0 < Int($1.day) ?? 0
      })
  }

  // 视图主体，定义图表的UI结构
  public var body: some View {
    // 创建面积图表，使用排序后的历史数据
    Chart(sortedHistory) { data in
      // 添加面积标记，表示每个数据点
      AreaMark(
        // X轴值：使用数据在数组中的索引作为时间轴
        x: .value("day", sortedHistory.firstIndex(where: { $0.id == data.id }) ?? 0),
        // Y轴值：标签在该日期的使用次数
        y: .value("uses", Int(data.uses) ?? 0)
      )
      // 设置插值方法为Catmull-Rom样条曲线，创建平滑的曲线
      .interpolationMethod(.catmullRom)
    }
    // 隐藏图表图例
    .chartLegend(.hidden)
    // 隐藏X轴（时间轴）
    .chartXAxis(.hidden)
    // 隐藏Y轴（数值轴）
    .chartYAxis(.hidden)
    // 设置图表固定尺寸：宽70点，高40点（适合嵌入列表）
    .frame(width: 70, height: 40)
    // 使用圆角矩形裁剪图表，圆角半径4点
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}
