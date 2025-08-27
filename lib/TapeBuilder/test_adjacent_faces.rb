require 'C:/Users/caifu/AppData/Roaming/SketchUp/SketchUp 2025/SketchUp/Plugins/lib/TapeBuilder/tape_elevator'

# 创建测试模型
model = Sketchup.active_model
model.start_operation("测试相邻面处理", true)

begin
  # 创建父组
  parent_group = model.active_entities.add_group
  
  # 创建第一个胶带面（模拟已有的胶带）
  face1_vertices = [
    Geom::Point3d.new(0, 0, 0),
    Geom::Point3d.new(10, 0, 0),
    Geom::Point3d.new(10, 2, 0),
    Geom::Point3d.new(0, 2, 0)
  ]
  
  face1 = parent_group.entities.add_face(face1_vertices)
  puts "创建第一个胶带面: #{face1 ? '成功' : '失败'}"
  
  if face1
    puts "第一个面的边界框: 最小点(#{face1.bounds.min.x}, #{face1.bounds.min.y}, #{face1.bounds.min.z})"
    puts "第一个面的边界框: 最大点(#{face1.bounds.max.x}, #{face1.bounds.max.y}, #{face1.bounds.max.z})"
    puts "第一个面的法线: #{face1.normal.to_s}"
    
    # 验证顶点坐标
    puts "第一个面的顶点坐标:"
    face1.vertices.each_with_index do |vertex, index|
      puts "  顶点#{index}: (#{vertex.position.x}, #{vertex.position.y}, #{vertex.position.z})"
    end
  end
  
  # 创建第二个胶带面（与第一个相邻）
  face2_vertices = [
    Geom::Point3d.new(0, 2, 0),      # 与face1共享边界
    Geom::Point3d.new(10, 2, 0),     # 与face1共享边界
    Geom::Point3d.new(10, 4, 0),
    Geom::Point3d.new(0, 4, 0)
  ]
  
  face2 = parent_group.entities.add_face(face2_vertices)
  puts "创建第二个胶带面: #{face2 ? '成功' : '失败'}"
  
  if face2
    puts "第二个面的边界框: 最小点(#{face2.bounds.min.x}, #{face2.bounds.min.y}, #{face2.bounds.min.z})"
    puts "第二个面的边界框: 最大点(#{face2.bounds.max.x}, #{face2.bounds.max.y}, #{face2.bounds.max.z})"
    puts "第二个面的法线: #{face2.normal.to_s}"
    
    # 验证顶点坐标
    puts "第二个面的顶点坐标:"
    face2.vertices.each_with_index do |vertex, index|
      puts "  顶点#{index}: (#{vertex.position.x}, #{vertex.position.y}, #{vertex.position.z})"
    end
    
    # 如果法线指向下方，反转面
    if face2.normal.z < 0
      puts "第二个面法线指向下方，正在反转..."
      face2.reverse!
      puts "反转后法线: #{face2.normal.to_s}"
    end
  end
  
  # 测试边界框相交检测
  puts "\n测试边界框相交检测:"
  if face1 && face2
    bounds1 = face1.bounds
    bounds2 = face2.bounds
    
    # 手动测试边界框相交
    intersects = !(bounds1.max.x < bounds2.min.x || 
                   bounds1.min.x > bounds2.max.x ||
                   bounds1.max.y < bounds2.min.y || 
                   bounds1.min.y > bounds2.max.y ||
                   bounds1.max.z < bounds2.min.z || 
                   bounds1.min.z > bounds2.max.z)
    
    puts "边界框是否相交: #{intersects}"
    
    # 测试扩展边界框
    tolerance = 0.1
    expanded_bounds1 = Geom::BoundingBox.new
    expanded_bounds1.add(Geom::Point3d.new(
      bounds1.min.x - tolerance,
      bounds1.min.y - tolerance,
      bounds1.min.z - tolerance
    ))
    expanded_bounds1.add(Geom::Point3d.new(
      bounds1.max.x + tolerance,
      bounds1.max.y + tolerance,
      bounds1.max.z + tolerance
    ))
    
    puts "扩展后的边界框1: 最小点(#{expanded_bounds1.min.x}, #{expanded_bounds1.min.y}, #{expanded_bounds1.min.z})"
    puts "扩展后的边界框1: 最大点(#{expanded_bounds1.max.x}, #{expanded_bounds1.max.y}, #{expanded_bounds1.max.z})"
    
    # 测试扩展边界框与第二个面的相交
    expanded_intersects = !(expanded_bounds1.max.x < bounds2.min.x || 
                           expanded_bounds1.min.x > bounds2.max.x ||
                           expanded_bounds1.max.y < bounds2.min.y || 
                           expanded_bounds1.min.y > bounds2.max.y ||
                           expanded_bounds1.max.z < bounds2.min.z || 
                           expanded_bounds1.min.z > bounds2.max.z)
    
    puts "扩展边界框是否与第二个面相交: #{expanded_intersects}"
  end
  
  # 测试相邻面检测
  puts "\n测试相邻面检测:"
  adjacent_faces = TapeBuilder::TapeElevator.send(:find_adjacent_faces, face2, parent_group)
  puts "检测到 #{adjacent_faces.length} 个相邻面"
  
  # 详细分析相邻面
  if !adjacent_faces.empty?
    puts "\n详细分析相邻面:"
    adjacent_faces.each_with_index do |adj_face, index|
      puts "相邻面#{index}:"
      puts "  边界框: 最小点(#{adj_face.bounds.min.x}, #{adj_face.bounds.min.y}, #{adj_face.bounds.min.z})"
      puts "  边界框: 最大点(#{adj_face.bounds.max.x}, #{adj_face.bounds.max.y}, #{adj_face.bounds.max.z})"
      puts "  法线: #{adj_face.normal.to_s}"
      puts "  顶点坐标:"
      adj_face.vertices.each_with_index do |vertex, v_index|
        puts "    顶点#{v_index}: (#{vertex.position.x}, #{vertex.position.y}, #{vertex.position.z})"
      end
    end
  end
  
  # 测试拉高操作
  puts "\n测试拉高操作:"
  result = TapeBuilder::TapeElevator.elevate_tape(face2, 0.05, 0.3, parent_group)
  
  if result
    puts "拉高操作成功，返回 #{result.is_a?(Array) ? result.length : 1} 个面"
  else
    puts "拉高操作失败"
  end
  
  model.commit_operation
  
rescue => e
  puts "测试过程中出错: #{e.message}"
  puts "错误堆栈: #{e.backtrace.join("\n")}"
  model.abort_operation
end

puts "\n测试完成！" 