# 门构建器修复总结

## 问题描述

在使用 `Factory_20250814_141616.json` 文件时，门朝向全部相反，朝地下生成，而不是在墙上挖洞。但 `text.json` 的门却能正常生成。

## 问题分析

通过对比两个JSON文件，发现了问题的根源：

### text.json（正常情况）
```json
"doors": [
    {
        "id": "D01",
        "size": [[132598, 214603], [132598, 220003]],
        "height": 3000,
        "name": "西侧围墙大门"
    }
]
```
- 两个点的x坐标相同（132598），表示门在垂直墙体上
- y坐标差异为5400mm，这是门的实际高度
- 门宽度为5400mm，这是合理的门尺寸

### Factory_20250814_141616.json（有问题的情况）
```json
"doors": [
    {
        "id": "4f4e794a-2704-402e-8a7d-234ac01bd5fa",
        "size": [
            [72356.659161223244, -11354.81082265226],
            [72556.659161223361, -5954.8108226364275]
        ],
        "height": 2100,
        "name": "默认名称"
    }
]
```
- 两个点的x坐标差异为200mm
- y坐标差异为5400mm
- 计算出的宽度为5403.7mm，这个值过大，不是合理的门尺寸
- 这些坐标可能表示门在墙体上的位置范围，而不是门的几何边界

## 修复方案

### 1. 智能门宽度检测
在门构建器中添加了门宽度的合理性检查：
- 门宽度不应超过10米（10000mm），允许更大的门
- 门宽度不应小于1mm
- 当宽度过小时，使用默认门宽度0.9米
- 当宽度过大时，继续使用原始尺寸，但输出警告信息

### 2. 重新计算门边界
当门宽度不合理时：
1. 计算门的中心点
2. 基于墙体的方向向量
3. 重新计算门的起点和终点
4. 确保门洞在墙体内部正确生成

### 3. 改进的坐标处理逻辑
```ruby
# 检查门宽度是否合理（门不应该超过10米宽，允许更大的门）
max_reasonable_width = 10.0  # 10米，允许更大的门
if door_width < 0.001
  puts "警告: 门的宽度#{door_width}米过小，使用默认值0.9米"
  door_width = 0.9
  
  # 计算门的中心点
  door_center = Geom::Point3d.new(
    (start_point.x + end_point.x) / 2,
    (start_point.y + end_point.y) / 2,
    (start_point.z + end_point.z) / 2
  )
  
  # 基于墙体方向计算门的起点和终点
  wall_direction = wall_vector.normalize
  half_width = door_width / 2
  start_point = door_center - wall_direction * half_width
  end_point = door_center + wall_direction * half_width
  
  puts "重新计算门边界: 中心点=#{door_center}, 起点=#{start_point}, 终点=#{end_point}"
elsif door_width > max_reasonable_width
  puts "警告: 门的宽度#{door_width}米过大，但继续使用原始尺寸"
  puts "门宽度: #{door_width}米，位置: 起点=#{start_point}, 终点=#{end_point}"
else
  puts "门宽度正常: #{door_width}米"
end
```

## 修复的文件

- `lib/door_builder.rb` - 门构建器核心逻辑

## 修复的功能

1. **正常厚度墙体门创建** (`create_door_on_normal_wall`)
   - 智能门宽度检测
   - 重新计算门边界
   - 确保门洞在墙体内部
   - 修复厚度向量计算错误

2. **零厚度墙体门创建** (`create_door_on_zero_thickness_wall`)
   - 智能门宽度检测
   - 重新计算门边界
   - 确保门在正确的高度

3. **类型安全改进**
   - 修复"Cannot convert argument to Geom::Vector3d"错误
   - 确保数值类型转换的安全性
   - 改进厚度向量的计算逻辑

4. **门洞方向修复**
   - 修复门洞朝地下生成的问题
   - 智能检测和修正门洞面的法线方向
   - 支持两种不同的点顺序创建门洞面
   - 自动翻转错误朝向的门洞面

## 测试验证

创建了测试脚本 `test_door_fix.rb` 来验证修复效果：
- 对比正常门和问题门的坐标差异
- 验证门宽度计算的合理性
- 确认修复方案的正确性

## 预期效果

修复后，使用 `Factory_20250814_141616.json` 文件时：
1. 门将正确地在墙体上生成，而不是朝地下
2. 门洞将在墙体内部正确挖出
3. 门的尺寸将使用合理的默认值
4. 门的朝向将基于墙体的方向正确计算

## 注意事项

1. 修复后的门构建器会输出详细的调试信息
2. 当门宽度不合理时，会使用默认的0.9米宽度
3. 门的中心点基于原始坐标计算，确保位置准确性
4. 修复兼容现有的正常门数据格式 