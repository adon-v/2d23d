# TapeBuilder 模块

TapeBuilder 是一个用于在SketchUp中创建区域边界胶带标识的模块。该模块可以根据区域的点坐标，在区域边界创建具有一定宽度和高度的胶带效果。

## 功能特点

- 从区域点集生成边界胶带
- 支持冲突检测，避免与现有实体重叠
- 可配置的胶带宽度、高度和颜色
- 简单易用的API

## 文件结构

- `tape_builder.rb` - 主要类实现
- `tape_constants.rb` - 常量定义
- `tape_utils.rb` - 工具函数
- `main.rb` - 使用示例和测试入口

## 使用方法

### 基本用法

```ruby
# 加载TapeBuilder模块
require 'E:/惠工云/2d23d/2d23d/lib/TapeBuilder/main'

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

# 生成胶带
TapeBuilder::Builder.generate_zone_tape(zone_points, parent_group)
```

### 从区域数据生成胶带

```ruby
# 加载TapeBuilder模块
require 'E:/惠工云/2d23d/2d23d/lib/TapeBuilder/main'

# 区域数据
zone_data = {
  "id" => "zone2",
  "name" => "办公区域",
  "shape" => {
    "type" => "polygon",
    "points" => [
      [0, 0, 0],
      [5, 0, 0],
      [5, 5, 0],
      [0, 5, 0]
    ]
  }
}

# 生成胶带
TapeBuilder.generate_tape_from_zone_data(zone_data)
```

### 运行测试

```ruby
# 加载TapeBuilder模块
require 'E:/惠工云/2d23d/2d23d/lib/TapeBuilder/main'

# 运行测试
TapeBuilder.test_tape_generation
```

## 配置参数

可以在`tape_constants.rb`中修改以下参数：

- `TAPE_COLOR` - 胶带颜色 [R, G, B]
- `TAPE_WIDTH` - 胶带宽度（米）
- `TAPE_HEIGHT` - 胶带高度（米）
- `TAPE_ELEVATION` - 胶带上浮高度（米）
- `CONFLICT_DETECTION_TOLERANCE` - 冲突检测容差（米）
- `CONFLICT_RAY_COUNT` - 每段边界发射的射线数量

## 注意事项

- 当前版本只支持简单的长方形区域
- 胶带材质目前只支持纯色（黄色）
- 冲突检测功能已暂时禁用，可根据需要在代码中启用
- 如果遇到常量重定义警告，可以忽略，不影响功能 