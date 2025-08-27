# 胶带生成器测试脚本
# 用于测试胶带颜色是否正确应用

require 'sketchup.rb'
require_relative 'tape_constants'
require_relative 'tape_utils'
require_relative 'tape_builder'

module TapeBuilderTest
  # 测试胶带颜色应用
  def self.test_tape_color
    puts "=== 开始测试胶带颜色应用 ==="
    
    # 获取当前模型
    model = Sketchup.active_model
    
    # 检查材质管理器
    puts "调试：检查材质管理器"
    puts "调试：材质数量: #{model.materials.length}"
    puts "调试：现有材质: #{model.materials.map(&:name).join(', ')}"
    
    # 检查胶带常量
    puts "调试：胶带颜色常量: #{TapeBuilder::TAPE_COLOR.inspect}"
    puts "调试：胶带宽度: #{TapeBuilder::TAPE_WIDTH}"
    puts "调试：胶带高度: #{TapeBuilder::TAPE_HEIGHT}"
    
    # 创建父组
    parent_group = model.active_entities.add_group
    puts "调试：创建父组: #{parent_group.entityID}"
    
    # 测试区域点
    zone_points = [
      [0, 0, 0],
      [3, 0, 0],
      [3, 3, 0],
      [0, 3, 0]
    ]
    
    puts "调试：开始生成胶带..."
    
    # 生成胶带
    Builder.generate_zone_tape(zone_points, parent_group)
    
    puts "调试：胶带生成完成"
    
    # 检查生成的胶带面
    tape_faces = []
    parent_group.entities.each do |entity|
      if entity.is_a?(Sketchup::Face) && entity.material && entity.material.name == "Tape"
        tape_faces << entity
      end
    end
    
    puts "调试：找到 #{tape_faces.length} 个胶带面"
    
    # 检查每个胶带面的材质
    tape_faces.each_with_index do |face, index|
      puts "调试：胶带面 #{index + 1}:"
      puts "调试：  实体ID: #{face.entityID}"
      puts "调试：  材质名称: #{face.material ? face.material.name : 'nil'}"
      puts "调试：  材质颜色: #{face.material ? face.material.color.inspect : 'nil'}"
      puts "调试：  材质有效性: #{face.material ? face.material.valid? : 'nil'}"
      puts "调试：  面有效性: #{face.valid?}"
      puts "调试：  顶点数: #{face.vertices.length}"
    end
    
    # 检查材质库中的胶带材质
    tape_material = model.materials["Tape"]
    if tape_material
      puts "调试：材质库中的胶带材质:"
      puts "调试：  名称: #{tape_material.name}"
      puts "调试：  颜色: #{tape_material.color.inspect}"
      puts "调试：  有效性: #{tape_material.valid?}"
      puts "调试：  使用颜色: #{tape_material.use_color}"
      puts "调试：  透明度: #{tape_material.alpha}"
    else
      puts "警告：材质库中未找到胶带材质"
    end
    
    puts "=== 胶带颜色测试完成 ==="
    
    # 返回父组以便进一步检查
    parent_group
  end

  # 测试立方体材质应用
  def self.test_cube_material_application
    puts "=== 开始测试立方体材质应用 ==="
    
    # 获取当前模型
    model = Sketchup.active_model
    
    # 创建父组
    parent_group = model.active_entities.add_group
    puts "调试：创建父组: #{parent_group.entityID}"
    
    # 测试区域点
    zone_points = [
      [0, 0, 0],
      [2, 0, 0],
      [2, 2, 0],
      [0, 2, 0]
    ]
    
    puts "调试：开始生成胶带立方体..."
    
    # 生成胶带
    Builder.generate_zone_tape(zone_points, parent_group)
    
    puts "调试：胶带立方体生成完成"
    
    # 统计所有面
    all_faces = []
    parent_group.entities.each do |entity|
      if entity.is_a?(Sketchup::Face)
        all_faces << entity
      end
    end
    
    puts "调试：父组中共有 #{all_faces.length} 个面"
    
    # 分类面
    tape_faces = []
    uncolored_faces = []
    
    all_faces.each do |face|
      if face.material && face.material.name == "Tape"
        tape_faces << face
      else
        uncolored_faces << face
      end
    end
    
    puts "调试：有材质的胶带面: #{tape_faces.length} 个"
    puts "调试：无材质的其他面: #{uncolored_faces.length} 个"
    
    # 检查每个面的详细信息
    puts "\n=== 胶带面详情 ==="
    tape_faces.each_with_index do |face, index|
      puts "胶带面 #{index + 1}:"
      puts "  实体ID: #{face.entityID}"
      puts "  材质名称: #{face.material.name}"
      puts "  材质颜色: #{face.material.color.inspect}"
      puts "  顶点数: #{face.vertices.length}"
      puts "  边数: #{face.edges.length}"
      puts "  法线: #{face.normal.inspect}"
    end
    
    if uncolored_faces.length > 0
      puts "\n=== 无材质面详情 ==="
      uncolored_faces.each_with_index do |face, index|
        puts "无材质面 #{index + 1}:"
        puts "  实体ID: #{face.entityID}"
        puts "  材质: #{face.material ? face.material.name : 'nil'}"
        puts "  顶点数: #{face.vertices.length}"
        puts "  边数: #{face.edges.length}"
        puts "  法线: #{face.normal.inspect}"
      end
    end
    
    puts "\n=== 立方体材质应用测试完成 ==="
    
    # 返回父组以便进一步检查
    parent_group
  end

  # 测试材质创建
  def self.test_material_creation
    puts "=== 开始测试材质创建 ==="
    
    # 获取当前模型
    model = Sketchup.active_model
    
    # 检查现有材质
    puts "调试：现有材质数量: #{model.materials.length}"
    puts "调试：现有材质名称: #{model.materials.map(&:name).join(', ')}"
    
    # 尝试创建胶带材质
    begin
      tape_material = model.materials.add("TestTape")
      tape_material.color = Sketchup::Color.new(255, 255, 0)  # 黄色
      tape_material.alpha = 1.0
      tape_material.texture = nil
      tape_material.colorize_type = 0
      
      puts "调试：测试材质创建成功"
      puts "调试：材质名称: #{tape_material.name}"
      puts "调试：材质颜色: #{tape_material.color.inspect}"
      puts "调试：材质有效性: #{tape_material.valid?}"
      
      # 清理测试材质
      model.materials.remove(tape_material)
      puts "调试：测试材质已清理"
      
    rescue => e
      puts "测试材质创建失败: #{e.message}"
    end
    
    puts "=== 材质创建测试完成 ==="
  end

  # 运行所有测试
  def self.run_all_tests
    puts "=== 开始运行所有测试 ==="
    
    # 测试1：材质创建
    test_material_creation
    
    # 测试2：胶带颜色应用
    test_tape_color
    
    # 测试3：立方体材质应用
    test_cube_material_application
    
    puts "=== 所有测试完成 ==="
  end
end

# 如果直接运行此文件，则执行测试
if __FILE__ == $0
  TapeBuilderTest.run_all_tests
end 