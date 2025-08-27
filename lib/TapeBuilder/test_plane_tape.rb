# 平面胶带测试脚本
# 测试修改后的胶带生成逻辑，验证胶带是否为平面而非立方体

require_relative 'tape_builder'

def test_plane_tape
  puts "=== 平面胶带测试开始 ==="
  
  # 获取当前模型
  model = Sketchup.active_model
  if !model
    puts "错误：无法获取当前模型"
    return
  end
  
  # 创建父组
  parent_group = model.active_entities.add_group
  parent_group.name = "平面胶带测试组"
  
  puts "调试：创建父组: #{parent_group.name}"
  
  # 定义测试区域点（简单的矩形）
  zone_points = [
    Geom::Point3d.new(0, 0, 0),
    Geom::Point3d.new(5, 0, 0),
    Geom::Point3d.new(5, 5, 0),
    Geom::Point3d.new(0, 5, 0)
  ]
  
  puts "调试：测试区域点:"
  zone_points.each_with_index do |point, i|
    puts "  点#{i}: #{point.inspect}"
  end
  
  # 生成平面胶带
  puts "调试：开始生成平面胶带..."
  TapeBuilder::Builder.generate_zone_tape(zone_points, parent_group)
  
  # 验证结果
  puts "调试：验证生成的胶带..."
  
  # 检查父组中的实体
  entities = parent_group.entities
  puts "调试：父组中的实体数量: #{entities.length}"
  
  # 统计不同类型的实体
  faces = entities.grep(Sketchup::Face)
  edges = entities.grep(Sketchup::Edge)
  groups = entities.grep(Sketchup::Group)
  
  puts "调试：实体统计:"
  puts "  面: #{faces.length}"
  puts "  边: #{edges.length}"
  puts "  组: #{groups.length}"
  
  # 检查胶带面
  tape_faces = faces.select { |face| face.material && face.material.name == "Tape" }
  puts "调试：胶带面数量: #{tape_faces.length}"
  
  # 验证胶带面的几何特性
  tape_faces.each_with_index do |face, i|
    puts "调试：胶带面#{i}:"
    puts "  有效性: #{face.valid?}"
    puts "  顶点数: #{face.vertices.length}"
    puts "  边数: #{face.edges.length}"
    puts "  材质: #{face.material ? face.material.name : '无'}"
    puts "  法线: #{face.normal.inspect}"
    
    # 检查是否为平面（所有顶点应该在同一个平面上）
    vertices = face.vertices.map(&:position)
    if vertices.length >= 3
      # 计算面的法线
      v1 = vertices[1] - vertices[0]
      v2 = vertices[2] - vertices[0]
      normal = v1.cross(v2)
      normal.normalize!
      
      puts "  计算法线: #{normal.inspect}"
      puts "  面法线: #{face.normal.inspect}"
      
      # 检查法线是否一致
      if normal.dot(face.normal).abs > 0.9
        puts "  ✓ 法线一致"
      else
        puts "  ✗ 法线不一致"
      end
    end
    
    # 检查面的边界框
    bounds = face.bounds
    puts "  边界框: #{bounds.inspect}"
    puts "  厚度: #{(bounds.depth * 39.3701).round(3)} 英寸"
    puts "  上浮高度: #{(bounds.min.z * 39.3701).round(3)} 英寸"
    
    # 验证是否为薄平面（厚度应该很小）
    if bounds.depth < 0.01
      puts "  ✓ 确认为薄平面"
    else
      puts "  ✗ 厚度过大，可能不是平面"
    end
    
    # 验证上浮高度（应该在0.1米左右）
    expected_elevation = 0.1  # 期望的上浮高度（米）
    actual_elevation = bounds.min.z
    elevation_tolerance = 0.01  # 容差（米）
    
    if (actual_elevation - expected_elevation).abs < elevation_tolerance
      puts "  ✓ 上浮高度正确: #{actual_elevation.round(3)}m"
    else
      puts "  ✗ 上浮高度不正确: 期望#{expected_elevation}m，实际#{actual_elevation.round(3)}m"
    end
  end
  
  puts "=== 平面胶带测试完成 ==="
  
  # 返回父组以便进一步检查
  parent_group
end

# 如果直接运行此脚本，执行测试
if __FILE__ == $0
  test_plane_tape
end 