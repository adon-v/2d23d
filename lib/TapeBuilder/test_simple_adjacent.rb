require 'C:/Users/caifu/AppData/Roaming/SketchUp/SketchUp 2025/SketchUp/Plugins/lib/TapeBuilder/tape_elevator'

# 创建简化的测试模型
model = Sketchup.active_model
model.start_operation("简化相邻面测试", true)

begin
  # 创建父组
  parent_group = model.active_entities.add_group
  
  # 创建第一个胶带面
  face1_vertices = [
    Geom::Point3d.new(0, 0, 0),
    Geom::Point3d.new(10, 0, 0),
    Geom::Point3d.new(10, 2, 0),
    Geom::Point3d.new(0, 2, 0)
  ]
  
  face1 = parent_group.entities.add_face(face1_vertices)
  puts "创建第一个胶带面: #{face1 ? '成功' : '失败'}"
  
  # 创建第二个胶带面（与第一个相邻）
  face2_vertices = [
    Geom::Point3d.new(0, 2, 0),      # 与face1共享边界
    Geom::Point3d.new(10, 2, 0),     # 与face1共享边界
    Geom::Point3d.new(10, 4, 0),
    Geom::Point3d.new(0, 4, 0)
  ]
  
  face2 = parent_group.entities.add_face(face2_vertices)
  puts "创建第二个胶带面: #{face2 ? '成功' : '失败'}"
  
  # 确保法线朝上
  if face1 && face1.normal.z < 0
    face1.reverse!
    puts "第一个面法线已修正: #{face1.normal.to_s}"
  end
  
  if face2 && face2.normal.z < 0
    face2.reverse!
    puts "第二个面法线已修正: #{face2.normal.to_s}"
  end
  
  # 测试相邻面检测
  puts "\n测试相邻面检测:"
  adjacent_faces = TapeBuilder::TapeElevator.send(:find_adjacent_faces, face2, parent_group)
  puts "检测到 #{adjacent_faces.length} 个相邻面"
  
  # 测试几何冲突检测
  if !adjacent_faces.empty?
    puts "\n测试几何冲突检测:"
    adjacent_faces.each_with_index do |adj_face, index|
      puts "相邻面#{index}:"
      
      # 测试是否真的需要调整
      needs_adjustment = TapeBuilder::TapeElevator.send(:really_needs_adjustment, face2.vertices.map { |v| v.position }, [adj_face])
      puts "  需要调整: #{needs_adjustment}"
      
      if needs_adjustment
        puts "  检测到真正的几何冲突"
      else
        puts "  只是共享边界，无需调整"
      end
    end
  end
  
  # 测试拉高操作（跳过几何调整）
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

puts "\n简化测试完成！" 