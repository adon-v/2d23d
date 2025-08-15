#!/usr/bin/env ruby

# 测试真实窗户创建过程
require_relative 'lib/window_builder'
require_relative 'lib/utils'

# 模拟SketchUp环境
module Geom
  class Point3d
    attr_accessor :x, :y, :z
    
    def initialize(x, y, z)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end
    
    def -(other)
      Vector3d.new(@x - other.x, @y - other.y, @z - other.z)
    end
    
    def +(other)
      if other.is_a?(Vector3d)
        Point3d.new(@x + other.x, @y + other.y, @z + other.z)
      else
        Point3d.new(@x + other.x, @y + other.y, @z + other.z)
      end
    end
    
    def dot(other)
      @x * other.x + @y * other.y + @z * other.z
    end
    
    def inspect
      "Point3d(#{@x}, #{@y}, #{@z})"
    end
  end
  
  class Vector3d
    attr_accessor :x, :y, :z
    
    def initialize(x, y, z)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end
    
    def length
      Math.sqrt(@x**2 + @y**2 + @z**2)
    end
    
    def normalize
      len = length
      return Vector3d.new(0, 0, 0) if len == 0
      Vector3d.new(@x / len, @y / len, @z / len)
    end
    
    def cross(other)
      Vector3d.new(
        @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
      )
    end
    
    def *(scalar)
      Vector3d.new(@x * scalar, @y * scalar, @z * scalar)
    end
    
    def clone
      Vector3d.new(@x, @y, @z)
    end
    
    def dot(other)
      @x * other.x + @y * other.y + @z * other.z
    end
    
    def inspect
      "Vector3d(#{@x}, #{@y}, #{@z})"
    end
  end
end

# 模拟Sketchup模块
module Sketchup
  def self.active_model
    nil
  end
end

puts "开始测试真实窗户创建过程..."

# 使用实际的错误数据
window_data = {
  "id" => "e58e0c1c-6816-44d6-8aa3-8458c80ab689",
  "position" => [125042, 4890.13],  # 毫米
  "size" => [101549.9656318155, 1200],  # 宽度和高度（毫米）
  "height" => 1200  # 中心点高度（毫米）
}

wall_data = {
  "start" => [221521, 187840, 0],  # 毫米
  "end" => [6761080, 187840, 0],   # 毫米
  "thickness" => 200               # 毫米
}

puts "测试数据:"
puts "  窗户数据: #{window_data.inspect}"
puts "  墙体数据: #{wall_data.inspect}"

# 测试parse_window_data方法
puts "\n=== 测试parse_window_data方法 ==="
window_info = WindowBuilder.parse_window_data(window_data)
if window_info
  puts "解析成功:"
  puts "  start_point: #{window_info[:start_point].inspect}"
  puts "  end_point: #{window_info[:end_point].inspect}"
  puts "  height: #{window_info[:height]}"
  puts "  width: #{window_info[:width]}"
  puts "  position: #{window_info[:position].inspect}"
else
  puts "解析失败"
end

# 测试adjust_window_position_for_wall方法
if window_info
  puts "\n=== 测试adjust_window_position_for_wall方法 ==="
  adjusted_info = WindowBuilder.adjust_window_position_for_wall(window_info, wall_data)
  if adjusted_info
    puts "调整成功:"
    puts "  start_point: #{adjusted_info[:start_point].inspect}"
    puts "  end_point: #{adjusted_info[:end_point].inspect}"
  else
    puts "调整失败"
  end
end

# 测试project_point_to_wall方法
if window_info
  puts "\n=== 测试project_point_to_wall方法 ==="
  wall_start = Utils.validate_and_create_point(wall_data["start"])
  wall_end = Utils.validate_and_create_point(wall_data["end"])
  position = window_info[:position]
  
  projected_point = WindowBuilder.project_point_to_wall(position, wall_start, wall_end)
  puts "投影成功:"
  puts "  原始点: #{position.inspect}"
  puts "  投影点: #{projected_point.inspect}"
end

# 测试calculate_window_wall_points方法
if window_info
  puts "\n=== 测试calculate_window_wall_points方法 ==="
  start_point = window_info[:start_point]
  end_point = window_info[:end_point]
  wall_thickness = 7.874  # 200mm = 7.874英寸
  
  wall_points = WindowBuilder.calculate_window_wall_points(start_point, end_point, wall_thickness)
  if wall_points && !wall_points.empty?
    puts "计算成功，墙面四点:"
    wall_points.each_with_index do |point, i|
      puts "  点#{i+1}: #{point.inspect}"
    end
    
    # 验证所有点都是Point3d对象
    all_valid = wall_points.all? { |p| p.is_a?(Geom::Point3d) }
    puts "所有点都是Point3d对象: #{all_valid}"
  else
    puts "计算失败"
  end
end

puts "\n测试完成！" 