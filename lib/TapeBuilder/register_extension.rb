require 'sketchup.rb'

module TapeBuilder
  # 注册扩展 - 已禁用，现在作为主插件的一部分
  # 除非 file_loaded?(__FILE__)
  #   # 创建扩展对象
  #   extension = SketchupExtension.new('胶带生成工具', 'TapeBuilder/main.rb')
  #   extension.version = '1.0.0'
  #   extension.description = '在SketchUp中创建区域边界胶带标识的工具'
  #   extension.creator = '惠工云'
  #   
  #   # 注册扩展
  #   Sketchup.register_extension(extension, true)
  #   
  #   # 创建菜单
  #   if extension.loaded?
  #     menu = UI.menu("插件")
  #     submenu = menu.add_submenu("胶带生成工具")
  #     
  #     # 添加测试菜单项
  #     submenu.add_item("生成测试胶带") {
  #       load 'E:/惠工云/2d23d/2d23d/lib/TapeBuilder/test_tape_builder.rb'
  #     }
  #     
  #     # 添加其他功能菜单项
  #     submenu.add_item("生成区域胶带") {
  #       model = Sketchup.active_model
  #       parent_group = model.active_entities.add_group
  #       
  #       # 提示用户输入区域点
  #       UI.messagebox("请在模型中创建一个多边形区域，然后运行此命令")
  #       
  #       # 这里可以添加更多交互逻辑，例如让用户选择区域
  #       # 简单示例：使用测试区域点
  #       zone_points = [
  #         [0, 0, 0],
  #         [5, 0, 0],
  #         [5, 5, 0],
  #         [0, 5, 0]
  #       ]
  #       
  #       TapeBuilder::Builder.generate_zone_tape(zone_points, parent_group)
  #     }
  #   end
  #   
  #   file_loaded(__FILE__)
  # end
  
  # 现在作为主插件的一部分，提供初始化方法
  def self.init_extension
    puts "TapeBuilder扩展已作为主插件的一部分加载"
    
    # 创建菜单
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
    
    submenu = menu.add_submenu("胶带生成工具")
    
    # 添加测试菜单项
    submenu.add_item("生成测试胶带") {
      # 这里可以添加测试胶带的逻辑
      UI.messagebox("测试胶带功能已集成到主插件中")
    }
    
    # 添加其他功能菜单项
    submenu.add_item("生成区域胶带") {
      model = Sketchup.active_model
      parent_group = model.active_entities.add_group
      
      # 提示用户输入区域点
      UI.messagebox("请在模型中创建一个多边形区域，然后运行此命令")
      
      # 这里可以添加更多交互逻辑，例如让用户选择区域
      # 简单示例：使用测试区域点
      zone_points = [
        [0, 0, 0],
        [5, 0, 0],
        [5, 5, 0],
        [0, 5, 0]
      ]
      
      # 调用TapeBuilder的生成方法
      if defined?(TapeBuilder::Builder) && TapeBuilder::Builder.respond_to?(:generate_zone_tape)
        TapeBuilder::Builder.generate_zone_tape(zone_points, parent_group)
      else
        UI.messagebox("TapeBuilder模块未完全加载，请检查插件状态")
      end
    }
    
    puts "TapeBuilder菜单已创建"
  end
end 