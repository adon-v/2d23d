# TapeBuilder 模块入口文件
# 这个文件现在只作为模块的入口点，具体的实现逻辑已经拆分到各个专门的类中

require_relative 'tape_constants'
require_relative 'tape_utils'
require_relative 'tape_builder_core'
require_relative 'tape_conflict_detector'
require_relative 'tape_face_creator'
require_relative 'tape_elevator'
require_relative 'tape_material_applier'
require_relative 'tape_connection_handler'

module TapeBuilder
  # 为了保持向后兼容性，这里重新导出主要的类
  Builder = TapeBuilder::Builder
  
  # 版本信息
  VERSION = '2.0.0'
  
  # 模块初始化方法
  def self.init
    puts "TapeBuilder 模块 v#{VERSION} 已加载"
    puts "模块已拆分为以下组件："
    puts "  - tape_builder_core.rb: 核心胶带生成逻辑"
    puts "  - tape_conflict_detector.rb: 冲突检测逻辑"
    puts "  - tape_face_creator.rb: 胶带面创建逻辑"
    puts "  - tape_elevator.rb: 胶带拉高逻辑"
    puts "  - tape_material_applier.rb: 材质应用逻辑"
    puts "  - tape_connection_handler.rb: 胶带连接处理逻辑"
  end
end

# 自动初始化模块
TapeBuilder.init 