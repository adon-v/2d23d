# 胶带修复测试文件
# 用于验证修复后的胶带生成逻辑是否正确处理闭合问题

require 'sketchup.rb'
require 'extensions.rb'

# 加载必要的模块
load File.join(File.dirname(__FILE__), 'lib', 'tape_builder.rb')
load File.join(File.dirname(__FILE__), 'lib', 'utils.rb')

# 测试胶带生成修复
def test_tape_generation_fix
  puts "=== 胶带生成修复测试 ==="
  
  # 创建测试组
  model = Sketchup.active_model
  test_group = model.entities.add_group
  test_group.name = "胶带修复测试组"
  
  # 测试用例1：简单的矩形区域
  puts "\n--- 测试用例1：简单矩形区域 ---"
  simple_rectangle_points = [
    Geom::Point3d.new(0, 0, 0),
    Geom::Point3d.new(100, 0, 0),
    Geom::Point3d.new(100, 50, 0),
    Geom::Point3d.new(0, 50, 0)
  ]
  
  begin
    TapeBuilder.generate_tape_by_offset_subtraction(
      simple_rectangle_points, 
      "测试矩形区域", 
      test_group, 
      nil, 
      false
    )
    puts "✓ 简单矩形区域胶带生成成功"
  rescue => e
    puts "✗ 简单矩形区域胶带生成失败: #{e.message}"
  end
  
  # 测试用例2：复杂多边形区域
  puts "\n--- 测试用例2：复杂多边形区域 ---"
  complex_polygon_points = [
    Geom::Point3d.new(200, 0, 0),
    Geom::Point3d.new(300, 0, 0),
    Geom::Point3d.new(350, 50, 0),
    Geom::Point3d.new(300, 100, 0),
    Geom::Point3d.new(200, 100, 0),
    Geom::Point3d.new(150, 50, 0)
  ]
  
  begin
    TapeBuilder.generate_tape_by_offset_subtraction(
      complex_polygon_points, 
      "测试复杂多边形区域", 
      test_group, 
      nil, 
      false
    )
    puts "✓ 复杂多边形区域胶带生成成功"
  rescue => e
    puts "✗ 复杂多边形区域胶带生成失败: #{e.message}"
  end
  
  # 测试用例3：可能导致闭合问题的区域
  puts "\n--- 测试用例3：可能导致闭合问题的区域 ---"
  problematic_points = [
    Geom::Point3d.new(400, 0, 0),
    Geom::Point3d.new(450, 0, 0),
    Geom::Point3d.new(450, 10, 0),  # 很窄的区域
    Geom::Point3d.new(400, 10, 0)
  ]
  
  begin
    TapeBuilder.generate_tape_by_offset_subtraction(
      problematic_points, 
      "测试问题区域", 
      test_group, 
      nil, 
      false
    )
    puts "✓ 问题区域胶带生成成功（应该被跳过或生成有瑕疵的胶带）"
  rescue => e
    puts "✗ 问题区域胶带生成失败: #{e.message}"
  end
  
  puts "\n=== 测试完成 ==="
  puts "请检查生成的胶带是否正确保持环状结构，而不是完全覆盖区域"
end

# 运行测试
test_tape_generation_fix 