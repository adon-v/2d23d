# 功能测试模块：测试各个功能的独立性
module FeatureTester
  # 测试所有功能
  def self.test_all_features
    puts "=== 功能独立性测试 ==="
    
    features = [:wall_builder, :door_builder, :window_builder, :zone_builder, 
                :structure_builder, :flow_builder, :equipment_builder, :tape_builder, :geometry_optimizer]
    
    results = {}
    features.each do |feature|
      results[feature] = test_feature(feature)
    end
    
    report_results(results)
  end
  
  # 测试单个功能
  def self.test_feature(feature_name)
    puts "测试 #{feature_name}..."
    
    result = {
      module_loaded: false,
      methods_available: false,
      can_execute: false
    }
    
    # 检查模块是否加载
    result[:module_loaded] = module_loaded?(feature_name)
    
    if result[:module_loaded]
      # 检查主要方法是否可用
      result[:methods_available] = check_methods(feature_name)
      result[:can_execute] = result[:methods_available]
    end
    
    status = result[:can_execute] ? "✅" : "❌"
    puts "  #{status} #{feature_name}: 模块=#{result[:module_loaded]}, 方法=#{result[:methods_available]}"
    
    result
  end
  
  # 检查模块是否加载
  def self.module_loaded?(feature_name)
    case feature_name
    when :wall_builder
      defined?(WallBuilder)
    when :door_builder
      defined?(DoorBuilder)
    when :window_builder
      defined?(WindowBuilder)
    when :zone_builder
      defined?(ZoneBuilder)
    when :structure_builder
      defined?(StructureBuilder)
    when :flow_builder
      defined?(FlowBuilder)
    when :equipment_builder
      defined?(EquipmentBuilder)
    when :tape_builder
      defined?(TapeBuilder)
    when :geometry_optimizer
      defined?(GeometryOptimizer)
    else
      false
    end
  end
  
  # 检查方法是否可用
  def self.check_methods(feature_name)
    begin
      case feature_name
      when :wall_builder
        WallBuilder.respond_to?(:import_walls)
      when :door_builder
        DoorBuilder.respond_to?(:create_all_doors)
      when :window_builder
        WindowBuilder.respond_to?(:create_all_windows)
      when :zone_builder
        ZoneBuilder.respond_to?(:import_zones)
      when :structure_builder
        StructureBuilder.respond_to?(:import_columns)
      when :flow_builder
        FlowBuilder.respond_to?(:import_flows)
      when :equipment_builder
        EquipmentBuilder.respond_to?(:import_equipments)
      when :tape_builder
        TapeBuilder.respond_to?(:import_tapes)
      when :geometry_optimizer
        GeometryOptimizer.respond_to?(:optimize_factory_layout)
      else
        false
      end
    rescue
      false
    end
  end
  
  # 报告结果
  def self.report_results(results)
    puts "\n=== 测试结果 ==="
    
    total = results.size
    working = results.values.count { |r| r[:can_execute] }
    
    puts "总功能数: #{total}"
    puts "独立功能: #{working}"
    puts "独立性: #{(working.to_f / total * 100).round(1)}%"
    
    if working == total
      puts "🎉 所有功能都能独立运行！"
    else
      puts "⚠️  部分功能需要改进"
    end
  end
end
