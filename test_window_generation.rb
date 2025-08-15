#!/usr/bin/env ruby
# 窗户生成测试文件

require_relative 'lib/core'
require_relative 'lib/utils'
require_relative 'lib/window_builder'

# 初始化SketchUp环境
Core.check_sketchup_version
Core.setup_encoding

# 测试数据
test_wall_data = {
  "id" => "test_wall_01",
  "start" => [0, 0],
  "end" => [10, 0],
  "thickness" => 200,
  "height" => 3000,
  "name" => "测试墙体"
}

# 测试窗户数据 - position+size格式
test_window_data_1 = {
  "id" => "W01",
  "position" => [5, 0],
  "size" => [2000, 1500],
  "height" => 1200,
  "name" => "测试窗户1",
  "description" => "position+size格式窗户"
}

# 测试窗户数据 - size数组格式
test_window_data_2 = {
  "id" => "W02",
  "size" => [[2, 0], [4, 0]],
  "height" => 1000,
  "name" => "测试窗户2",
  "description" => "size数组格式窗户"
}

# 创建测试墙体
def create_test_wall(wall_data)
  model = Sketchup.active_model
  wall_group = model.entities.add_group
  wall_group.name = "Wall-#{wall_data['id']}"
  
  start_point = Utils.validate_and_create_point(wall_data["start"])
  end_point = Utils.validate_and_create_point(wall_data["end"])
  thickness = Utils.parse_number(wall_data["thickness"]) * 0.001
  height = Utils.parse_number(wall_data["height"]) * 0.001
  
  # 创建墙体
  wall_vector = end_point - start_point
  wall_normal = wall_vector.cross(Geom::Vector3d.new(0, 0, 1)).normalize
  
  # 墙体底部四个点
  points_bottom = [
    start_point,
    end_point,
    end_point + wall_normal * thickness,
    start_point + wall_normal * thickness
  ]
  
  # 墙体顶部四个点
  points_top = points_bottom.map { |p| p + Geom::Vector3d.new(0, 0, height) }
  
  # 创建墙体六个面
  faces = []
  
  # 前面
  front_points = [points_bottom[0], points_bottom[1], points_top[1], points_top[0]]
  faces << wall_group.entities.add_face(front_points)
  
  # 后面
  back_points = [points_bottom[2], points_bottom[3], points_top[3], points_top[2]]
  faces << wall_group.entities.add_face(back_points)
  
  # 左面
  left_points = [points_bottom[0], points_bottom[3], points_top[3], points_top[0]]
  faces << wall_group.entities.add_face(left_points)
  
  # 右面
  right_points = [points_bottom[1], points_bottom[2], points_top[2], points_top[1]]
  faces << wall_group.entities.add_face(right_points)
  
  # 顶面
  top_points = [points_top[0], points_top[1], points_top[2], points_top[3]]
  faces << wall_group.entities.add_face(top_points)
  
  # 底面
  bottom_points = [points_bottom[0], points_bottom[1], points_bottom[2], points_bottom[3]]
  faces << wall_group.entities.add_face(bottom_points)
  
  # 设置墙体材质
  faces.each do |face|
    face.material = [128, 128, 128] unless face.deleted?
  end
  
  wall_group
end

# 运行测试
def run_window_test
  model = Sketchup.active_model
  model.start_operation("窗户生成测试", true)
  
  # 创建主组
  main_group = model.entities.add_group
  main_group.name = "窗户测试"
  
  # 创建测试墙体
  wall_group = create_test_wall(test_wall_data)
  wall_group.move!(Geom::Transformation.new([0, 0, 0]))
  
  # 准备窗户数据
  window_data_list = [
    {
      window_data: test_window_data_1,
      wall_data: test_wall_data,
      parent_group: main_group
    },
    {
      window_data: test_window_data_2,
      wall_data: test_wall_data,
      parent_group: main_group
    }
  ]
  
  # 创建窗户
  puts "开始创建测试窗户..."
  WindowBuilder.create_all_windows(window_data_list, main_group)
  
  model.commit_operation
  puts "窗户生成测试完成！"
end

# 执行测试
if __FILE__ == $0
  run_window_test
end 