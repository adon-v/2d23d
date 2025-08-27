# 防止重复加载导致的常量重定义警告
if defined?(TapeBuilder::Builder)
  puts "TapeBuilder模块已加载，跳过重复加载"
else
  # 先加载常量定义，确保常量在使用前已定义
  require 'sketchup.rb' # 添加SketchUp API依赖
  require_relative 'tape_constants'
  require_relative 'tape_utils'
  require_relative 'tape_builder_core'
  require_relative 'tape_conflict_detector'
  require_relative 'tape_face_creator'
  require_relative 'tape_elevator'
  require_relative 'tape_material_applier'
  require_relative 'tape_connection_handler'
  require_relative 'tape_builder'

  module TapeBuilder
    # 初始化方法，供主程序调用
    def self.init
      register_menu
      puts "TapeBuilder模块已初始化"
    end
    
    # 注册菜单方法
    def self.register_menu
      # 使用SketchUp内置的菜单常量，适应不同语言版本
      menu = UI.menu("Extensions") # 英文版使用"Extensions"
      
      # 如果Extensions菜单不存在，尝试使用Plugins或插件
      if !menu
        menu_names = ["Plugins", "插件", "拡張機能", "Erweiterungen", "Extensions"]
        menu_names.each do |name|
          begin
            menu = UI.menu(name)
            break if menu
          rescue
            next
          end
        end
      end
      
      # 如果仍然找不到菜单，使用Tools菜单作为后备选项
      menu ||= UI.menu("Tools")
      
      submenu = menu.add_submenu("胶带生成")
      
      
      # 添加胶带颜色测试菜单项
      submenu.add_item("测试胶带颜色") {
        require_relative 'test_tape_builder'
        TapeBuilderTest.run_all_tests
      }
      
      # 添加其他功能菜单项
      submenu.add_item("从选择创建") {
        # 获取当前选择
        model = Sketchup.active_model
        selection = model.selection
        
        if selection.empty?
          UI.messagebox("请先选择一个面，然后运行此命令")
          return
        end
        
        # 获取选中的面
        selected_face = selection.find { |entity| entity.is_a?(Sketchup::Face) }
        
        if !selected_face
          UI.messagebox("请选择一个面，而不是其他类型的实体")
          return
        end
        
        # 创建父组
        parent_group = model.active_entities.add_group
        
        # 从面的边界提取点
        edges = selected_face.outer_loop.edges
        zone_points = edges.map { |edge| edge.start.position.to_a }
        
        # 生成胶带
        Builder.generate_zone_tape(zone_points, parent_group)
        
        puts "已为选中的面生成胶带"
      }
    end
    
    # 测试胶带生成
    def self.test_tape_generation
      puts "=== 开始测试胶带生成 ==="
      
      # 获取当前模型
      model = Sketchup.active_model
      
      # 创建父组
      parent_group = model.active_entities.add_group
      
      # 测试区域点
      zone_points = [
        [0, 0, 0],
        [5, 0, 0],
        [5, 5, 0],
        [0, 5, 0]
      ]
      
      puts "调试：开始生成胶带..."
      
      # 生成胶带
      Builder.generate_zone_tape(zone_points, parent_group)
      
      puts "调试：胶带生成完成"
      puts "调试：结果组ID: #{parent_group.entityID}"
      
      parent_group
    end
    
    # 从区域数据生成胶带
    def self.generate_tape_from_zone_data(zone_data, parent_group = nil)
      # 如果未提供父组，则创建一个新的
      parent_group ||= Sketchup.active_model.active_entities.add_group
      
      # 提取区域点
      if zone_data.is_a?(Hash) && zone_data["shape"] && zone_data["shape"]["points"]
        zone_points = zone_data["shape"]["points"]
        
        # 生成胶带
        Builder.generate_zone_tape(zone_points, parent_group)
      else
        puts "错误：区域数据格式不正确"
      end
      
      parent_group
    end
    
    # 添加菜单项
    unless file_loaded?(__FILE__)
      register_menu
      file_loaded(__FILE__)
    end
  end
end

# 如果直接运行此文件，则执行测试
if __FILE__ == $0
  TapeBuilder.test_tape_generation
end 