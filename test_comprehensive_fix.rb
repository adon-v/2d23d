#!/usr/bin/env ruby

# 全面测试窗户构建器修复
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

puts "开始全面测试窗户构建器修复..."

# 测试用例1：正常窗户
puts "\n=== 测试用例1：正常窗户 ==="
window_data1 = {
  "id" => "test_window_1",
  "position" => [1000, 2000],
  "size" => [800, 1200],
  "height" => 1500
}

wall_data1 = {
  "start" => [0, 0, 0],
  "end" => [5000, 0, 0],
  "thickness" => 200
}

puts "测试数据1:"
puts "  窗户数据: #{window_data1.inspect}"
puts "  墙体数据: #{wall_data1.inspect}"

window_info1 = WindowBuilder.parse_window_data(window_data1)
if window_info1
  puts "解析成功"
  adjusted_info1 = WindowBuilder.adjust_window_position_for_wall(window_info1, wall_data1)
  if adjusted_info1
    puts "调整成功"
  else
    puts "调整失败"
  end
else
  puts "解析失败"
end

# 测试用例2：大窗户
puts "\n=== 测试用例2：大窗户 ==="
window_data2 = {
  "id" => "test_window_2",
  "position" => [125042, 4890.13],
  "size" => [101549.9656318155, 1200],
  "height" => 1200
}

wall_data2 = {
  "start" => [221521, 187840, 0],
  "end" => [6761080, 187840, 0],
  "thickness" => 200
}

puts "测试数据2:"
puts "  窗户数据: #{window_data2.inspect}"
puts "  墙体数据: #{wall_data2.inspect}"

window_info2 = WindowBuilder.parse_window_data(window_data2)
if window_info2
  puts "解析成功"
  adjusted_info2 = WindowBuilder.adjust_window_position_for_wall(window_info2, wall_data2)
  if adjusted_info2
    puts "调整成功"
  else
    puts "调整失败"
  end
else
  puts "解析失败"
end

# 测试用例3：小窗户
puts "\n=== 测试用例3：小窗户 ==="
window_data3 = {
  "id" => "test_window_3",
  "position" => [500, 1000],
  "size" => [100, 50],
  "height" => 800
}

wall_data3 = {
  "start" => [0, 0, 0],
  "end" => [1000, 0, 0],
  "thickness" => 150
}

puts "测试数据3:"
puts "  窗户数据: #{window_data3.inspect}"
puts "  墙体数据: #{wall_data3.inspect}"

window_info3 = WindowBuilder.parse_window_data(window_data3)
if window_info3
  puts "解析成功"
  adjusted_info3 = WindowBuilder.adjust_window_position_for_wall(window_info3, wall_data3)
  if adjusted_info3
    puts "调整成功"
  else
    puts "调整失败"
  end
else
  puts "解析失败"
end

puts "\n全面测试完成！" 