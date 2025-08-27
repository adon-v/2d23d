require 'sketchup.rb'

module TapeBuilder
  # 注册扩展
  unless file_loaded?(__FILE__)
    # 创建扩展对象
    extension = SketchupExtension.new('胶带生成工具', 'TapeBuilder/main.rb')
    extension.version = '1.0.0'
    extension.description = '在SketchUp中创建区域边界胶带标识的工具'
    extension.creator = '惠工云'
    
    # 注册扩展
    Sketchup.register_extension(extension, true)
    
    # 创建菜单
    if extension.loaded?
      menu = UI.menu("插件")
      submenu = menu.add_submenu("胶带生成工具")
      
      # 添加测试菜单项
      submenu.add_item("生成测试胶带") {
        load 'E:/惠工云/2d23d/2d23d/lib/TapeBuilder/test_tape_builder.rb'
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
        
        TapeBuilder::Builder.generate_zone_tape(zone_points, parent_group)
      }
    end
    
    file_loaded(__FILE__)
  end
end 