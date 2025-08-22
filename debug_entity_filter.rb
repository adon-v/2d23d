#!/usr/bin/env ruby
# 实体过滤调试工具

# 调试实体过滤功能
def debug_entity_filter
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  model = Sketchup.active_model
  
  # 获取所有实体信息
  wall_entities = EntityStorage.get_entities_by_type("wall")
  window_entities = EntityStorage.get_entities_by_type("window")
  
  debug_info = "=== 实体过滤调试信息 ===\n\n"
  debug_info += "墙体实体数量: #{wall_entities.length}\n"
  debug_info += "窗户实体数量: #{window_entities.length}\n\n"
  
  # 显示墙体信息
  debug_info += "墙体实体:\n"
  wall_entities.each_with_index do |record, index|
    debug_info += "  #{index + 1}. #{record[:name]} (ID: #{record[:entity_id]})\n"
  end
  
  debug_info += "\n窗户实体:\n"
  window_entities.each_with_index do |record, index|
    debug_info += "  #{index + 1}. #{record[:name]} (ID: #{record[:entity_id]})\n"
  end
  
  UI.messagebox(debug_info)
end

# 测试选择墙体时的过滤
def test_wall_selection_filter
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  wall_entities = EntityStorage.get_entities_by_type("wall")
  
  if wall_entities.empty?
    UI.messagebox("当前没有墙体实体")
    return
  end
  
  # 选择第一个墙体
  model = Sketchup.active_model
  selection = model.selection
  
  # 清空选择
  selection.clear
  
  # 选择墙体
  wall_entity = wall_entities.first
  selection.add(wall_entity[:entity])
  
  # 显示选择前的信息
  before_info = "选择前:\n"
  before_info += "选中实体数量: #{selection.length}\n"
  before_info += "选中实体ID: #{selection.map(&:entityID).inspect}\n"
  
  # 手动调用过滤函数
  EntityStorage.filter_conflicting_entities_from_selection(model, selection, "wall")
  
  # 显示选择后的信息
  after_info = "\n选择后:\n"
  after_info += "选中实体数量: #{selection.length}\n"
  after_info += "选中实体ID: #{selection.map(&:entityID).inspect}\n"
  
  UI.messagebox(before_info + after_info)
end

# 强制过滤测试
def force_filter_test
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  model = Sketchup.active_model
  selection = model.selection
  
  if selection.empty?
    UI.messagebox("请先选择一些实体")
    return
  end
  
  # 显示过滤前信息
  before_info = "过滤前:\n"
  before_info += "选中实体数量: #{selection.length}\n"
  selection.each_with_index do |entity, index|
    before_info += "  #{index + 1}. ID: #{entity.entityID}, 类型: #{entity.class.name}\n"
  end
  
  # 强制过滤窗户
  window_entities = EntityStorage.get_entities_by_type("window")
  window_ids = window_entities.map { |record| record[:entity_id] }
  
  entities_to_remove = []
  selection.each do |entity|
    if window_ids.include?(entity.entityID)
      entities_to_remove << entity
    end
  end
  
  entities_to_remove.each do |entity|
    selection.remove(entity)
  end
  
  # 显示过滤后信息
  after_info = "\n过滤后:\n"
  after_info += "选中实体数量: #{selection.length}\n"
  selection.each_with_index do |entity, index|
    after_info += "  #{index + 1}. ID: #{entity.entityID}, 类型: #{entity.class.name}\n"
  end
  
  after_info += "\n移除的窗户数量: #{entities_to_remove.length}"
  
  UI.messagebox(before_info + after_info)
end

# 测试反选功能
def test_inverse_selection
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  model = Sketchup.active_model
  selection = model.selection
  
  # 清空选择
  selection.clear
  
  # 获取墙体实体
  wall_entities = EntityStorage.get_entities_by_type("wall")
  if wall_entities.empty?
    UI.messagebox("当前没有墙体实体")
    return
  end
  
  # 选择第一个墙体
  wall_entity = wall_entities.first
  selection.add(wall_entity[:entity])
  
  # 显示选择前信息
  before_info = "选择墙体后:\n"
  before_info += "选中实体数量: #{selection.length}\n"
  selection.each_with_index do |entity, index|
    before_info += "  #{index + 1}. ID: #{entity.entityID}, 类型: #{entity.class.name}\n"
    if entity.respond_to?(:get_attribute)
      before_info += "     属性: type=#{entity.get_attribute('FactoryImporter', 'type')}, name=#{entity.get_attribute('FactoryImporter', 'name')}\n"
    end
    if entity.is_a?(Sketchup::Group) && entity.name
      before_info += "     名称: #{entity.name}\n"
    end
  end
  
  # 使用反选功能移除窗户
  EntityStorage.remove_windows_from_selection_using_inverse_selection(model, selection)
  
  # 显示选择后信息
  after_info = "\n反选移除窗户后:\n"
  after_info += "选中实体数量: #{selection.length}\n"
  selection.each_with_index do |entity, index|
    after_info += "  #{index + 1}. ID: #{entity.entityID}, 类型: #{entity.class.name}\n"
    if entity.respond_to?(:get_attribute)
      after_info += "     属性: type=#{entity.get_attribute('FactoryImporter', 'type')}, name=#{entity.get_attribute('FactoryImporter', 'name')}\n"
    end
    if entity.is_a?(Sketchup::Group) && entity.name
      after_info += "     名称: #{entity.name}\n"
    end
  end
  
  UI.messagebox(before_info + after_info)
end

# 详细分析选中实体的属性
def analyze_selected_entities
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  model = Sketchup.active_model
  selection = model.selection
  
  if selection.empty?
    UI.messagebox("请先选择一些实体")
    return
  end
  
  analysis = "选中实体详细分析:\n\n"
  
  selection.each_with_index do |entity, index|
    analysis += "实体 #{index + 1}:\n"
    analysis += "  ID: #{entity.entityID}\n"
    analysis += "  类型: #{entity.class.name}\n"
    
    if entity.respond_to?(:get_attribute)
      analysis += "  自定义属性:\n"
      analysis += "    type: #{entity.get_attribute('FactoryImporter', 'type')}\n"
      analysis += "    name: #{entity.get_attribute('FactoryImporter', 'name')}\n"
      analysis += "    id: #{entity.get_attribute('FactoryImporter', 'id')}\n"
      analysis += "    window_type: #{entity.get_attribute('FactoryImporter', 'window_type')}\n"
      analysis += "    window_name: #{entity.get_attribute('FactoryImporter', 'window_name')}\n"
      analysis += "    window_id: #{entity.get_attribute('FactoryImporter', 'window_id')}\n"
    end
    
    if entity.is_a?(Sketchup::Group) && entity.name
      analysis += "  组名称: #{entity.name}\n"
      # 检查是否包含窗户相关关键词
      name_lower = entity.name.downcase
      if name_lower.include?("窗户") || name_lower.include?("window")
        analysis += "  ⚠️  检测到窗户关键词!\n"
      end
    end
    
    if entity.is_a?(Sketchup::ComponentInstance)
      analysis += "  组件名称: #{entity.name}\n"
      analysis += "  组件定义名称: #{entity.definition.name}\n"
    end
    
    analysis += "\n"
  end
  
  UI.messagebox(analysis)
end

# 测试英文窗户名称识别
def test_english_window_recognition
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  model = Sketchup.active_model
  selection = model.selection
  
  # 清空选择
  selection.clear
  
  # 获取所有窗户实体
  window_entities = EntityStorage.get_entities_by_type("window")
  if window_entities.empty?
    UI.messagebox("当前没有窗户实体")
    return
  end
  
  # 选择前3个窗户实体
  test_count = [3, window_entities.length].min
  test_count.times do |i|
    selection.add(window_entities[i][:entity])
  end
  
  # 显示选择前信息
  before_info = "选择窗户后:\n"
  before_info += "选中实体数量: #{selection.length}\n"
  selection.each_with_index do |entity, index|
    before_info += "  #{index + 1}. ID: #{entity.entityID}, 类型: #{entity.class.name}\n"
    if entity.respond_to?(:get_attribute)
      before_info += "     属性: type=#{entity.get_attribute('FactoryImporter', 'type')}, name=#{entity.get_attribute('FactoryImporter', 'name')}\n"
    end
    if entity.is_a?(Sketchup::Group) && entity.name
      before_info += "     名称: #{entity.name}\n"
    end
  end
  
  # 测试反选功能（应该移除窗户）
  EntityStorage.remove_windows_from_selection_using_inverse_selection(model, selection)
  
  # 显示选择后信息
  after_info = "\n反选移除窗户后:\n"
  after_info += "选中实体数量: #{selection.length}\n"
  if selection.length > 0
    selection.each_with_index do |entity, index|
      after_info += "  #{index + 1}. ID: #{entity.entityID}, 类型: #{entity.class.name}\n"
    end
  else
    after_info += "  ✅ 所有窗户都被正确移除"
  end
  
  UI.messagebox(before_info + after_info)
end

# 检查窗户属性设置
def check_window_attributes
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 获取所有窗户实体
  window_entities = EntityStorage.get_entities_by_type("window")
  if window_entities.empty?
    UI.messagebox("当前没有窗户实体")
    return
  end
  
  analysis = "窗户实体属性分析:\n\n"
  analysis += "窗户实体总数: #{window_entities.length}\n\n"
  
  window_entities.each_with_index do |record, index|
    entity = record[:entity]
    analysis += "窗户 #{index + 1}:\n"
    analysis += "  存储ID: #{record[:entity_id]}\n"
    analysis += "  实体ID: #{entity.entityID}\n"
    analysis += "  类型: #{entity.class.name}\n"
    
    if entity.respond_to?(:get_attribute)
      analysis += "  自定义属性:\n"
      analysis += "    type: #{entity.get_attribute('FactoryImporter', 'type')}\n"
      analysis += "    name: #{entity.get_attribute('FactoryImporter', 'name')}\n"
      analysis += "    window_type: #{entity.get_attribute('FactoryImporter', 'window_type')}\n"
      analysis += "    window_name: #{entity.get_attribute('FactoryImporter', 'window_name')}\n"
      analysis += "    window_id: #{entity.get_attribute('FactoryImporter', 'window_id')}\n"
    end
    
    if entity.is_a?(Sketchup::Group) && entity.name
      analysis += "  组名称: #{entity.name}\n"
    end
    
    analysis += "\n"
  end
  
  UI.messagebox(analysis)
end

# 检查墙体和窗户对应关系
def check_wall_window_mapping
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 获取所有墙体和窗户对应关系
  mappings = EntityStorage.get_all_wall_window_mappings
  if mappings.empty?
    UI.messagebox("当前没有墙体和窗户的对应关系")
    return
  end
  
  analysis = "墙体和窗户对应关系分析:\n\n"
  analysis += "墙体总数: #{mappings.keys.length}\n\n"
  
  mappings.each do |wall_id, windows|
    analysis += "墙体ID: #{wall_id}\n"
    analysis += "  对应窗户数量: #{windows.length}\n"
    
    windows.each_with_index do |window_record, index|
      analysis += "  窗户 #{index + 1}: #{window_record[:name]} (ID: #{window_record[:entity_id]})\n"
    end
    
    analysis += "\n"
  end
  
  # 添加调试信息
  analysis += "调试信息:\n"
  analysis += "墙体实体总数: #{EntityStorage.get_entities_by_type('wall').length}\n"
  analysis += "窗户实体总数: #{EntityStorage.get_entities_by_type('window').length}\n"
  
  UI.messagebox(analysis)
end

# 测试墙体和窗户对应关系反选
def test_wall_window_mapping_selection
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 获取所有墙体
  wall_entities = EntityStorage.get_entities_by_type("wall")
  if wall_entities.empty?
    UI.messagebox("当前没有墙体实体")
    return
  end
  
  # 找到有窗户的墙体
  wall_with_windows = nil
  wall_entities.each do |wall_record|
    wall_id = wall_record[:entity].get_attribute('FactoryImporter', 'wall_id')
    if wall_id
      windows = EntityStorage.get_windows_for_wall(wall_id)
      if windows.length > 0
        wall_with_windows = wall_record
        break
      end
    end
  end
  
  if wall_with_windows.nil?
    UI.messagebox("没有找到包含窗户的墙体")
    return
  end
  
  # 测试选择该墙体
  model = Sketchup.active_model
  selection = model.selection
  
  # 清空选择
  selection.clear
  
  # 选择墙体
  selection.add(wall_with_windows[:entity])
  
  # 显示选择前信息
  before_info = "选择墙体后:\n"
  before_info += "墙体: #{wall_with_windows[:name]}\n"
  before_info += "墙体ID: #{wall_with_windows[:entity].get_attribute('FactoryImporter', 'wall_id')}\n"
  before_info += "选中实体数量: #{selection.length}\n"
  
  # 显示墙体对应的窗户
  wall_id = wall_with_windows[:entity].get_attribute('FactoryImporter', 'wall_id')
  windows = EntityStorage.get_windows_for_wall(wall_id)
  before_info += "墙体对应的窗户数量: #{windows.length}\n"
  windows.each_with_index do |window_record, index|
    before_info += "  窗户 #{index + 1}: #{window_record[:name]} (ID: #{window_record[:entity_id]})\n"
  end
  
  # 显示选中实体的详细信息
  before_info += "\n选中的实体:\n"
  selection.each_with_index do (entity, index|
    before_info += "  实体 #{index + 1}: ID=#{entity.entityID}, 类型=#{entity.class.name}\n"
    if entity.respond_to?(:get_attribute)
      before_info += "    属性: type=#{entity.get_attribute('FactoryImporter', 'type')}, name=#{entity.get_attribute('FactoryImporter', 'name')}\n"
    end
  end
  
  # 使用对应关系反选
  EntityStorage.remove_windows_using_mapping(model, selection, wall_with_windows)
  
  # 显示选择后信息
  after_info = "\n反选移除窗户后:\n"
  after_info += "选中实体数量: #{selection.length}\n"
  
  if selection.length > 0
    after_info += "剩余实体:\n"
    selection.each_with_index do |entity, index|
      after_info += "  实体 #{index + 1}: ID=#{entity.entityID}, 类型=#{entity.class.name}\n"
    end
  end
  
  UI.messagebox(before_info + after_info)
end

# 测试立柱存储功能
def test_column_storage
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 获取所有立柱实体
  column_entities = EntityStorage.get_entities_by_type("column")
  if column_entities.empty?
    UI.messagebox("当前没有立柱实体")
    return
  end
  
  analysis = "立柱实体存储分析:\n\n"
  analysis += "立柱实体总数: #{column_entities.length}\n\n"
  
  column_entities.each_with_index do |record, index|
    entity = record[:entity]
    analysis += "立柱 #{index + 1}:\n"
    analysis += "  存储ID: #{record[:entity_id]}\n"
    analysis += "  实体ID: #{entity.entityID}\n"
    analysis += "  类型: #{entity.class.name}\n"
    
    if entity.respond_to?(:get_attribute)
      analysis += "  自定义属性:\n"
      analysis += "    type: #{entity.get_attribute('FactoryImporter', 'type')}\n"
      analysis += "    name: #{entity.get_attribute('FactoryImporter', 'name')}\n"
      analysis += "    column_id: #{entity.get_attribute('FactoryImporter', 'column_id')}\n"
      analysis += "    column_name: #{entity.get_attribute('FactoryImporter', 'column_name')}\n"
    end
    
    if entity.is_a?(Sketchup::Group) && entity.name
      analysis += "  组名称: #{entity.name}\n"
    end
    
    # 显示元数据
    if record[:metadata] && !record[:metadata].empty?
      analysis += "  元数据:\n"
      record[:metadata].each do |key, value|
        analysis += "    #{key}: #{value}\n"
      end
    end
    
    analysis += "\n"
  end
  
  UI.messagebox(analysis)
end

# 创建调试菜单
def create_debug_menu
  menu = UI.menu("Extensions").add_submenu("实体过滤调试")
  
  menu.add_item(UI::Command.new("调试实体过滤") { debug_entity_filter })
  menu.add_item(UI::Command.new("测试墙体选择过滤") { test_wall_selection_filter })
  menu.add_item(UI::Command.new("强制过滤测试") { force_filter_test })
  menu.add_item(UI::Command.new("测试反选功能") { test_inverse_selection })
  menu.add_item(UI::Command.new("分析选中实体") { analyze_selected_entities })
  menu.add_item(UI::Command.new("测试英文窗户识别") { test_english_window_recognition })
  menu.add_item(UI::Command.new("检查窗户属性") { check_window_attributes })
  menu.add_item(UI::Command.new("检查墙窗对应关系") { check_wall_window_mapping })
  menu.add_item(UI::Command.new("测试墙窗对应反选") { test_wall_window_mapping_selection })
  menu.add_item(UI::Command.new("测试立柱存储") { test_column_storage })
  
  puts "实体过滤调试菜单创建成功"
end

# 初始化
create_debug_menu
puts "实体过滤调试工具加载完成" 