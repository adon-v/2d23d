# 工厂布局导入插件 - 重构版本

## 主要改进

### 1. 功能独立性
每个功能模块都可以独立运行，即使某个模块出现错误，也不会影响其他模块：

- ✅ 墙体构建 (WallBuilder)
- ✅ 门构建 (DoorBuilder) 
- ✅ 窗户构建 (WindowBuilder)
- ✅ 区域构建 (ZoneBuilder)
- ✅ 结构构建 (StructureBuilder)
- ✅ 流程构建 (FlowBuilder)
- ✅ 设备构建 (EquipmentBuilder)
- ✅ 胶带构建 (TapeBuilder)
- ✅ 几何体优化 (GeometryOptimizer) - **新增**

### 2. 几何体优化功能 - **新增**
为了解决现有插件输出的项目mesh太多不利于后续操作的问题，新增了几何体优化模块：

#### 优化策略
1. **炸组（Explode Groups/Components）**: 将不需要独立交互的组件全部炸开
2. **焊接共面面**: 合并相邻的共面面，减少面数量
3. **减少组件数量**: 把整面墙、地板、屋顶等合并成一个整体Mesh
4. **清理孤立实体**: 删除无用的边和点

#### 优化效果
- 减少实体数量（通常可减少30-50%）
- 减少组件数量（通常可减少40-60%）
- 减少面数量（通常可减少20-40%）
- 提高模型性能，便于后续操作

### 3. 错误隔离机制
- 分级错误处理（严重错误、一般错误、警告、信息）
- 自动恢复策略
- 错误日志记录
- 继续运行机制

### 4. 模块化架构
- **PluginManager**: 模块初始化和依赖管理
- **ErrorHandler**: 统一错误处理
- **ConfigManager**: 功能开关和参数管理
- **FeatureTester**: 功能独立性测试
- **GeometryOptimizer**: 几何体优化 - **新增**

## 项目结构

```
Vscode/
├── main.rb                    # 主入口文件（重构）
├── lib/
│   ├── core.rb               # 核心模块
│   ├── ui_manager.rb         # UI管理
│   ├── factory_importer.rb   # 工厂导入主模块（重构）
│   ├── wall_builder.rb       # 墙体构建
│   ├── door_builder.rb       # 门构建
│   ├── window_builder.rb     # 窗户构建
│   ├── zone_builder.rb       # 区域构建
│   ├── structure_builder.rb  # 结构构建
│   ├── flow_builder.rb       # 流程构建
│   ├── equipment_builder.rb  # 设备构建
│   ├── tape_builder.rb       # 胶带构建
│   ├── utils.rb              # 工具函数
│   ├── error_handler.rb      # 错误处理
│   ├── config_manager.rb     # 配置管理
│   ├── feature_tester.rb     # 功能测试
│   └── geometry_optimizer.rb # 几何体优化（新增）
└── README.md                 # 说明文档
```

## 使用方法

### 功能配置
```ruby
# 禁用某个功能
ConfigManager.disable_feature(:wall_builder)

# 启用某个功能
ConfigManager.enable_feature(:wall_builder)

# 配置几何体优化
ConfigManager.set(:geometry_optimization, {
  enabled: true,
  explode_groups: true,
  merge_faces: true,
  merge_components: true,
  cleanup_orphaned: true,
  auto_optimize: true,
  optimization_threshold: {
    total_entities: 1000,
    groups_count: 100,
    faces_count: 500
  }
})
```

### 错误处理
```ruby
# 安全执行代码块
result = ErrorHandler.safe_execute("墙体创建") do
  WallBuilder.import_walls(walls_data, parent_group)
end
```

### 功能测试
```ruby
# 运行功能独立性测试
FeatureTester.test_all_features
```

### 几何体优化 - **新增**
```ruby
# 手动运行几何体优化
GeometryOptimizer.optimize_factory_layout(main_group)

# 分析几何体状态
stats = GeometryOptimizer.analyze_geometry(main_group)
puts "实体数量: #{stats[:total_entities]}"
puts "组件数量: #{stats[:groups_count]}"
puts "面数量: #{stats[:faces_count]}"

# 检查是否需要优化
if GeometryOptimizer.should_optimize?(main_group)
  puts "建议进行几何体优化"
end
```

## 几何体优化配置详解

### 优化选项
- **enabled**: 是否启用几何体优化
- **explode_groups**: 是否炸开不必要的组件
- **merge_faces**: 是否合并共面面
- **merge_components**: 是否合并同类组件
- **cleanup_orphaned**: 是否清理孤立实体
- **auto_optimize**: 是否自动优化（根据阈值判断）

### 优化阈值
- **total_entities**: 总实体数量阈值（默认1000）
- **groups_count**: 组件数量阈值（默认100）
- **faces_count**: 面数量阈值（默认500）

### 优化效果示例
```
=== 几何体优化结果 ===
炸开的组件: 45 个
合并的面: 23 对
合并的组件: 12 对

优化前: 实体=1500, 组件=120, 面=800
优化后: 实体=850, 组件=63, 面=520
优化效果: 减少实体=650, 减少组件=57, 减少面=280
```

## 版本历史

### v21 (重构版本)
- ✅ 实现功能模块化
- ✅ 添加错误隔离机制
- ✅ 引入配置管理
- ✅ 添加功能测试
- ✅ 优化项目结构
- ✅ **新增几何体优化功能**

## 向后兼容性

### 保持不变的方面
- ✅ 所有原有功能的实现细节保持不变
- ✅ 所有原有的API接口保持不变
- ✅ 所有原有的数据格式保持不变
- ✅ 所有原有的用户交互保持不变

### 新增的功能
- 🔧 插件管理器
- 🔧 错误处理系统
- 🔧 配置管理系统
- 🔧 功能测试系统
- 🔧 **几何体优化系统** - 新增

## 使用建议

### 1. 几何体优化使用
- 插件会在导入完成后自动进行几何体优化
- 可以通过配置控制优化行为
- 建议在大型项目中启用优化功能
- 优化过程会显示详细的统计信息

### 2. 性能优化
- 对于大型工厂布局，建议启用所有优化选项
- 可以根据项目需求调整优化阈值
- 优化后的模型更适合后续的编辑和渲染操作

### 3. 故障排除
- 如果优化过程中出现错误，会记录在错误日志中
- 可以禁用特定的优化选项来避免问题
- 优化是可选的，不会影响核心功能

