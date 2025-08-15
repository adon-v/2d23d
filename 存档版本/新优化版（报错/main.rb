#!/usr/bin/env ruby
# 工厂布局导入插件 - 墙体垂直优化版 v21
# 主入口文件 - 重构版本

require_relative 'lib/core'
require_relative 'lib/ui_manager'
require_relative 'lib/factory_importer'
require_relative 'lib/wall_builder'
require_relative 'lib/door_builder'
require_relative 'lib/window_builder'
require_relative 'lib/tape_builder'
require_relative 'lib/zone_builder'
require_relative 'lib/structure_builder'
require_relative 'lib/flow_builder'
require_relative 'lib/utils'
require_relative 'lib/equipment_builder'
require_relative 'lib/error_handler'
require_relative 'lib/config_manager'
require_relative 'lib/feature_tester'
require_relative 'lib/geometry_optimizer'

# 插件管理器：负责模块的独立初始化和错误隔离
module PluginManager
  @initialized_modules = []
  @failed_modules = []
  
  # 模块配置
  MODULES = {
    core: {
      name: 'Core',
      required: true,
      dependencies: []
    },
    ui_manager: {
      name: 'UIManager', 
      required: true,
      dependencies: [:core]
    },
    factory_importer: {
      name: 'FactoryImporter',
      required: true,
      dependencies: [:core, :ui_manager]
    },
    wall_builder: {
      name: 'WallBuilder',
      required: false,
      dependencies: [:core]
    },
    door_builder: {
      name: 'DoorBuilder',
      required: false,
      dependencies: [:core, :wall_builder]
    },
    window_builder: {
      name: 'WindowBuilder',
      required: false,
      dependencies: [:core, :wall_builder]
    },
    zone_builder: {
      name: 'ZoneBuilder',
      required: false,
      dependencies: [:core]
    },
    structure_builder: {
      name: 'StructureBuilder',
      required: false,
      dependencies: [:core]
    },
    flow_builder: {
      name: 'FlowBuilder',
      required: false,
      dependencies: [:core]
    },
    equipment_builder: {
      name: 'EquipmentBuilder',
      required: false,
      dependencies: [:core]
    },
    tape_builder: {
      name: 'TapeBuilder',
      required: false,
      dependencies: [:core]
    },
    geometry_optimizer: {
      name: 'GeometryOptimizer',
      required: false,
      dependencies: [:core]
    }
  }
  
  # 初始化所有模块
  def self.init_all
    puts "=== 开始初始化工厂布局导入插件 ==="
    
    # 按依赖顺序初始化模块
    MODULES.each do |module_key, config|
      init_module(module_key, config)
    end
    
    # 输出初始化结果
    report_initialization_status
    
    # 运行功能独立性测试
    FeatureTester.test_all_features
    
    puts "=== 插件初始化完成 ==="
  end
  
  # 初始化单个模块
  def self.init_module(module_key, config)
    module_name = config[:name]
    
    # 检查功能是否启用
    unless ConfigManager.feature_enabled?(module_key) || config[:required]
      puts "⚠️  #{module_name} 模块已禁用，跳过初始化"
      return true
    end
    
    # 检查依赖
    unless dependencies_satisfied?(config[:dependencies])
      error_msg = "模块 #{module_name} 的依赖未满足: #{config[:dependencies].join(', ')}"
      puts "❌ #{error_msg}"
      @failed_modules << { module: module_key, error: error_msg }
      return false
    end
    
    # 尝试初始化模块
    begin
      case module_key
      when :core
        Core.check_sketchup_version
        Core.setup_encoding
        Core.log_environment_info
      when :ui_manager
        UIManager.create_menu
        UIManager.create_toolbar
      when :factory_importer
        # FactoryImporter 不需要特殊初始化
        puts "✅ #{module_name} 模块就绪"
      when :wall_builder, :door_builder, :window_builder, :zone_builder, 
           :structure_builder, :flow_builder, :equipment_builder, :tape_builder
        # 这些模块不需要特殊初始化，只需要确保类已加载
        puts "✅ #{module_name} 模块就绪"
      end
      
      @initialized_modules << module_key
      puts "✅ #{module_name} 模块初始化成功"
      return true
      
    rescue => e
      error_msg = "模块 #{module_name} 初始化失败: #{Utils.ensure_utf8(e.message)}"
      puts "❌ #{error_msg}"
      
      if config[:required]
        @failed_modules << { module: module_key, error: error_msg }
        return false
      else
        puts "⚠️  #{module_name} 模块初始化失败，但非必需，继续运行"
        return true
      end
    end
  end
  
  # 检查依赖是否满足
  def self.dependencies_satisfied?(dependencies)
    dependencies.all? { |dep| @initialized_modules.include?(dep) }
  end
  
  # 报告初始化状态
  def self.report_initialization_status
    puts "\n=== 初始化状态报告 ==="
    puts "成功初始化的模块 (#{@initialized_modules.size}):"
    @initialized_modules.each do |module_key|
      puts "  ✅ #{MODULES[module_key][:name]}"
    end
    
    if @failed_modules.any?
      puts "\n初始化失败的模块 (#{@failed_modules.size}):"
      @failed_modules.each do |failed|
        module_name = MODULES[failed[:module]][:name]
        puts "  ❌ #{module_name}: #{failed[:error]}"
      end
    end
    
    # 检查核心功能是否可用
    core_available = @initialized_modules.include?(:core)
    ui_available = @initialized_modules.include?(:ui_manager)
    factory_available = @initialized_modules.include?(:factory_importer)
    
    if core_available && ui_available && factory_available
      puts "\n🎉 核心功能可用，插件可以正常使用"
    else
      puts "\n⚠️  部分核心功能不可用，插件功能可能受限"
    end
  end
  
  # 检查模块是否可用
  def self.module_available?(module_key)
    @initialized_modules.include?(module_key)
  end
  
  # 获取可用模块列表
  def self.available_modules
    @initialized_modules.dup
  end
  
  # 获取失败模块列表
  def self.failed_modules
    @failed_modules.dup
  end
end

# 初始化插件
PluginManager.init_all 