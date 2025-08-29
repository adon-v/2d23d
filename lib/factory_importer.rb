# 工厂导入主模块：处理工厂布局导入的主要逻辑
require 'json'
require_relative 'coordinate_processor'

# TapeBuilder现在通过主插件的统一加载机制加载，不需要在这里单独加载
# 注释掉旧的加载代码
# begin
#   require_relative 'TapeBuilder/main'
#   puts "新胶带系统加载成功"
# rescue => e
#   puts "警告：新胶带系统加载失败: #{e.message}"
# end

module FactoryImporter
  # 导入工厂布局
  def self.import_factory_layout
    filter = "JSON文件 (*.json)|*.json|所有文件 (*.*)|*.*||"
    file_path = UI.openpanel("选择工厂布局文件", "", filter)
    
    return if file_path.nil?
    
    begin
      json_data = File.read(file_path)
      layout_data = JSON.parse(json_data)
      
      # 检查是否是有效的工厂布局文件
      unless layout_data["site"]
        UI.messagebox("无效的工厂布局文件: 缺少site属性")
        return
      end
      
      # 应用坐标预处理，将整个工厂模型平移到第一象限
      puts "开始坐标预处理..."
      layout_data = CoordinateProcessor.process_factory_coordinates(layout_data)
      puts "坐标预处理完成"
      
      # 添加调试信息：检查窗户数据是否被修改
      puts "=== 调试：检查坐标预处理后的窗户数据 ==="
      layout_data["site"]["factories"].each do |factory|
        walls = factory["walls"] || factory.dig("structures", "walls") || []
        walls.each do |wall|
          windows = wall["windows"] || []
          windows.each do |window|
            puts "窗户ID: #{window['id']}, size: #{window['size'].inspect}"
          end
        end
      end
      
      model = Sketchup.active_model
      model.start_operation("导入工厂布局", true)
      
      # 初始化实体存储器（独立功能，不影响主流程）
      begin
        EntityStorage.init
        puts "实体存储器初始化成功"
      rescue => e
        puts "警告: 实体存储器初始化失败，继续执行主流程: #{e.message}"
      end

      # 初始化新胶带系统
      begin
        if defined?(TapeBuilder)
          TapeBuilder.init
          puts "新胶带系统初始化成功"
        end
      rescue => e
        puts "警告: 新胶带系统初始化失败，继续执行主流程: #{e.message}"
      end
      
      main_group = model.entities.add_group
      main_group.name = layout_data["site"]["name"] || "工厂布局"
      
      factories_data = layout_data["site"]["factories"]
      factories_data = [factories_data] unless factories_data.is_a?(Array)
      
      import_factory(factories_data, main_group,main_group)
      
      # 获取所有zones
      all_zones = []
      all_walls = []
      factories_data.each do |f|
        zs = f["zones"]
        ws = f["walls"]
        all_zones.concat(zs) if zs.is_a?(Array)
        all_walls.concat(ws) if ws.is_a?(Array)
      end
      
      # 基于工厂size生成大地面，不再依赖围墙和区域数据
      if defined?(ZoneBuilder.generate_factory_ground_from_size)
        puts "【地面生成】开始基于工厂size生成大地面..."
        ZoneBuilder.generate_factory_ground_from_size(main_group, factories_data)
      else
        puts "【警告】ZoneBuilder.generate_factory_ground_from_size 方法未定义"
        # 回退到原来的方法
        if defined?(ZoneBuilder.generate_factory_total_ground)
          puts "【地面生成】回退到原方法：基于区域和墙体生成地面..."
          ZoneBuilder.generate_factory_total_ground(main_group, all_zones, all_walls)
        end
      end
      
      # 区域着色仍然需要区域数据
      if defined?(ZoneBuilder.generate_zones_floor)
        puts "【区域着色】开始生成区域地面着色..."
        ZoneBuilder.generate_zones_floor(main_group, all_zones)
      else
        puts "【警告】ZoneBuilder.generate_zones_floor 方法未定义"
      end
      
      model.commit_operation
      
      # 导入完成后刷新实体存储器菜单
      begin
        if defined?(EntityStorage)
          EntityStorage.refresh_storage_menu
          puts "实体存储器菜单已刷新"
        end
      rescue => e
        puts "警告: 刷新实体存储器菜单失败: #{e.message}"
      end
      
      UI.messagebox("工厂布局导入成功!")
      
    rescue JSON::ParserError => e
      model.abort_operation if defined?(model) && model
      UI.messagebox("JSON解析错误: #{e.message}")
      puts Utils.ensure_utf8("JSON解析错误: #{e.message}")
    rescue Exception => e
      model.abort_operation if defined?(model) && model
      UI.messagebox("导入过程中出错: #{e.message}")
      puts Utils.ensure_utf8("导入错误: #{e.message}")
    end
  end
  
  # 导入工厂数据
  # 这里加一个main_group的传参，方便防止组件在最基础的组上
  def self.import_factory(factories_data, parent_group,main_group)
    # 用于暂存所有门和窗户数据
    all_door_data = []
    all_window_data = []
    
    factories_data.each do |factory_data|
      begin
        factory_group = parent_group.entities.add_group
        factory_group.name = factory_data["id"] || "工厂"
        
        # 1. 先导入所有墙体
        walls_data = fetch_walls_data(factory_data)
        WallBuilder.import_walls(walls_data, factory_group) if walls_data
        
        # 2. 再创建内部墙体
        zones_data = factory_data["zones"] || []
        # 2.1 导入外部区域及围墙
        zones_out_factory_data = factory_data.dig("structures", "outdoor_appendix_zone") || []
        # zone可能要经常地进行增删改查，将其直接放到main_group或许好点？
        ZoneBuilder.import_zones_out_factory(zones_out_factory_data, main_group) if defined?(ZoneBuilder.import_zones_out_factory)
        # 3. 导入其他结构（除了门）
        column_data = factory_data.dig("structures", "columns") || []
        puts "1"
        puts column_data
        object_data = factory_data.dig("structures", "objects") || []
        StructureBuilder.import_columns(column_data || [], factory_group) if defined?(StructureBuilder.import_columns)
        ZoneBuilder.import_zones(zones_data, factory_group)
        #StructureBuilder.import_corridors(factory_data["flows"] || [], factory_group) if defined?(StructureBuilder.import_corridors)
        StructureBuilder.import_objects(object_data || [], factory_group) if defined?(StructureBuilder.import_objects)
        
        # 4. 暂存门和窗户数据（不立即创建）
        # 收集墙体上的门
        if walls_data.is_a?(Array)
          walls_data.each do |wall_data|
            # 收集门数据
            if wall_data.key?('doors') && !wall_data['doors'].empty?
              wall_data['doors'].each do |door_data|
                all_door_data << {
                  door_data: door_data,
                  wall_data: wall_data,
                  parent_group: factory_group
                }
              end
            end
            
            # 收集窗户数据
            if wall_data.key?('windows') && !wall_data['windows'].empty?
              wall_data['windows'].each do |window_data|
                all_window_data << {
                  window_data: window_data,
                  wall_data: wall_data,
                  parent_group: factory_group
                }
              end
            end
          end
        end
        
        # 收集工厂门
        factory_doors = factory_data["factory_doors"] || []
        factory_doors.each do |door_data|
          all_door_data << {
            door_data: door_data,
            parent_group: factory_group
          }
        end
        
        # 收集工厂窗户
        factory_windows = factory_data["factory_windows"] || []
        factory_windows.each do |window_data|
          all_window_data << {
            window_data: window_data,
            parent_group: factory_group
          }
        end
        
        # 导入flow通道
        if factory_data["flows"] && !factory_data["flows"].empty?
          FlowBuilder.import_flows(factory_data["flows"], factory_group)
        end
        
        # 导入设备 - 位于Schema中Factory的Equipments属性
        if factory_data["Equipments"] && !factory_data["Equipments"].empty?
          puts "发现设备数据，开始导入..."
          # 设备的父组不应该是factory_group,而应该是main_group,不然无法对其进行增删改查
          EquipmentBuilder.import_equipments(factory_data["Equipments"], main_group)
        else
          puts "未找到设备数据"
        end
        
      rescue => e
        error_msg = "工厂导入警告: #{Utils.ensure_utf8(e.message)}"
        puts Utils.ensure_utf8(error_msg)
      end
    end
    
    # 5. 所有墙体创建完成后，统一创建门和窗户（核心滞后逻辑）
    DoorBuilder.create_all_doors(all_door_data, parent_group)
    WindowBuilder.create_all_windows(all_window_data, parent_group)
  end
  
  # 获取墙体数据
  def self.fetch_walls_data(factory_data)
    if factory_data.key?('structures') && factory_data['structures'].key?('walls')
      return factory_data['structures']['walls']
    elsif factory_data.key?('walls')
      return factory_data['walls']
    else
      puts "警告: 未找到墙体数据"
      return []
    end
  end
end 