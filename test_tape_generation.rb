# 简单胶带生成测试
# 用于验证修复后的胶带生成是否正常工作

require 'sketchup.rb'

# 加载必要的模块
load File.join(File.dirname(__FILE__), 'lib', 'tape_builder.rb')
load File.join(File.dirname(__FILE__), 'lib', 'utils.rb')

def test_simple_tape_generation
  puts "=== 简单胶带生成测试 ==="
  
  # 创建测试组
  model = Sketchup.active_model
  test_group = model.entities.add_group
  test_group.name = "简单胶带测试组"
  
  # 创建一个简单的矩形区域
  puts "\n--- 测试简单矩形区域 ---"
  rectangle_points = [
    Geom::Point3d.new(0, 0, 0),
    Geom::Point3d.new(100, 0, 0),
    Geom::Point3d.new(100, 50, 0),
    Geom::Point3d.new(0, 50, 0)
  ]
  
  begin
    result = TapeBuilder.generate_tape_by_offset_subtraction(
      rectangle_points, 
      "测试矩形", 
      test_group, 
      nil, 
      false
    )
    
    if result
      puts "✓ 矩形区域胶带生成成功"
    else
      puts "✗ 矩形区域胶带生成失败"
    end
  rescue => e
    puts "✗ 矩形区域胶带生成异常: #{e.message}"
    puts e.backtrace.join("\n")
  end
  
  # 创建一个简单的三角形区域
  puts "\n--- 测试简单三角形区域 ---"
  triangle_points = [
    Geom::Point3d.new(200, 0, 0),
    Geom::Point3d.new(300, 0, 0),
    Geom::Point3d.new(250, 50, 0)
  ]
  
  begin
    result = TapeBuilder.generate_tape_by_offset_subtraction(
      triangle_points, 
      "测试三角形", 
      test_group, 
      nil, 
      false
    )
    
    if result
      puts "✓ 三角形区域胶带生成成功"
    else
      puts "✗ 三角形区域胶带生成失败"
    end
  rescue => e
    puts "✗ 三角形区域胶带生成异常: #{e.message}"
    puts e.backtrace.join("\n")
  end
  
  puts "\n=== 测试完成 ==="
  puts "请检查是否生成了黄色的胶带"
end

# 运行测试
test_simple_tape_generation 