#!/usr/bin/env ruby
# 实体存储器修复测试工具

# 测试实体唯一性
def test_entity_uniqueness
  model = Sketchup.active_model
  
  # 检查实体存储器状态
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 获取所有实体
  all_entities = EntityStorage.get_all_entities
  
  if all_entities.empty?
    UI.messagebox("当前没有存储的实体")
    return
  end
  
  # 分析实体唯一性
  analysis_result = "=== 实体唯一性分析 ===\n\n"
  analysis_result += "总实体数量: #{all_entities.length}\n\n"
  
  # 按类型分组分析
  type_groups = {}
  all_entities.each do |entity_record|
    type = entity_record[:type]
    type_groups[type] ||= []
    type_groups[type] << entity_record
  end
  
  type_groups.each do |type, entities|
    analysis_result += "#{EntityStorage.get_type_display_name(type)} (#{type}):\n"
    analysis_result += "  数量: #{entities.length}\n"
    
    # 检查名称唯一性
    names = entities.map { |e| e[:name] }
    unique_names = names.uniq
    duplicate_names = names.select { |name| names.count(name) > 1 }.uniq
    
    if duplicate_names.empty?
      analysis_result += "  ✅ 所有实体名称唯一\n"
    else
      analysis_result += "  ❌ 发现重复名称: #{duplicate_names.join(', ')}\n"
    end
    
    # 检查ID唯一性
    ids = entities.map { |e| e[:entity_id] }
    unique_ids = ids.uniq
    
    if unique_ids.length == ids.length
      analysis_result += "  ✅ 所有实体ID唯一\n"
    else
      analysis_result += "  ❌ 发现重复ID\n"
    end
    
    # 显示前几个实体的详细信息
    analysis_result += "  实体列表:\n"
    entities.first(5).each do |entity_record|
      analysis_result += "    - #{entity_record[:name]} (ID: #{entity_record[:entity_id]})\n"
    end
    
    if entities.length > 5
      analysis_result += "    ... 还有 #{entities.length - 5} 个实体\n"
    end
    
    analysis_result += "\n"
  end
  
  UI.messagebox(analysis_result)
end

# 测试实体选择功能
def test_entity_selection
  model = Sketchup.active_model
  
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 获取墙体实体进行测试
  wall_entities = EntityStorage.get_entities_by_type("wall")
  
  if wall_entities.empty?
    UI.messagebox("当前没有墙体实体")
    return
  end
  
  # 创建选择测试菜单
  test_menu = UI.menu("Extensions").add_submenu("实体选择测试")
  
  wall_entities.each_with_index do |entity_record, index|
    entity_name = entity_record[:name]
    test_menu.add_item("#{index + 1}. #{entity_name}") {
      begin
        # 清除当前选择
        model.selection.clear
        
        # 选择指定实体
        entity = entity_record[:entity]
        if entity && entity.valid?
          model.selection.add(entity)
          model.active_view.zoom(entity)
          UI.messagebox("已选择: #{entity_name}")
        else
          UI.messagebox("实体已失效: #{entity_name}")
        end
      rescue => e
        UI.messagebox("选择失败: #{e.message}")
      end
    }
  end
  
  UI.messagebox("已创建实体选择测试菜单\n\n请使用 Extensions → 实体选择测试 来选择不同的墙体")
end

# 测试批量选择功能
def test_batch_selection
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 创建批量选择测试菜单
  batch_menu = UI.menu("Extensions").add_submenu("批量选择测试")
  
  # 为每种实体类型创建批量选择测试
  EntityStorage::ENTITY_TYPES.each do |key, type|
    display_name = EntityStorage.get_type_display_name(type)
    entities = EntityStorage.get_entities_by_type(type)
    
    if entities.any?
      batch_menu.add_item("选择所有 #{display_name} (#{entities.length}个)") {
        EntityStorage.select_all_entities_by_type(type)
      }
      
      batch_menu.add_item("添加所有 #{display_name} 到选择") {
        EntityStorage.add_all_entities_by_type_to_selection(type)
      }
    else
      batch_menu.add_item("#{display_name} (无实体)") {
        UI.messagebox("#{display_name} 暂无实体")
      }
    end
  end
  
  UI.messagebox("已创建批量选择测试菜单\n\n请使用 Extensions → 批量选择测试 来测试批量选择功能")
end

# 测试实体属性
def test_entity_attributes
  model = Sketchup.active_model
  selection = model.selection
  
  if selection.empty?
    UI.messagebox("请先选择要测试的实体")
    return
  end
  
  analysis_result = "=== 实体属性分析 ===\n\n"
  
  selection.each_with_index do |entity, index|
    analysis_result += "实体 #{index + 1}:\n"
    analysis_result += "  类型: #{entity.class.name}\n"
    analysis_result += "  名称: #{entity.name rescue '无名称'}\n"
    analysis_result += "  实体ID: #{entity.entityID}\n"
    analysis_result += "  GUID: #{entity.guid}\n"
    
    # 检查自定义属性
    if entity.respond_to?(:get_attribute)
      analysis_result += "  自定义属性:\n"
      
      # 检查常见的属性
      common_attrs = ['id', 'wall_id', 'equipment_id', 'zone_id', 'flow_id', 'name']
      common_attrs.each do |attr|
        value = entity.get_attribute('FactoryImporter', attr)
        if value
          analysis_result += "    #{attr}: #{value}\n"
        end
      end
    end
    
    analysis_result += "\n"
  end
  
  UI.messagebox(analysis_result)
end

# 测试实体过滤功能
def test_entity_filtering
  if !defined?(EntityStorage)
    UI.messagebox("实体存储器模块未加载")
    return
  end
  
  # 创建过滤测试菜单
  filter_menu = UI.menu("Extensions").add_submenu("实体过滤测试")
  
  # 测试选择墙体时的过滤
  filter_menu.add_item("测试选择墙体（过滤窗户）") {
    wall_entities = EntityStorage.get_entities_by_type("wall")
    if wall_entities.any?
      # 选择第一个墙体
      EntityStorage.select_entity_in_sketchup(wall_entities.first)
      UI.messagebox("已选择墙体，请检查是否自动选中了窗户")
    else
      UI.messagebox("当前没有墙体实体")
    end
  }
  
  # 测试批量选择墙体时的过滤
  filter_menu.add_item("测试批量选择墙体（过滤窗户）") {
    EntityStorage.select_all_entities_by_type("wall")
  }
  
  # 测试选择窗户时的过滤
  filter_menu.add_item("测试选择窗户（过滤墙体）") {
    window_entities = EntityStorage.get_entities_by_type("window")
    if window_entities.any?
      # 选择第一个窗户
      EntityStorage.select_entity_in_sketchup(window_entities.first)
      UI.messagebox("已选择窗户，请检查是否自动选中了墙体")
    else
      UI.messagebox("当前没有窗户实体")
    end
  }
  
  # 测试混合选择
  filter_menu.add_item("测试混合选择（墙体+窗户）") {
    model = Sketchup.active_model
    selection = model.selection
    
    # 先选择一些墙体
    wall_entities = EntityStorage.get_entities_by_type("wall")
    if wall_entities.any?
      EntityStorage.select_entity_in_sketchup(wall_entities.first)
      
      # 再添加窗户
      window_entities = EntityStorage.get_entities_by_type("window")
      if window_entities.any?
        EntityStorage.add_all_entities_by_type_to_selection("window")
        UI.messagebox("已进行混合选择，请检查选择结果")
      end
    else
      UI.messagebox("当前没有墙体实体")
    end
  }
  
  UI.messagebox("已创建实体过滤测试菜单\n\n请使用 Extensions → 实体过滤测试 来测试过滤功能")
end

# 创建测试菜单
def create_test_menu
  menu = UI.menu("Extensions").add_submenu("实体存储器测试")
  
  menu.add_item(UI::Command.new("测试实体唯一性") { test_entity_uniqueness })
  menu.add_item(UI::Command.new("测试实体选择") { test_entity_selection })
  menu.add_item(UI::Command.new("测试批量选择") { test_batch_selection })
  menu.add_item(UI::Command.new("测试实体属性") { test_entity_attributes })
  menu.add_item(UI::Command.new("测试实体过滤") { test_entity_filtering })
  
  puts "实体存储器测试菜单创建成功"
end

# 初始化
create_test_menu
puts "实体存储器修复测试工具加载完成" 