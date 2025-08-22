# 实体存储器：存储和分类所有生成的实体，提供动态菜单和实体选择功能
module EntityStorage
  # 实体类型常量（移除门，因为门是挖出来的，不需要定位）
  ENTITY_TYPES = {
    FACTORY_GROUND: "factory_ground",      # 工厂大地面
    INDOOR_ZONE: "indoor_zone",            # 内部区域
    OUTDOOR_ZONE: "outdoor_zone",          # 外部区域
    WINDOW: "window",                      # 窗户
    WALL: "wall",                          # 墙体
    EQUIPMENT: "equipment",                # 设备
    FLOW: "flow",                          # 流通道
    COLUMN: "column",                      # 立柱
    STRUCTURE: "structure"                 # 其他结构
  }
  
  # 存储所有实体的哈希表
  @@entities = {}
  
  # 实体计数器
  @@entity_counts = {}
  
  # 墙体和窗户的对应关系存储
  @@wall_window_mapping = {}
  
  # 初始化存储器
  def self.init
    @@entities = {}
    @@entity_counts = {}
    @@wall_window_mapping = {}
    
    # 初始化每个类型的存储列表和计数器
    ENTITY_TYPES.each do |key, type|
      @@entities[type] = []
      @@entity_counts[type] = 0
    end
    
    puts "实体存储器已初始化"
  end
  
  # 添加实体到指定类型
  def self.add_entity(entity_type, entity, metadata = {})
    return unless entity && entity.valid?
    
    # 验证实体类型
    unless ENTITY_TYPES.values.include?(entity_type)
      puts "警告: 未知的实体类型 '#{entity_type}'"
      return
    end
    
    # 创建实体记录
    entity_record = {
      entity: entity,
      entity_id: entity.entityID,
      guid: entity.guid,
      name: get_entity_name(entity),
      type: entity_type,
      metadata: metadata,
      created_at: Time.now
    }
    
    # 添加到对应类型列表
    @@entities[entity_type] << entity_record
    @@entity_counts[entity_type] += 1
    
    puts "已存储 #{entity_type} 实体: #{entity_record[:name]}"
    
    # 自动刷新菜单以显示新实体
    begin
      refresh_storage_menu
    rescue => e
      puts "警告: 自动刷新菜单失败: #{e.message}"
    end
  end
  
  # 获取实体名称（包含唯一标识）
  def self.get_entity_name(entity)
    base_name = nil
    
    # 获取基础名称
    if entity.respond_to?(:name) && !entity.name.empty?
      base_name = entity.name
    elsif entity.respond_to?(:get_attribute) && entity.get_attribute('FactoryImporter', 'name')
      base_name = entity.get_attribute('FactoryImporter', 'name')
    else
      base_name = "未命名实体"
    end
    
    # 添加唯一标识符
    unique_id = get_unique_identifier(entity)
    "#{base_name}_#{unique_id}"
  end
  
  # 获取实体的唯一标识符
  def self.get_unique_identifier(entity)
    # 优先使用自定义ID
    if entity.respond_to?(:get_attribute)
      custom_id = entity.get_attribute('FactoryImporter', 'id') ||
                  entity.get_attribute('FactoryImporter', 'wall_id') ||
                  entity.get_attribute('FactoryImporter', 'equipment_id') ||
                  entity.get_attribute('FactoryImporter', 'zone_id') ||
                  entity.get_attribute('FactoryImporter', 'flow_id') ||
                  entity.get_attribute('FactoryImporter', 'column_id')
      
      return custom_id if custom_id
    end
    
    # 使用实体ID作为备选
    entity.entityID.to_s
  end
  
  # 获取指定类型的实体列表
  def self.get_entities_by_type(entity_type)
    @@entities[entity_type] || []
  end
  
  # 添加墙体和窗户的对应关系
  def self.add_wall_window_mapping(wall_id, window_entity_record)
    @@wall_window_mapping[wall_id] ||= []
    @@wall_window_mapping[wall_id] << window_entity_record
    puts "已添加墙体和窗户对应关系: 墙体ID=#{wall_id}, 窗户=#{window_entity_record[:name]}"
  end
  
  # 获取指定墙体对应的所有窗户
  def self.get_windows_for_wall(wall_id)
    @@wall_window_mapping[wall_id] || []
  end
  
  # 获取所有墙体和窗户的对应关系
  def self.get_all_wall_window_mappings
    @@wall_window_mapping
  end
  
  # 获取所有实体
  def self.get_all_entities
    all_entities = []
    @@entities.each do |type, entities|
      all_entities.concat(entities)
    end
    all_entities
  end
  
  # 根据ID查找实体
  def self.find_entity_by_id(entity_id)
    @@entities.each do |type, entities|
      entities.each do |entity_record|
        return entity_record if entity_record[:entity_id] == entity_id
      end
    end
    nil
  end
  
  # 根据GUID查找实体
  def self.find_entity_by_guid(guid)
    @@entities.each do |type, entities|
      entities.each do |entity_record|
        return entity_record if entity_record[:guid] == guid
      end
    end
    nil
  end
  
  # 根据名称查找实体
  def self.find_entities_by_name(name)
    found_entities = []
    @@entities.each do |type, entities|
      entities.each do |entity_record|
        if entity_record[:name].to_s.include?(name.to_s)
          found_entities << entity_record
        end
      end
    end
    found_entities
  end
  
  # 获取统计信息
  def self.get_statistics
    stats = {
      total_entities: 0,
      type_counts: @@entity_counts.clone,
      types: []
    }
    
    @@entities.each do |type, entities|
      stats[:total_entities] += entities.size
      stats[:types] << type if entities.any?
    end
    
    stats
  end
  
  # 获取存储状态
  def self.get_status
    stats = get_statistics
    {
      initialized: !@@entities.empty?,
      total_entities: stats[:total_entities],
      type_counts: stats[:type_counts],
      has_entities: stats[:total_entities] > 0
    }
  end
  
  # 清空指定类型的实体
  def self.clear_entities_by_type(entity_type)
    if @@entities[entity_type]
      @@entities[entity_type].clear
      @@entity_counts[entity_type] = 0
      puts "已清空 #{entity_type} 类型的实体"
      
      # 刷新菜单
      begin
        refresh_storage_menu
      rescue => e
        puts "警告: 刷新菜单失败: #{e.message}"
      end
    end
  end
  
  # 清空所有实体
  def self.clear_all_entities
    @@entities.each do |type, entities|
      entities.clear
      @@entity_counts[type] = 0
    end
    puts "已清空所有实体"
    
    # 刷新菜单
    begin
      refresh_storage_menu
    rescue => e
      puts "警告: 刷新菜单失败: #{e.message}"
    end
  end
  
  # 在SketchUp中选中指定实体
  def self.select_entity_in_sketchup(entity_record)
    return unless entity_record && entity_record[:entity]
    
    model = Sketchup.active_model
    selection = model.selection
    
    # 清空当前选择
    selection.clear
    
    # 选中指定实体
    entity = entity_record[:entity]
    if entity.valid?
      selection.add(entity)
      puts "已选中实体: #{entity_record[:name]}"
      
      # 使用反选方式过滤冲突实体
      if entity_record[:type] == "wall"
        # 特殊处理墙体：使用墙体和窗户对应关系进行反选
        puts "检测到墙体选择，使用墙体和窗户对应关系进行反选..."
        remove_windows_using_mapping(model, selection, entity_record)
      else
        # 其他实体使用常规过滤
        filter_conflicting_entities_from_selection(model, selection, entity_record[:type])
      end
      
      # 强制刷新选择（确保过滤生效）
      model.active_view.invalidate
      
      # 将视图中心对准选中的实体
      model.active_view.zoom(entity)
    else
      puts "警告: 实体已失效，无法选中"
    end
  end
  

  
  # 使用墙体和窗户对应关系进行反选（新方法）
  def self.remove_windows_using_mapping(model, selection, wall_entity_record)
    puts "开始使用墙体和窗户对应关系进行反选..."
    puts "墙体: #{wall_entity_record[:name]}"
    
    # 获取墙体ID
    wall_id = nil
    if wall_entity_record[:entity].respond_to?(:get_attribute)
      wall_id = wall_entity_record[:entity].get_attribute('FactoryImporter', 'id') ||
                wall_entity_record[:entity].get_attribute('FactoryImporter', 'wall_id')
    end
    
    if wall_id.nil?
      puts "警告: 无法获取墙体ID，跳过反选"
      return
    end
    
    puts "墙体ID: #{wall_id}"
    
    # 获取该墙体对应的所有窗户
    wall_windows = get_windows_for_wall(wall_id)
    puts "墙体对应的窗户数量: #{wall_windows.length}"
    
    if wall_windows.empty?
      puts "该墙体没有对应的窗户，无需反选"
      return
    end
    
    # 显示墙体对应的窗户
    wall_windows.each_with_index do |window_record, index|
      puts "  窗户 #{index + 1}: #{window_record[:name]} (ID: #{window_record[:entity_id]})"
    end
    
    # 直接使用存储器中的窗户实体进行反选
    puts "直接使用存储器中的窗户实体进行反选..."
    removed_count = 0
    
    wall_windows.each do |window_record|
      window_entity = window_record[:entity]
      if window_entity && window_entity.valid?
        # 检查该窗户实体是否在当前选择中
        if selection.include?(window_entity)
          selection.remove(window_entity)
          puts "  -> 反选移除窗户: #{window_record[:name]} (ID: #{window_record[:entity_id]})"
          removed_count += 1
        else
          puts "  -> 窗户不在选择中: #{window_record[:name]} (ID: #{window_record[:entity_id]})"
        end
      else
        puts "  -> 窗户实体无效: #{window_record[:name]}"
      end
    end
    
    puts "反选完成，移除了 #{removed_count} 个窗户"
    puts "选择后实体数量: #{selection.length}"
  end
  
  # 智能过滤选择中的冲突实体（使用反选方式）
  def self.filter_conflicting_entities_from_selection(model, selection, target_type)
    puts "开始过滤冲突实体，目标类型: #{target_type}"
    puts "当前选择数量: #{selection.length}"
    
    # 定义实体冲突规则
    conflict_rules = {
      "wall" => ["window"],      # 选择墙体时过滤窗户
      "window" => ["wall"],      # 选择窗户时过滤墙体
      "equipment" => ["zone"],   # 选择设备时过滤区域
      "zone" => ["equipment"]    # 选择区域时过滤设备
    }
    
    # 获取需要过滤的实体类型
    types_to_filter = conflict_rules[target_type] || []
    puts "需要过滤的类型: #{types_to_filter.inspect}"
    
    total_removed = 0
    
    types_to_filter.each do |filter_type|
      # 获取该类型的所有实体
      filter_entities = get_entities_by_type(filter_type)
      filter_entity_ids = filter_entities.map { |record| record[:entity_id] }
      puts "#{filter_type} 类型实体数量: #{filter_entities.length}"
      
      # 使用反选方式：从选择中移除该类型的实体
      entities_to_remove = []
      selection.each do |selected_entity|
        # 方法1：检查实体ID
        if filter_entity_ids.include?(selected_entity.entityID)
          entities_to_remove << selected_entity
          next
        end
        
        # 方法2：检查自定义属性
        if selected_entity.respond_to?(:get_attribute)
          entity_type = selected_entity.get_attribute('FactoryImporter', 'type')
          window_type = selected_entity.get_attribute('FactoryImporter', 'window_type')
          entity_name = selected_entity.get_attribute('FactoryImporter', 'name')
          window_name = selected_entity.get_attribute('FactoryImporter', 'window_name')
          
          # 对于窗户的特殊处理
          if filter_type == "window"
            is_window = entity_type == "window" || 
                       window_type == "wall_window" || 
                       window_type == "independent_window" ||
                       (entity_name && (entity_name.include?("窗户") || entity_name.downcase.include?("window"))) ||
                       (window_name && (window_name.include?("窗户") || window_name.downcase.include?("window")))
            
            if is_window
              entities_to_remove << selected_entity
              next
            end
          else
            # 其他实体的常规处理
            if entity_type == filter_type || 
               (entity_name && entity_name.downcase.include?(filter_type.downcase))
              entities_to_remove << selected_entity
              next
            end
          end
        end
        
        # 方法3：检查实体名称
        if selected_entity.is_a?(Sketchup::Group) && selected_entity.name
          if selected_entity.name.downcase.include?(filter_type.downcase)
            entities_to_remove << selected_entity
            next
          end
        end
      end
      
      # 移除冲突实体
      entities_to_remove.each do |entity|
        selection.remove(entity)
        puts "反选移除: #{entity.entityID} (#{get_type_display_name(filter_type)})"
      end
      
      total_removed += entities_to_remove.length
      
      if entities_to_remove.any?
        puts "已反选移除 #{entities_to_remove.length} 个 #{get_type_display_name(filter_type)} 实体"
      end
    end
    
    puts "反选过滤完成，总共移除: #{total_removed} 个实体"
    puts "最终选择数量: #{selection.length}"
    
    total_removed
  end
  
  # 批量选择指定类型的所有实体
  def self.select_all_entities_by_type(entity_type)
    model = Sketchup.active_model
    selection = model.selection
    entities = get_entities_by_type(entity_type)
    
    if entities.empty?
      UI.messagebox("#{get_type_display_name(entity_type)} 暂无实体")
      return
    end
    
    # 清除当前选择
    selection.clear
    
    # 选择所有有效实体
    valid_count = 0
    invalid_count = 0
    
    entities.each do |entity_record|
      entity = entity_record[:entity]
      if entity && entity.valid?
        selection.add(entity)
        valid_count += 1
      else
        invalid_count += 1
      end
    end
    
    # 如果选择的是墙体，使用墙体和窗户对应关系进行反选
    if entity_type == "wall"
      puts "批量选择墙体，使用墙体和窗户对应关系进行反选..."
      # 对于批量选择，我们需要处理所有墙体
      wall_entities = get_entities_by_type("wall")
      wall_entities.each do |wall_record|
        remove_windows_using_mapping(model, selection, wall_record)
      end
    else
      # 其他实体使用常规过滤
      filter_conflicting_entities_from_selection(model, selection, entity_type)
    end
    
    # 显示结果
    result = "批量选择结果:\n\n"
    result += "类型: #{get_type_display_name(entity_type)}\n"
    result += "成功选择: #{valid_count} 个实体\n"
    result += "失效实体: #{invalid_count} 个\n"
    result += "最终选择: #{selection.length} 个实体\n"
    
    if selection.length > 0
      # 将视图调整到显示所有选中实体
      model.active_view.zoom(selection)
      result += "\n✅ 已选中所有 #{get_type_display_name(entity_type)}"
    else
      result += "\n❌ 没有可选择的实体"
    end
    
    UI.messagebox(result)
  end
  
  # 选择指定类型的所有实体（添加到当前选择）
  def self.add_all_entities_by_type_to_selection(entity_type)
    model = Sketchup.active_model
    selection = model.selection
    entities = get_entities_by_type(entity_type)
    
    if entities.empty?
      UI.messagebox("#{get_type_display_name(entity_type)} 暂无实体")
      return
    end
    
    # 添加到当前选择
    valid_count = 0
    invalid_count = 0
    
    entities.each do |entity_record|
      entity = entity_record[:entity]
      if entity && entity.valid?
        selection.add(entity)
        valid_count += 1
      else
        invalid_count += 1
      end
    end
    
    # 如果添加的是墙体，使用墙体和窗户对应关系进行反选
    if entity_type == "wall"
      puts "添加墙体到选择，使用墙体和窗户对应关系进行反选..."
      # 对于添加到选择，我们需要处理所有墙体
      wall_entities = get_entities_by_type("wall")
      wall_entities.each do |wall_record|
        remove_windows_using_mapping(model, selection, wall_record)
      end
    else
      # 其他实体使用常规过滤
      filter_conflicting_entities_from_selection(model, selection, entity_type)
    end
    
    # 显示结果
    result = "添加到选择结果:\n\n"
    result += "类型: #{get_type_display_name(entity_type)}\n"
    result += "成功添加: #{valid_count} 个实体\n"
    result += "失效实体: #{invalid_count} 个\n"
    result += "当前选择总数: #{selection.length} 个实体\n"
    
    if selection.length > 0
      result += "\n✅ 已添加所有 #{get_type_display_name(entity_type)} 到当前选择"
    else
      result += "\n❌ 没有可添加的实体"
    end
    
    UI.messagebox(result)
  end
  
  # 创建存储器菜单
  def self.create_storage_menu
    begin
      # 尝试不同的菜单名称，支持不同版本的SketchUp
      menu = nil
      
      # 尝试英文菜单名
      begin
        menu = UI.menu("Extensions")
      rescue
        # 尝试中文菜单名
        begin
          menu = UI.menu("插件")
        rescue
          # 尝试其他可能的菜单名
          begin
            menu = UI.menu("Tools")
          rescue
            puts "无法找到合适的菜单，跳过实体存储器菜单创建"
            return
          end
        end
      end
      
      # 创建实体存储器主菜单
      storage_menu = menu.add_submenu("实体存储器")
      
      # 添加状态显示菜单项
      storage_menu.add_item("存储状态") {
        show_storage_status
      }
      
      storage_menu.add_separator
      
      # 添加清空功能菜单项
      storage_menu.add_item("清空所有实体") {
        clear_all_entities
        refresh_storage_menu
        UI.messagebox("已清空所有实体")
      }
      
      # 添加刷新菜单项
      storage_menu.add_item("刷新菜单") {
        refresh_storage_menu
      }
      
      storage_menu.add_separator
      
      # 动态创建实体类型子菜单
      create_entity_type_menus(storage_menu)
      
    rescue => e
      puts "创建实体存储器菜单失败: #{e.message}"
      puts "错误详情: #{e.backtrace.join("\n")}"
    end
  end
  
  # 创建实体类型子菜单
  def self.create_entity_type_menus(parent_menu)
    ENTITY_TYPES.each do |key, type|
      # 获取当前实时的实体数量
      current_count = get_entities_by_type(type).size
      
      # 为每个实体类型创建子菜单（不显示计数）
      type_menu = parent_menu.add_submenu(get_type_display_name(type))
      
      # 添加该类型的统计信息
      type_menu.add_item("查看统计信息") {
        show_type_statistics(type)
      }
      
      # 添加批量选择功能
      type_menu.add_item("选择所有 #{get_type_display_name(type)}") {
        select_all_entities_by_type(type)
      }
      
      # 添加批量选择功能（添加到当前选择）
      type_menu.add_item("添加所有 #{get_type_display_name(type)} 到选择") {
        add_all_entities_by_type_to_selection(type)
      }
      
      # 添加选择该类型实体的菜单项
      type_menu.add_item("选择单个实体") {
        show_entity_selector(type)
      }
      
      type_menu.add_separator
      
      # 添加该类型的所有实体（显示所有实体，确保唯一性）
      entities = get_entities_by_type(type)
      if entities.any?
        entities.each do |entity_record|
          entity_name = entity_record[:name]
          # 为每个实体创建唯一的菜单项
          type_menu.add_item(entity_name) {
            select_entity_in_sketchup(entity_record)
          }
        end
      end
    end
  end
  
  # 获取类型显示名称
  def self.get_type_display_name(type)
    case type
    when "factory_ground"
      "工厂地面"
    when "indoor_zone"
      "内部区域"
    when "outdoor_zone"
      "外部区域"
    when "window"
      "窗户"
    when "wall"
      "墙体"
    when "equipment"
      "设备"
    when "flow"
      "流通道"
    when "column"
      "立柱"
    when "structure"
      "其他结构"
    else
      type
    end
  end
  
  # 显示存储状态
  def self.show_storage_status
    stats = get_statistics
    status = get_status
    
    info = "实体存储器状态:\n\n"
    info += "初始化状态: #{status[:initialized] ? '已初始化' : '未初始化'}\n"
    info += "总实体数量: #{status[:total_entities]}\n\n"
    
    if status[:has_entities]
      info += "各类型实体:\n"
      stats[:types].each do |type|
        entities = get_entities_by_type(type)
        if entities.any?
          info += "#{get_type_display_name(type)}: #{entities.size} 个\n"
        end
      end
    else
      info += "当前没有存储任何实体"
    end
    
    UI.messagebox(info)
  end
  
  # 显示指定类型的统计信息
  def self.show_type_statistics(entity_type)
    entities = get_entities_by_type(entity_type)
    
    if entities.any?
      info = "#{get_type_display_name(entity_type)} 统计信息:\n\n"
      info += "实体数量: #{entities.size}\n\n"
      info += "实体列表:\n"
      
      entities.each_with_index do |entity_record, index|
        info += "#{index + 1}. #{entity_record[:name]}\n"
        if entity_record[:metadata] && !entity_record[:metadata].empty?
          info += "   元数据: #{entity_record[:metadata].inspect}\n"
        end
      end
    else
      info = "#{get_type_display_name(entity_type)} 暂无实体"
    end
    
    UI.messagebox(info)
  end
  
  # 显示实体选择器（用于处理大量实体）
  def self.show_entity_selector(entity_type)
    entities = get_entities_by_type(entity_type)
    
    if entities.empty?
      UI.messagebox("#{get_type_display_name(entity_type)} 暂无实体")
      return
    end
    
    # 创建选择列表
    options = entities.map.with_index do |entity_record, index|
      "#{index + 1}. #{entity_record[:name]}"
    end
    
    # 显示选择对话框
    selection = UI.messagebox(
      "请选择要操作的 #{get_type_display_name(entity_type)}:\n\n" + options.join("\n"),
      MB_OKCANCEL
    )
    
    if selection == IDOK
      # 显示详细选择对话框
      show_detailed_entity_selector(entity_type, entities)
    end
  end
  
  # 显示详细的实体选择器
  def self.show_detailed_entity_selector(entity_type, entities)
    # 创建选择列表
    options = entities.map.with_index do |entity_record, index|
      "#{index + 1}. #{entity_record[:name]}"
    end
    
    # 使用输入框让用户选择
    prompt = "请输入要选择的 #{get_type_display_name(entity_type)} 编号 (1-#{entities.size}):"
    input = UI.inputbox([prompt], ["1"], "选择实体")
    
    if input
      begin
        index = input[0].to_i - 1
        if index >= 0 && index < entities.size
          select_entity_in_sketchup(entities[index])
        else
          UI.messagebox("无效的编号，请输入 1 到 #{entities.size} 之间的数字")
        end
      rescue => e
        UI.messagebox("选择失败: #{e.message}")
      end
    end
  end
  
  # 刷新菜单（重新创建）
  def self.refresh_storage_menu
    begin
      puts "开始刷新实体存储器菜单..."
      
      # 尝试不同的菜单名称，支持不同版本的SketchUp
      menu = nil
      
      # 尝试英文菜单名
      begin
        menu = UI.menu("Extensions")
      rescue
        # 尝试中文菜单名
        begin
          menu = UI.menu("插件")
        rescue
          # 尝试其他可能的菜单名
          begin
            menu = UI.menu("Tools")
          rescue
            puts "无法找到合适的菜单，跳过菜单刷新"
            return
          end
        end
      end
      
      # 查找并删除现有的实体存储器菜单
      existing_menu = find_storage_menu(menu)
      if existing_menu
        menu.remove_item(existing_menu)
        puts "已删除旧菜单"
      end
      
      # 重新创建菜单
      create_storage_menu
      puts "菜单刷新完成，当前实体状态:"
      
      # 显示当前各类型的实体数量
      ENTITY_TYPES.each do |key, type|
        count = get_entities_by_type(type).size
        if count > 0
          puts "  #{get_type_display_name(type)}: #{count} 个"
        end
      end
      
    rescue => e
      puts "刷新菜单失败: #{e.message}"
      puts "错误详情: #{e.backtrace.join("\n")}"
    end
  end
  
  # 查找现有的实体存储器菜单
  def self.find_storage_menu(parent_menu)
    parent_menu.items.each do |item|
      if item.respond_to?(:title) && item.title == "实体存储器"
        return item
      end
    end
    nil
  end
  
  # 显示实体选择器对话框
  def self.show_entity_selector(entity_type)
    entities = get_entities_by_type(entity_type)
    
    if entities.empty?
      UI.messagebox("该类型暂无存储的实体")
      return
    end
    
    # 构建实体列表
    entity_list = entities.map do |entity_record|
      entity_record[:name]
    end
    
    # 显示选择对话框
    prompts = ["选择要选中的实体:"]
    defaults = [entity_list.first]
    lists = [entity_list.join("|")]
    
    result = UI.inputbox(prompts, defaults, lists, "实体选择器 - #{get_type_display_name(entity_type)}")
    
    if result
      selected_name = result[0]
      selected_entity = entities.find { |e| e[:name] == selected_name }
      
      if selected_entity
        select_entity_in_sketchup(selected_entity)
      else
        UI.messagebox("未找到选中的实体")
      end
    end
  end
end 