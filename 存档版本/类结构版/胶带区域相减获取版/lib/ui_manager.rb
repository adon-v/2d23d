# UI管理模块：处理菜单和工具栏创建
module UIManager
  # 创建菜单
  def self.create_menu
    begin
      plugin_menu = UI.menu("Extensions")
      
      cmd = UI::Command.new("导入工厂布局") {
        FactoryImporter.import_factory_layout
      }
      cmd.small_icon = "C:\Users\fyang\Desktop\1.jpg"
      cmd.large_icon = "C:\Users\fyang\Desktop\1.jpg"
      cmd.tooltip = "从JSON文件导入工厂布局(包含设备)"
      cmd.status_bar_text = "导入工厂布局及设备"
      
      plugin_menu.add_item(cmd)
      
      # 添加实体存储器菜单（独立功能）
      begin
        # 优先尝试简化版实体存储器（兼容性更好）
        if defined?(EntityStorageSimple)
          EntityStorageSimple.create_simple_menu
          puts "简化版实体存储器菜单创建成功"
        elsif defined?(EntityStorage)
          EntityStorage.create_storage_menu
          puts "标准版实体存储器菜单创建成功"
        else
          puts "实体存储器模块未加载，跳过菜单创建"
        end
      rescue => e
        puts "警告: 创建实体存储器菜单失败，不影响主功能: #{e.message}"
        puts "建议使用简化版实体存储器以提高兼容性"
      end
      
      # 添加材质管理器菜单（独立功能）
      begin
        if defined?(MaterialManager)
          MaterialManager.init
          puts "材质管理器菜单创建成功"
        else
          puts "材质管理器模块未加载，跳过菜单创建"
        end
      rescue => e
        puts "警告: 创建材质管理器菜单失败，不影响主功能: #{e.message}"
      end
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