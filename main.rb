#!/usr/bin/env ruby
# 工厂布局导入插件 
# 主入口文件

require_relative 'lib/core'
require_relative 'lib/utils'
require_relative 'lib/ui_manager'
require_relative 'lib/factory_importer'
require_relative 'lib/wall_builder'
require_relative 'lib/door_builder'
require_relative 'lib/tape_builder'
require_relative 'lib/window_builder'
require_relative 'lib/zone_builder'
require_relative 'lib/structure_builder'
require_relative 'lib/flow_builder'
require_relative 'lib/equipment_builder'

# 独立加载实体存储器（可选功能）
begin
  require_relative 'lib/entity_storage'
  puts "实体存储器模块加载成功"
rescue LoadError => e
  puts "警告: 实体存储器模块加载失败，将跳过实体存储功能: #{e.message}"
rescue => e
  puts "警告: 实体存储器模块初始化失败: #{e.message}"
end

# 独立加载材质管理器（可选功能）
begin
  require_relative 'lib/material_manager'
  puts "材质管理器模块加载成功"
rescue LoadError => e
  puts "警告: 材质管理器模块加载失败，将跳过材质管理功能: #{e.message}"
rescue => e
  puts "警告: 材质管理器模块初始化失败: #{e.message}"
end

# 初始化插件
module FactoryImporter
  def self.init
    Core.check_sketchup_version
    Core.setup_encoding
    Core.log_environment_info
    UIManager.create_menu
    UIManager.create_toolbar
  end
end

# 初始化插件
FactoryImporter.init 