# UI管理模块：处理菜单和工具栏创建
module UIManager
  # 创建菜单
  def self.create_menu
    begin
      plugin_menu = UI.menu("Extensions")
      
      cmd = UI::Command.new("导入工厂布局") {
        # 导入工厂布局
        FactoryImporter.import_factory_layout
      }
      cmd.small_icon = "C:\Users\fyang\Desktop\1.jpg"
      cmd.large_icon = "C:\Users\fyang\Desktop\1.jpg"
      cmd.tooltip = "从JSON文件导入工厂布局(包含设备)"
      cmd.status_bar_text = "导入工厂布局及设备"
      
      plugin_menu.add_item(cmd)
    end
  end
  
  # 创建工具栏
  def self.create_toolbar
    begin
      toolbar = UI::Toolbar.new("工厂布局导入")
      
      cmd = UI::Command.new("导入工厂") {
        FactoryImporter.import_factory_layout
      }
      cmd.small_icon = "C:/Users/fyang/Desktop/1.jpg"
      cmd.large_icon = "C:/Users/fyang/Desktop/1.jpg"
      cmd.tooltip = "从JSON文件导入工厂布局(包含设备、墙体等)"
      cmd.status_bar_text = "导入工厂布局及设备"
      toolbar.add_item(cmd)
      
      toolbar.show
    rescue Exception => e
      error_msg = "创建工具栏时出错: #{Utils.ensure_utf8(e.message)}"
      puts Utils.ensure_utf8(error_msg)
    end
  end
end 