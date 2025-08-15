#!/usr/bin/env ruby
# 工厂布局导入插件 - 墙体垂直优化版 v21
# 主入口文件

require_relative 'lib/core'
require_relative 'lib/ui_manager'
require_relative 'lib/factory_importer'
require_relative 'lib/wall_builder'
require_relative 'lib/door_builder'
require_relative 'lib/tape_builder'
require_relative 'lib/window_builder'
require_relative 'lib/zone_builder'
require_relative 'lib/structure_builder'
require_relative 'lib/flow_builder'
require_relative 'lib/utils'
require_relative 'lib/equipment_builder'

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