# 简化测试脚本 - 验证基本功能
require_relative 'tape_elevator'

puts "开始简化测试..."

# 测试边界框相交检测
puts "\n测试边界框相交检测:"
bounds1 = Geom::BoundingBox.new
bounds1.add(Geom::Point3d.new(0, 0, 0))
bounds1.add(Geom::Point3d.new(10, 2, 0))

bounds2 = Geom::BoundingBox.new
bounds2.add(Geom::Point3d.new(0, 2, 0))
bounds2.add(Geom::Point3d.new(10, 4, 0))

puts "边界框1: 最小(#{bounds1.min.x}, #{bounds1.min.y}, #{bounds1.min.z}) 最大(#{bounds1.max.x}, #{bounds1.max.y}, #{bounds1.max.z})"
puts "边界框2: 最小(#{bounds2.min.x}, #{bounds2.min.y}, #{bounds2.min.z}) 最大(#{bounds2.max.x}, #{bounds2.max.y}, #{bounds2.max.z})"

# 测试相交检测
intersects = TapeBuilder::TapeElevator.send(:bounds_intersect, bounds1, bounds2)
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

puts "扩展边界框1: 最小(#{expanded_bounds1.min.x}, #{expanded_bounds1.min.y}, #{expanded_bounds1.min.z}) 最大(#{expanded_bounds1.max.x}, #{expanded_bounds1.max.y}, #{expanded_bounds1.max.z})"

expanded_intersects = TapeBuilder::TapeElevator.send(:bounds_intersect, expanded_bounds1, bounds2)
puts "扩展边界框是否与边界框2相交: #{expanded_intersects}"

# 测试顶点去重
puts "\n测试顶点去重:"
test_vertices = [
  Geom::Point3d.new(0, 0, 0),
  Geom::Point3d.new(0, 0, 0),  # 重复
  Geom::Point3d.new(10, 0, 0),
  Geom::Point3d.new(10, 0, 0),  # 重复
  Geom::Point3d.new(10, 2, 0),
  Geom::Point3d.new(0, 2, 0)
]

puts "原始顶点数: #{test_vertices.length}"
unique_vertices = TapeBuilder::TapeElevator.send(:remove_duplicate_vertices, test_vertices)
puts "去重后顶点数: #{unique_vertices.length}"

puts "\n简化测试完成！" 