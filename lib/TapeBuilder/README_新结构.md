# TapeBuilder 模块 - 重构版本

TapeBuilder 是一个用于在SketchUp中创建区域边界胶带标识的模块。该模块已经重构为更小、更易维护的组件结构。

**重要更新：胶带现在被视为平面而非立方体，提供更轻量级的边界标识。**

## 🏗️ 新的模块结构

### 核心文件
- **`tape_builder.rb`** - 模块入口文件，负责加载所有组件
- **`tape_builder_core.rb`** - 核心胶带生成逻辑，包含主要的生成方法和边界线段提取
- **`tape_constants.rb`** - 常量定义（胶带宽度、厚度、颜色等）
- **`tape_utils.rb`** - 工具函数（点、向量操作等）

### 功能组件
- **`tape_conflict_detector.rb`** - 冲突检测逻辑，检查胶带位置是否已有实体
- **`tape_face_creator.rb`** - 胶带面创建逻辑，负责创建胶带平面
- **`tape_elevator.rb`** - 胶带拉高逻辑（已关闭，胶带保持为平面）
- **`tape_material_applier.rb`** - 材质应用逻辑，应用胶带材质和颜色
- **`tape_connection_handler.rb`** - 胶带连接处理逻辑，处理胶带之间的连接

### 其他文件
- **`main.rb`** - 主程序入口，包含菜单注册和测试功能
- **`register_extension.rb`** - SketchUp扩展注册
- **`test_tape_builder.rb`** - 测试脚本
- **`test_plane_tape.rb`** - 平面胶带测试脚本（新增）

## 🔄 重构优势

### 1. 单一职责原则
每个文件现在只负责一个特定的功能领域，使代码更容易理解和维护。

### 2. 更好的可测试性
各个组件可以独立测试，不需要加载整个模块。

### 3. 更容易扩展
新功能可以添加到相应的组件中，而不会影响其他部分。

### 4. 更好的代码组织
相关的功能被组织在一起，提高了代码的可读性。

## 📁 文件大小对比

| 文件 | 重构前 | 重构后 |
|------|--------|--------|
| `tape_builder.rb` | 826行 | 34行 |
| `tape_builder_core.rb` | - | 67行 |
| `tape_conflict_detector.rb` | - | 200行 |
| `tape_face_creator.rb` | - | 120行 |
| `tape_elevator.rb` | - | 250行 |
| `tape_material_applier.rb` | - | 80行 |
| `tape_connection_handler.rb` | - | 90行 |

## 🚀 使用方法

### 基本用法（保持不变）
```ruby
# 加载TapeBuilder模块
require 'path/to/TapeBuilder/main'

# 创建父组
model = Sketchup.active_model
parent_group = model.active_entities.add_group

# 区域四个点坐标
zone_points = [
  [0, 0, 0],
  [5, 0, 0],
  [5, 5, 0],
  [0, 5, 0]
]

# 生成平面胶带（不再创建立方体）
TapeBuilder::Builder.generate_zone_tape(zone_points, parent_group)
```

### 平面胶带特性
- **轻量级**：胶带现在是薄平面，文件大小更小
- **快速渲染**：不需要复杂的3D几何计算
- **易于编辑**：平面胶带更容易选择和修改
- **材质应用**：只应用正面材质，背面保持透明
- **防抢面**：胶带会上浮到0.1米高度，避免与地面发生z-fighting
- **简单上浮**：使用简单的变换上浮，不创建立方体，保持平面特性

### 测试平面胶带功能
```ruby
# 运行平面胶带测试
load 'path/to/TapeBuilder/test_plane_tape.rb'
test_plane_tape
```

### 直接使用特定组件
```ruby
# 只加载冲突检测器
require_relative 'tape_conflict_detector'
require_relative 'tape_constants'

# 检查线段冲突
has_conflict = TapeBuilder::ConflictDetector.check_segment_conflict(segment, width, parent_group)
```

## 🔧 开发指南

### 添加新功能
1. 确定功能属于哪个组件
2. 在相应的文件中添加方法
3. 如果需要新的组件，创建新文件并更新 `tape_builder.rb`

### 修改现有功能
1. 找到功能所在的组件文件
2. 修改相应的方法
3. 确保更新相关的测试

### 调试
每个组件都有详细的调试输出，可以通过查看控制台输出来诊断问题。

## 📋 向后兼容性

重构后的模块保持了完全的向后兼容性：
- 所有公共API保持不变
- 现有的代码无需修改
- 模块的加载方式相同

## 🎯 未来计划

- [ ] 添加更多的胶带样式选项
- [ ] 实现胶带动画效果
- [ ] 添加批量处理功能
- [ ] 改进冲突检测算法
- [ ] 添加更多的材质选项

## 📞 支持

如果您在使用过程中遇到问题，请检查：
1. 所有必要的文件是否都在同一目录中
2. SketchUp版本是否兼容
3. 控制台是否有错误信息

重构后的代码结构更清晰，维护更容易，欢迎贡献代码和改进建议！ 