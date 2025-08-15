# 工厂导入主模块：处理工厂布局导入的主要逻辑
require 'json'

module FactoryImporter
  # 导入工厂布局 - 重构版本，支持功能独立化
  def self.import_factory_layout
    # 检查核心模块是否可用
    unless PluginManager.module_available?(:core)
      UI.messagebox("错误: 核心模块未初始化，无法导入工厂布局")
      return
    end
    
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
      
      model = Sketchup.active_model
      model.start_operation("导入工厂布局", true)
      
      main_group = model.entities.add_group
      main_group.name = layout_data["site"]["name"] || "工厂布局"
      
      factories_data = layout_data["site"]["factories"]
      factories_data = [factories_data] unless factories_data.is_a?(Array)
      
      # 使用独立的功能处理器
      processor = FactoryLayoutProcessor.new(main_group)
      success = processor.process_factories(factories_data)
      
      if success
        model.commit_operation
        UI.messagebox("工厂布局导入成功!")
      else
        model.abort_operation
        UI.messagebox("工厂布局导入过程中出现错误，请查看控制台输出")
      end
      
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
  
  # 工厂布局处理器：负责独立处理各个功能模块
  class FactoryLayoutProcessor
    def initialize(main_group)
      @main_group = main_group
      @collected_data = { door_data: [], window_data: [] }
      @processed_factories = []
      @errors = []
    end
    
    # 处理工厂数据
    def process_factories(factories_data)
      puts "=== 开始处理工厂数据 ==="
      
      factories_data.each_with_index do |factory_data, index|
        begin
          puts "处理工厂 #{index + 1}/#{factories_data.size}: #{factory_data['id'] || '未知'}"
          
          factory_group = @main_group.entities.add_group
          factory_group.name = factory_data["id"] || "工厂"
          
          # 独立处理各个功能模块
          process_walls(factory_data, factory_group)
          process_zones(factory_data, factory_group)
          process_structures(factory_data, factory_group)
          process_flows(factory_data, factory_group)
          process_equipments(factory_data)
          
          @processed_factories << factory_group
          
        rescue => e
          error_msg = "处理工厂 #{factory_data['id'] || '未知'} 时出错: #{Utils.ensure_utf8(e.message)}"
          puts "❌ #{error_msg}"
          @errors << error_msg
        end
      end
      
      # 处理收集到的门和窗户数据
      process_doors_and_windows
      
      # 生成地面
      generate_ground(factories_data)
      
      # 几何体优化
      optimize_geometry
      
      # 报告处理结果
      report_processing_result
      
      @errors.empty?
    end
    
    private
    
    # 处理墙体
    def process_walls(factory_data, factory_group)
      return unless PluginManager.module_available?(:wall_builder)
      
      begin
        walls_data = fetch_walls_data(factory_data)
        if walls_data && walls_data.any?
          puts "  📏 处理墙体数据 (#{walls_data.size} 个)"
          WallBuilder.import_walls(walls_data, factory_group)
          
          # 收集门和窗户数据
          collect_doors_and_windows(walls_data, factory_group)
        else
          puts "  ⚠️  未找到墙体数据"
        end
      rescue => e
        error_msg = "处理墙体时出错: #{Utils.ensure_utf8(e.message)}"
        puts "  ❌ #{error_msg}"
        @errors << error_msg
      end
    end
    
    # 处理区域
    def process_zones(factory_data, factory_group)
      return unless PluginManager.module_available?(:zone_builder)
      
      begin
        zones_data = factory_data["zones"] || []
        if zones_data.any?
          puts "  🏢 处理区域数据 (#{zones_data.size} 个)"
          ZoneBuilder.import_zones(zones_data, factory_group)
        end
        
        # 处理外部区域
        zones_out_factory_data = factory_data.dig("structures", "outdoor_appendix_zone") || []
        if zones_out_factory_data.any?
          puts "  🌳 处理外部区域数据 (#{zones_out_factory_data.size} 个)"
          ZoneBuilder.import_zones_out_factory(zones_out_factory_data, @main_group) if defined?(ZoneBuilder.import_zones_out_factory)
        end
      rescue => e
        error_msg = "处理区域时出错: #{Utils.ensure_utf8(e.message)}"
        puts "  ❌ #{error_msg}"
        @errors << error_msg
      end
    end
    
    # 处理结构
    def process_structures(factory_data, factory_group)
      return unless PluginManager.module_available?(:structure_builder)
      
      begin
        # 处理柱子
        column_data = factory_data.dig("structures", "columns") || []
        if column_data.any?
          puts "  🏗️  处理柱子数据 (#{column_data.size} 个)"
          StructureBuilder.import_columns(column_data, factory_group) if defined?(StructureBuilder.import_columns)
        end
        
        # 处理其他对象
        object_data = factory_data.dig("structures", "objects") || []
        if object_data.any?
          puts "  📦 处理对象数据 (#{object_data.size} 个)"
          StructureBuilder.import_objects(object_data, factory_group) if defined?(StructureBuilder.import_objects)
        end
      rescue => e
        error_msg = "处理结构时出错: #{Utils.ensure_utf8(e.message)}"
        puts "  ❌ #{error_msg}"
        @errors << error_msg
      end
    end
    
    # 处理流程
    def process_flows(factory_data, factory_group)
      return unless PluginManager.module_available?(:flow_builder)
      
      begin
        flows_data = factory_data["flows"] || []
        if flows_data.any?
          puts "  🔄 处理流程数据 (#{flows_data.size} 个)"
          FlowBuilder.import_flows(flows_data, factory_group)
        end
      rescue => e
        error_msg = "处理流程时出错: #{Utils.ensure_utf8(e.message)}"
        puts "  ❌ #{error_msg}"
        @errors << error_msg
      end
    end
    
    # 处理设备
    def process_equipments(factory_data)
      return unless PluginManager.module_available?(:equipment_builder)
      
      begin
        equipments_data = factory_data["Equipments"] || []
        if equipments_data.any?
          puts "  ⚙️  处理设备数据 (#{equipments_data.size} 个)"
          EquipmentBuilder.import_equipments(equipments_data, @main_group)
        else
          puts "  ⚠️  未找到设备数据"
        end
      rescue => e
        error_msg = "处理设备时出错: #{Utils.ensure_utf8(e.message)}"
        puts "  ❌ #{error_msg}"
        @errors << error_msg
      end
    end
    
    # 收集门和窗户数据
    def collect_doors_and_windows(walls_data, factory_group)
      return unless walls_data.is_a?(Array)
      
      walls_data.each do |wall_data|
        # 收集门
        if wall_data.key?('doors') && !wall_data['doors'].empty?
          wall_data['doors'].each do |door_data|
            @collected_data[:door_data] << {
              door_data: door_data,
              wall_data: wall_data,
              parent_group: factory_group
            }
          end
        end
        
        # 收集窗户
        if wall_data.key?('windows') && !wall_data['windows'].empty?
          wall_data['windows'].each do |window_data|
            @collected_data[:window_data] << {
              window_data: window_data,
              wall_data: wall_data,
              parent_group: factory_group
            }
          end
        end
      end
    end
    
    # 处理门和窗户
    def process_doors_and_windows
      # 处理门
      if @collected_data[:door_data].any? && PluginManager.module_available?(:door_builder)
        begin
          puts "🚪 创建门 (#{@collected_data[:door_data].size} 个)"
          DoorBuilder.create_all_doors(@collected_data[:door_data], @main_group)
        rescue => e
          error_msg = "创建门时出错: #{Utils.ensure_utf8(e.message)}"
          puts "❌ #{error_msg}"
          @errors << error_msg
        end
      end
      
      # 处理窗户
      if @collected_data[:window_data].any? && PluginManager.module_available?(:window_builder)
        begin
          puts "🪟 创建窗户 (#{@collected_data[:window_data].size} 个)"
          WindowBuilder.create_all_windows(@collected_data[:window_data], @main_group)
        rescue => e
          error_msg = "创建窗户时出错: #{Utils.ensure_utf8(e.message)}"
          puts "❌ #{error_msg}"
          @errors << error_msg
        end
      end
    end
    
    # 生成地面
    def generate_ground(factories_data)
      return unless PluginManager.module_available?(:zone_builder)
      
      begin
        puts "🌍 生成工厂地面"
        
        if defined?(ZoneBuilder.generate_factory_ground_from_size)
          ZoneBuilder.generate_factory_ground_from_size(@main_group, factories_data)
        elsif defined?(ZoneBuilder.generate_factory_total_ground)
          # 获取所有zones和walls用于回退方法
          all_zones = []
          all_walls = []
          factories_data.each do |f|
            all_zones.concat(f["zones"] || [])
            all_walls.concat(f["walls"] || [])
          end
          ZoneBuilder.generate_factory_total_ground(@main_group, all_zones, all_walls)
        else
          puts "⚠️  地面生成功能不可用"
        end
      rescue => e
        error_msg = "生成地面时出错: #{Utils.ensure_utf8(e.message)}"
        puts "❌ #{error_msg}"
        @errors << error_msg
      end
    end
    
    # 几何体优化
    def optimize_geometry
      return unless PluginManager.module_available?(:geometry_optimizer)
      
      begin
        puts "🔧 开始几何体优化"
        
        # 分析当前几何体状态
        stats = GeometryOptimizer.analyze_geometry(@main_group)
        puts "  当前状态: 实体=#{stats[:total_entities]}, 组件=#{stats[:groups_count]}, 面=#{stats[:faces_count]}"
        
        # 检查是否需要优化
        if GeometryOptimizer.should_optimize?(@main_group)
          puts "  检测到需要优化，开始处理..."
          GeometryOptimizer.optimize_factory_layout(@main_group)
          
          # 优化后的状态
          stats_after = GeometryOptimizer.analyze_geometry(@main_group)
          puts "  优化后状态: 实体=#{stats_after[:total_entities]}, 组件=#{stats_after[:groups_count]}, 面=#{stats_after[:faces_count]}"
          
          # 计算优化效果
          entity_reduction = stats[:total_entities] - stats_after[:total_entities]
          group_reduction = stats[:groups_count] - stats_after[:groups_count]
          face_reduction = stats[:faces_count] - stats_after[:faces_count]
          
          puts "  优化效果: 减少实体=#{entity_reduction}, 减少组件=#{group_reduction}, 减少面=#{face_reduction}"
        else
          puts "  当前几何体状态良好，无需优化"
        end
        
      rescue => e
        error_msg = "几何体优化时出错: #{Utils.ensure_utf8(e.message)}"
        puts "❌ #{error_msg}"
        @errors << error_msg
      end
    end
    
    # 报告处理结果
    def report_processing_result
      puts "\n=== 处理结果报告 ==="
      puts "成功处理的工厂: #{@processed_factories.size} 个"
      puts "收集的门数据: #{@collected_data[:door_data].size} 个"
      puts "收集的窗户数据: #{@collected_data[:window_data].size} 个"
      
      if @errors.any?
        puts "\n处理过程中的错误 (#{@errors.size} 个):"
        @errors.each_with_index do |error, index|
          puts "  #{index + 1}. #{error}"
        end
      else
        puts "\n✅ 所有功能处理完成，无错误"
      end
    end
    
    # 获取墙体数据
    def fetch_walls_data(factory_data)
      if factory_data.key?('structures') && factory_data['structures'].key?('walls')
        return factory_data['structures']['walls']
      elsif factory_data.key?('walls')
        return factory_data['walls']
      else
        return []
      end
    end
  end
  
  # 保留原有的方法以保持向后兼容
  def self.import_factory(factories_data, parent_group, main_group)
    processor = FactoryLayoutProcessor.new(main_group)
    processor.process_factories(factories_data)
  end
  
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
  
  def self.create_windows(window_data_list, parent_group)
    begin
      WindowBuilder.create_all_windows(window_data_list, parent_group)
    rescue => e
      error_msg = "窗户创建失败: #{Utils.ensure_utf8(e.message)}"
      puts Utils.ensure_utf8(error_msg)
      UI.messagebox("窗户创建过程中出错: #{e.message}")
    end
  end
end 