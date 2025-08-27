# ZoneBuilder 模块说明文档

## 概述
`ZoneBuilder` 是一个用于处理工厂区域创建和着色的核心模块。该模块负责导入内部区域、外部区域，生成区域地面着色，以及创建工厂总地面等功能。

## 主要功能

### 1. 区域导入功能
- **内部区域导入** (`import_zones`): 处理工厂内部功能区域的创建
- **外部区域导入** (`import_zones_out_factory`): 处理工厂外部区域的创建
- **共享边界检测**: 自动检测紧邻区域并优化处理

### 2. 地面着色功能
- **内部区域着色** (`create_indoor_zones_floor`): 为内部区域创建彩色地面
- **外部区域着色** (`create_outdoor_zones_floor`): 为外部区域创建彩色地面
- **工厂总地面** (`generate_factory_total_ground`): 基于区域和外墙点生成总地面
- **基于工厂尺寸的地面** (`generate_factory_ground_from_size`): 根据工厂size数据生成地面

### 3. 几何优化功能
- **紧邻区域处理**: 避免区域间的几何冲突
- **点序列优化**: 优化区域边界点的排列
- **微小偏移**: 为紧邻区域添加微小偏移避免抢面问题

## 区域创建详细逻辑流程

### 第一阶段：数据预处理和验证

#### 1.1 共享边界检测
```ruby
# 检测共享边界逻辑
shared_boundaries = Utils.detect_shared_boundaries(zones_data)
if shared_boundaries.any?
  puts "检测到 #{shared_boundaries.size} 对紧邻区域，启用优化处理"
  shared_boundaries.each do |boundary|
    puts "  - #{boundary[:zone1][:zone1_name]} 与 #{boundary[:zone2][:zone2_name]} 共享边界"
  end
end
```

**检测目的**: 识别存在共享边界的区域对，为后续的几何优化做准备
**优化策略**: 启用紧邻区域处理模式，避免几何冲突

#### 1.2 区域数据完整性验证
```ruby
# 数据验证流程
unless zone_data && zone_data["shape"]
  puts "警告: 区域缺少shape数据，跳过"
  next
end

shape = zone_data["shape"]
unless shape["points"]
  puts "警告: 区域 #{zone_data['name'] || zone_data['id']} 缺少points数据，跳过"
  next
end
```

**验证项目**:
- 区域数据对象存在性
- shape数据结构完整性
- points数组数据有效性

**跳过条件**: 任何关键数据缺失都会导致区域被跳过

### 第二阶段：形状类型识别和处理

#### 2.1 形状类型判断
```ruby
shape_type = shape["type"] || "polygon"
puts "区域形状类型: #{shape_type}"

case shape_type.downcase
when "polygon", "多边形"
  # 多边形处理逻辑
when "rectangle", "矩形"
  # 矩形处理逻辑
else
  puts "不支持的区域形状类型: #{shape_type}"
end
```

**支持类型**:
- `polygon` / `多边形`: 直接处理
- `rectangle` / `矩形`: 转换为多边形后处理
- 其他类型: 记录警告并跳过

#### 2.2 矩形转多边形处理
```ruby
when "rectangle", "矩形"
  # 对于矩形，先转换为多边形处理
  points = shape["points"].map { |point| Utils.validate_and_create_point(point) }.compact
  next if points.size != 4
  puts "矩形区域点数: #{points.size}"
  
  # 检查矩形点是否按顺序排列，如果不是则重新排序
  points = Utils.sort_rectangle_points(points)
  
  # 创建临时的多边形数据
  polygon_zone_data = zone_data.dup
  polygon_zone_data["shape"] = {
    "type" => "polygon",
    "points" => shape["points"]
  }
```

**转换步骤**:
1. 验证矩形点数（必须为4个）
2. 点序列排序优化
3. 创建临时多边形数据结构

### 第三阶段：几何创建和优化

#### 3.1 紧邻区域处理调用
```ruby
# 使用新的紧邻处理功能
zone_group = Utils.create_zone_with_adjacency_handling(parent_group, zone_data, created_zones)
if zone_group
  # 隐藏基础区域平面和边缘线
  hide_base_plane_and_edges(zone_group)
  
  created_zones << zone_group
  puts "成功创建区域: #{zone_data["name"] || zone_data["id"]}"
else
  puts "跳过创建区域: #{zone_data["name"] || zone_data["id"]} (可能存在冲突)"
end
```

**处理流程**:
1. 调用 `Utils.create_zone_with_adjacency_handling` 处理几何创建
2. 检查创建结果
3. 成功时进行后续处理，失败时记录并跳过

#### 3.2 基础平面和边缘线隐藏
```ruby
def self.hide_base_plane_and_edges(zone_group)
  # 遍历组内所有面，识别并隐藏基础平面（通常是Z=0的面）
  zone_group.entities.grep(Sketchup::Face).each do |face|
    # 判断是否为基础平面（Z坐标接近0）
    is_base_plane = face.vertices.all? { |v| v.position.z.abs < 0.01 }
    
    if is_base_plane
      # 隐藏基础平面
      face.hidden = true
      
      # 隐藏该面的所有边缘线
      face.edges.each do |edge|
        edge.hidden = true
      end
    end
  end
end
```

**隐藏逻辑**:
- 识别基础平面：Z坐标接近0的面
- 隐藏基础平面和其边缘线
- 保持几何完整性，只隐藏视觉显示

### 第四阶段：地面着色创建

#### 4.1 内部区域地面着色流程
```ruby
def self.create_indoor_zones_floor(parent_group, zones_data, shared_boundaries = [])
  # 内部区域专用颜色映射
  func_colors = {
    "装配区" => [255, 255, 204],    # 浅黄色
    "加工区" => [204, 255, 204],    # 浅绿色
    "仓储区" => [204, 204, 255],    # 浅蓝色
    "办公区" => [255, 204, 255],    # 浅粉色
    "质检区" => [255, 204, 153],    # 浅橙色
    "default" => [220, 220, 220]    # 默认灰色
  }
  
  has_adjacent_zones = shared_boundaries.any?
```

**颜色分配策略**:
- 基于区域类型名称匹配
- 循环使用颜色数组作为备选
- 默认灰色作为兜底方案

#### 4.2 点序列优化和偏移处理
```ruby
# 优化点序列
optimized_points = Utils.optimize_zone_points(points, zone["name"])

# 如果有紧邻区域，添加微小偏移
if has_adjacent_zones
  is_adjacent = shared_boundaries.any? do |boundary|
    boundary[:zone1][:zone1_id] == zone["id"] || boundary[:zone2][:zone2_id] == zone["id"]
  end
  if is_adjacent
    optimized_points = Utils.add_zone_offset(optimized_points, zone["id"], 0.001)
  end
end
```

**优化步骤**:
1. 调用 `Utils.optimize_zone_points` 优化点序列
2. 检查是否为紧邻区域
3. 为紧邻区域添加0.001米的微小偏移

#### 4.2.1 区域偏移算法详解 (`add_zone_offset`)

```ruby
def self.add_zone_offset(points, zone_id, offset_distance = 0.001)
  return points if points.size < 3
  
  center_x = points.map(&:x).sum / points.size
  center_y = points.map(&:y).sum / points.size
  center_z = points.map(&:z).sum / points.size
  center = Geom::Point3d.new(center_x, center_y, center_z)
  
  offset_points = points.map do |point|
    vec = Geom::Vector3d.new(point.x - center.x, point.y - center.y, 0)
    
    if vec.length < 1e-12
      point.dup
    else
      dir = vec.normalize
      offset_vec = dir * offset_distance
      Geom::Point3d.new(point.x + offset_vec.x, point.y + offset_vec.y, point.z)
    end
  end
  
  offset_points
end
```

**算法逻辑详解**:

**第一步：输入验证**
- 检查点数是否足够（至少3个点）
- 不足时直接返回原始点集

**第二步：计算区域中心点**
```ruby
center_x = points.map(&:x).sum / points.size
center_y = points.map(&:y).sum / points.size
center_z = points.map(&:z).sum / points.size
center = Geom::Point3d.new(center_x, center_y, center_z)
```
- 计算所有点的X、Y、Z坐标平均值
- 创建区域几何中心点

**第三步：计算每个点的偏移向量**
```ruby
vec = Geom::Vector3d.new(point.x - center.x, point.y - center.y, 0)
```
- 从中心点指向当前点的向量
- Z分量设为0（保持水平偏移）

**第四步：处理特殊情况**
```ruby
if vec.length < 1e-12
  point.dup
else
  # 正常偏移处理
end
```
- 当点与中心点重合时（向量长度接近0），直接复制原点
- 避免除零错误

**第五步：计算偏移后的新位置**
```ruby
dir = vec.normalize
offset_vec = dir * offset_distance
Geom::Point3d.new(point.x + offset_vec.x, point.y + offset_vec.y, point.z)
```
- 将向量标准化为单位向量
- 乘以偏移距离得到偏移向量
- 在原点基础上添加偏移量

**偏移效果**:
- 所有点都向外扩展（远离中心点）
- 保持区域的整体形状和比例
- 避免与相邻区域的几何冲突
- 偏移距离：0.001米（1毫米）

#### 4.3 分层地面系统
```ruby
# 内部区域地面上浮高度调整为0.3（高于外部区域，解决抢面问题）
elevated_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.3) }

# 外部区域地面上浮高度调整为0.2（解决抢面问题）
elevated_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.2) }
```

**分层策略**:
- 内部区域：Z + 0.3米（最高层）
- 外部区域：Z + 0.2米（中间层）
- 总地面：Z + 0.0米（基础层）

**解决抢面问题**: 通过高度分层避免不同区域地面在Z=0平面上的几何冲突

## 抢面问题详解

### 什么是"抢面"？

**抢面（Face Competition）** 是3D建模中的一个常见问题，指多个几何对象试图占据同一个几何空间，导致：

1. **几何冲突**: 两个或多个面完全重叠
2. **渲染异常**: 面闪烁、消失或显示异常
3. **选择困难**: 无法准确选择特定的面或区域
4. **数据不一致**: 几何数据出现矛盾

### 抢面问题的具体表现

```ruby
# 问题场景示例
# 区域A和区域B在Z=0平面上有重叠的边界
zone_a_floor = create_face([[0,0,0], [100,0,0], [100,100,0], [0,100,0]])
zone_b_floor = create_face([[50,50,0], [150,50,0], [150,150,0], [50,150,0]])

# 结果：两个面在重叠区域产生冲突
# - 面可能闪烁或消失
# - 无法准确选择特定区域
# - 几何数据不一致
```

### 代码如何解决抢面问题

#### 1. 分层地面系统（主要解决方案）

```ruby
# 内部区域地面上浮高度调整为0.3（高于外部区域，解决抢面问题）
elevated_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.3) }

# 外部区域地面上浮高度调整为0.2（解决抢面问题）
elevated_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.2) }
```

**分层策略**:
- **内部区域**: Z + 0.3米（最高层）
- **外部区域**: Z + 0.2米（中间层）  
- **总地面**: Z + 0.0米（基础层）

**解决原理**: 通过Z轴分层，确保不同区域的地面不在同一个平面上，避免几何重叠

#### 2. 微小偏移处理（辅助解决方案）

```ruby
# 为紧邻区域添加微小偏移
if is_adjacent
  optimized_points = Utils.add_zone_offset(optimized_points, zone["id"], 0.001)
end
```

**偏移策略**:
- 偏移距离：0.001米（1毫米）
- 偏移方向：从区域中心向外扩展
- 偏移目的：为相邻区域提供微小的几何分离

#### 3. 完整的抢面解决方案

```ruby
# 解决抢面问题的完整流程
def solve_face_competition(zone_data, shared_boundaries)
  # 第一步：检测紧邻区域
  is_adjacent = detect_adjacent_zones(zone_data, shared_boundaries)
  
  # 第二步：应用微小偏移
  if is_adjacent
    points = add_zone_offset(points, zone_data["id"], 0.001)
  end
  
  # 第三步：应用高度分层
  elevation_height = get_elevation_height(zone_data["type"])
  elevated_points = points.map { |pt| pt.offset(0, 0, elevation_height) }
  
  # 第四步：创建分离的地面
  create_separated_floor(elevated_points)
end
```

### 抢面问题的技术细节

#### 几何层面的解决

1. **空间分离**: 通过Z轴高度差创建物理分离
2. **边界偏移**: 通过微小偏移创建边界分离
3. **层次管理**: 建立清晰的地面层次结构

#### 渲染层面的解决

1. **面独立性**: 每个区域都有独立的地面面
2. **材质区分**: 不同区域使用不同颜色和材质
3. **属性标识**: 为每个面设置唯一的属性信息

### 实际效果对比

#### 解决前的问题
- ❌ 区域边界重叠，面闪烁
- ❌ 无法准确选择特定区域
- ❌ 几何数据不一致
- ❌ 渲染效果异常

#### 解决后的效果
- ✅ 区域边界清晰分离
- ✅ 每个区域独立可选中
- ✅ 几何数据一致
- ✅ 渲染效果稳定

### 技术优势

1. **自动处理**: 无需手动调整，系统自动检测和解决
2. **性能优化**: 微小偏移对性能影响极小
3. **视觉保持**: 偏移量小到几乎不可见
4. **兼容性好**: 适用于各种形状和尺寸的区域

### 第五阶段：属性设置和材质应用

#### 5.1 区域组属性设置
```ruby
# 设置组的属性（重要：确保区域可以被识别）
zone_group.set_attribute('FactoryImporter', 'zone_type', 'indoor')
zone_group.set_attribute('FactoryImporter', 'zone_id', zone["id"])
zone_group.set_attribute('FactoryImporter', 'zone_name', zone["name"] || "未命名区域")
zone_group.set_attribute('FactoryImporter', 'zone_shape_type', shape["type"] || "polygon")
```

**属性信息**:
- `zone_type`: 区域类型（indoor/outdoor）
- `zone_id`: 区域唯一标识
- `zone_name`: 区域名称
- `zone_shape_type`: 形状类型

#### 5.2 地面面属性设置
```ruby
# 设置面的属性
face.set_attribute('FactoryImporter', 'face_type', 'indoor_floor')
face.set_attribute('FactoryImporter', 'zone_id', zone["id"])
face.set_attribute('FactoryImporter', 'zone_name', zone["name"] || "未命名区域")
```

**面属性信息**:
- `face_type`: 面类型（indoor_floor/outdoor_floor）
- `zone_id`: 关联的区域ID
- `zone_name`: 关联的区域名称

#### 5.3 材质和颜色应用
```ruby
func = (zone["type"] || zone["name"] || "default").to_s
color = func_colors[func] || func_colors.values[idx % func_colors.size] || [200, 200, 200]
face.material = color
face.back_material = color
```

**材质分配逻辑**:
1. 优先使用区域类型名称匹配
2. 其次使用区域名称匹配
3. 最后使用循环索引或默认颜色

### 第六阶段：胶带生成和边界处理

#### 6.1 区域边界胶带生成
```ruby
# 生成内部区域边界胶带
TapeBuilder.generate_zone_boundary_tapes(zones_data, parent_group)

# 生成外部区域共享边界胶带
TapeBuilder.generate_outdoor_zone_boundary_tapes(zones_data, outdoor_group)
```

**胶带功能**:
- 标记区域边界
- 提供视觉分隔
- 支持区域识别和选择

## 核心方法详解

### import_zones(zones_data, parent_group)
**功能**: 导入内部区域数据并创建3D模型

**参数**:
- `zones_data`: 区域数据数组
- `parent_group`: 父级SketchUp组

**处理流程**:
1. 检测共享边界
2. 遍历区域数据
3. 根据形状类型创建区域（支持多边形和矩形）
4. 隐藏基础平面和边缘线
5. 生成区域边界胶带
6. 创建区域地面着色

**支持的区域形状**:
- `polygon` / `多边形`: 多边形区域
- `rectangle` / `矩形`: 矩形区域（自动转换为多边形处理）

### import_zones_out_factory(zones_data, parent_group)
**功能**: 导入外部区域数据

**特点**:
- 创建专门的外部区域组
- 设置特殊的材质和属性
- 不生成围墙，只生成胶带
- 外部区域地面上浮高度：0.2米

### create_indoor_zones_floor(parent_group, zones_data, shared_boundaries)
**功能**: 为内部区域创建地面着色

**颜色映射**:
- 装配区: 浅黄色 [255, 255, 204]
- 加工区: 浅绿色 [204, 255, 204]
- 仓储区: 浅蓝色 [204, 204, 255]
- 办公区: 浅粉色 [255, 204, 255]
- 质检区: 浅橙色 [255, 204, 153]
- 默认: 灰色 [220, 220, 220]

**技术特点**:
- 地面上浮高度：0.3米（高于外部区域）
- 自动处理紧邻区域偏移
- 隐藏边缘线避免视觉干扰

### create_outdoor_zones_floor(parent_group, zones_data, shared_boundaries)
**功能**: 为外部区域创建地面着色

**颜色映射**:
- 空压机房: 绿色 [100, 200, 100]
- 废气处理区: 棕色 [150, 100, 50]
- 非标零星钣金打磨: 橙色 [200, 150, 100]
- 喷粉原材区: 蓝色 [100, 150, 200]
- 喷粉废品区: 红色 [200, 100, 100]
- 机修房: 紫色 [150, 100, 150]
- 油品仓库: 深蓝色 [100, 100, 150]
- 默认: 绿色 [120, 180, 120]

**技术特点**:
- 地面上浮高度：0.2米
- 自动处理紧邻区域偏移
- 隐藏边缘线

### generate_factory_ground_from_size(parent_group, factories_data)
**功能**: 基于工厂size数据生成总地面

**处理流程**:
1. 解析工厂size数据（格式：`[[min_x, min_y], [max_x, max_y]]`）
2. 收集所有工厂边界点
3. 计算凸包
4. 生成总地面面
5. 设置材质和属性

**备用方案**: 当size数据无效时，自动调用`generate_default_ground_from_factories`生成默认地面

## 技术特性

### 1. 几何冲突处理
- **紧邻区域检测**: 自动识别共享边界的区域
- **微小偏移**: 为紧邻区域添加0.001米的偏移
- **分层处理**: 内部区域(0.3m) > 外部区域(0.2m) > 总地面(0m)

### 2. 性能优化
- **点序列优化**: 优化区域边界点的排列顺序
- **凸包计算**: 使用高效的凸包算法计算总边界
- **批量处理**: 一次性处理多个区域

### 3. 错误处理
- **数据验证**: 检查区域数据的完整性
- **异常捕获**: 捕获并记录创建过程中的错误
- **清理机制**: 失败时自动清理已创建的对象

### 4. 属性管理
- **SketchUp属性**: 为每个区域和面设置详细的属性信息
- **材质管理**: 自动设置合适的材质和颜色
- **组管理**: 创建有组织的组结构

## 使用示例

### 基本用法
```ruby
# 导入内部区域
ZoneBuilder.import_zones(zones_data, parent_group)

# 导入外部区域
ZoneBuilder.import_zones_out_factory(outdoor_zones_data, parent_group)

# 生成工厂总地面
ZoneBuilder.generate_factory_ground_from_size(factories_data, parent_group)
```

### 数据格式要求
```json
{
  "zones": [
    {
      "id": "zone_001",
      "name": "装配区",
      "type": "装配区",
      "shape": {
        "type": "polygon",
        "points": [
          [0, 0, 0],
          [100, 0, 0],
          [100, 100, 0],
          [0, 100, 0]
        ]
      }
    }
  ]
}
```

## 依赖关系

### 内部依赖
- `Utils`: 提供几何计算和点验证功能
- `TapeBuilder`: 生成区域边界胶带

### 外部依赖
- SketchUp API: 3D建模和几何操作
- Ruby标准库: 数组和字符串处理

## 注意事项

### 1. 性能考虑
- 大量区域时，建议分批处理
- 复杂几何形状可能影响性能

### 2. 数据质量
- 确保区域点数据完整且有效
- 避免重复或重叠的区域定义

### 3. 内存管理
- 大量区域创建时注意内存使用
- 及时清理不需要的临时对象

## 更新日志

### 版本特性
- **紧邻区域优化**: 自动检测和处理共享边界
- **分层地面系统**: 避免区域间的几何冲突
- **智能材质分配**: 基于区域类型自动分配颜色
- **错误恢复机制**: 失败时自动回退到备用方案

## 故障排除

### 常见问题
1. **区域创建失败**: 检查点数据格式和数量
2. **颜色显示异常**: 验证材质设置和SketchUp版本兼容性
3. **性能问题**: 考虑分批处理或简化几何形状

### 调试建议
- 启用详细日志输出
- 检查区域数据的完整性
- 验证SketchUp环境设置

---

*本文档基于 ZoneBuilder 模块代码分析生成，如有疑问请参考源代码或联系开发团队。* 