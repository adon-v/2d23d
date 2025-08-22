# 简化版实体存储器模块：专门解决SketchUp 2024兼容性问题
module EntityStorageSimple
  # 实体类型定义
  ENTITY_TYPES = {
    "factory_ground" => "工厂地面",
    "indoor_zone" => "内部区域", 
    "outdoor_zone" => "外部区域",
    "window" => "窗户",
    "wall" => "墙体",
    "equipment" => "设备",
    "flow" => "流通道",
    "door" => "门",
    "structure" => "其他结构"
  }
  
  # 实体存储
  @entities = {}
  @initialized = false
  
  # 初始化
  def self.init
    return if @initialized
    
    ENTITY_TYPES.each do |key, _|
      @entities[key] = []
    end
    
    @initialized = true
    puts "简化版实体存储器初始化完成"
  end
  
  # 创建简化菜单
  def self.create_simple_menu
    begin
      puts "创建简化版实体存储器菜单..."
      
      # 尝试获取Extensions菜单
      menu = UI.menu("Extensions")
      
      # 创建主菜单
      storage_menu = menu.add_submenu("实体存储器(简化版)")
      
      # 添加基本功能
      storage_menu.add_item("存储状态") {
        show_simple_status
      }
      
      storage_menu.add_separator
      
      storage_menu.add_item("清空所有实体") {
        clear_all_entities
        UI.messagebox("已清空所有实体")
      }
      
      storage_menu.add_separator
      
      # 为每个类型创建子菜单
      ENTITY_TYPES.each do |key, display_name|
        type_menu = storage_menu.add_submenu(display_name)
        
        type_menu.add_item("查看统计") {
          show_type_stats(key)
        }
        
        type_menu.add_item("选择实体") {
          select_entities_by_type(key)
        }
        
        # 显示该类型的实体（最多5个）
        entities = get_entities_by_type(key)
        if entities.any?
          type_menu.add_separator
          display_count = [entities.size, 5].min
          entities.first(display_count).each do |entity_record|
            type_menu.add_item(entity_record[:name]) {
              select_entity_in_sketchup(entity_record)
            }
          end
          
          if entities.size > 5
            type_menu.add_item("... 还有 #{entities.size - 5} 个") {
              select_entities_by_type(key)
            }
          end
        end
      end
      
      puts "简化版菜单创建成功"
      
    rescue => e
      puts "创建简化版菜单失败: #{e.message}"
      puts "错误详情: #{e.backtrace.join("\n")}"
    end
  end
  
  # 存储实体
  def self.store_entity(entity, name, type, metadata = {})
    init
    
    return false unless ENTITY_TYPES.key?(type)
    return false unless entity.respond_to?(:entityID)
    
    entity_record = {
      id: entity.entityID,
      name: name,
      type: type,
      metadata: metadata,
      timestamp: Time.now
    }
    
    @entities[type] << entity_record
    puts "已存储实体: #{name} (#{type})"
    
    true
  rescue => e
    puts "存储实体失败: #{e.message}"
    false
  end
  
  # 获取指定类型的实体
  def self.get_entities_by_type(type)
    init
    @entities[type] || []
  end
  
  # 获取所有实体
  def self.get_all_entities
    init
    all_entities = []
    @entities.each do |_, entities|
      all_entities.concat(entities)
    end
    all_entities
  end
  
  # 清空所有实体
  def self.clear_all_entities
    init
    @entities.each do |key, _|
      @entities[key] = []
    end
    puts "已清空所有实体"
  end
  
  # 显示简化状态
  def self.show_simple_status
    init
    
    total_count = get_all_entities.size
    info = "简化版实体存储器状态:\n\n"
    info += "总实体数量: #{total_count}\n\n"
    
    if total_count > 0
      info += "各类型实体:\n"
      ENTITY_TYPES.each do |key, display_name|
        count = get_entities_by_type(key).size
        if count > 0
          info += "#{display_name}: #{count} 个\n"
        end
      end
    else
      info += "当前没有存储任何实体"
    end
    
    UI.messagebox(info)
  end
  
  # 显示类型统计
  def self.show_type_stats(type)
    entities = get_entities_by_type(type)
    display_name = ENTITY_TYPES[type] || type
    
    if entities.any?
      info = "#{display_name} 统计信息:\n\n"
      info += "实体数量: #{entities.size}\n\n"
      info += "实体列表:\n"
      
      entities.each_with_index do |entity_record, index|
        info += "#{index + 1}. #{entity_record[:name]}\n"
        if entity_record[:metadata] && !entity_record[:metadata].empty?
          info += "   元数据: #{entity_record[:metadata].inspect}\n"
        end
      end
    else
      info = "#{display_name} 暂无实体"
    end
    
    UI.messagebox(info)
  end
  
  # 选择指定类型的实体
  def self.select_entities_by_type(type)
    entities = get_entities_by_type(type)
    display_name = ENTITY_TYPES[type] || type
    
    if entities.empty?
      UI.messagebox("#{display_name} 暂无实体")
      return
    end
    
    # 构建选择列表
    entity_list = entities.map { |e| e[:name] }
    
    # 显示选择对话框
    prompts = ["选择要选中的实体:"]
    defaults = [entity_list.first]
    lists = [entity_list.join("|")]
    
    result = UI.inputbox(prompts, defaults, lists, "实体选择器 - #{display_name}")
    
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
  
  # 在SketchUp中选择实体
  def self.select_entity_in_sketchup(entity_record)
    model = Sketchup.active_model
    return unless model
    
    selection = model.selection
    selection.clear
    
    # 尝试通过ID查找实体
    entity = model.find_entity_by_id(entity_record[:id])
    
    if entity && entity.valid?
      selection.add(entity)
      puts "已选中实体: #{entity_record[:name]}"
      
      # 将视图中心对准选中的实体
      model.active_view.zoom(entity)
    else
      puts "警告: 实体已失效，无法选中"
      # 从存储中移除失效的实体
      remove_invalid_entity(entity_record)
    end
  end
  
  # 移除失效的实体
  def self.remove_invalid_entity(entity_record)
    type = entity_record[:type]
    @entities[type].delete_if { |e| e[:id] == entity_record[:id] }
    puts "已移除失效的实体: #{entity_record[:name]}"
  end
  
  # 获取统计信息
  def self.get_statistics
    init
    
    stats = {
      total: get_all_entities.size,
      types: ENTITY_TYPES.keys,
      type_counts: {}
    }
    
    ENTITY_TYPES.each do |key, _|
      stats[:type_counts][key] = get_entities_by_type(key).size
    end
    
    stats
  end
  
  # 获取状态信息
  def self.get_status
    init
    
    {
      initialized: @initialized,
      total_entities: get_all_entities.size,
      has_entities: get_all_entities.any?
    }
  end
end 