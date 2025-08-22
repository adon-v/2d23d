# 材质管理器模块：处理SketchUp材质目录读取和材质应用
module MaterialManager
  # SketchUp材质目录路径
  MATERIALS_DIR = "C:\\ProgramData\\SketchUp\\SketchUp 2024\\SketchUp\\Materials"
  
  # 材质分类缓存
  @material_categories = {}
  
  # 材质分类名称中英文对照表
  CATEGORY_TRANSLATIONS = {
    # 建筑相关
    'Architectural' => '建筑',
    'Architecture' => '建筑',
    'Building' => '建筑',
    
    # 砖石和覆层
    'Brick and Cladding' => '砖石和覆层',
    'Brick' => '砖石',
    'Cladding' => '覆层',
    'Masonry' => '砌体',
    
    # 地毯
    'Carpet' => '地毯',
    'Rug' => '地毯',
    
    # 陶瓷
    'Ceramic' => '陶瓷',
    'Porcelain' => '瓷器',
    
    # 混凝土
    'Concrete' => '混凝土',
    'Cement' => '水泥',
    
    # 织物
    'Fabric' => '织物',
    'Textile' => '纺织品',
    'Cloth' => '布料',
    
    # 玻璃
    'Glass' => '玻璃',
    'Glazing' => '玻璃',
    
    # 地面覆盖
    'Groundcover' => '地面覆盖',
    'Ground Cover' => '地面覆盖',
    'Flooring' => '地面',
    
    # 景观
    'Landscape' => '景观',
    'Garden' => '花园',
    'Outdoor' => '户外',
    
    # 金属
    'Metal' => '金属',
    'Steel' => '钢',
    'Aluminum' => '铝',
    'Iron' => '铁',
    'Copper' => '铜',
    'Brass' => '黄铜',
    'Bronze' => '青铜',
    
    # 涂料
    'Paint' => '涂料',
    'Coating' => '涂层',
    'Finish' => '饰面',
    
    # 塑料
    'Plastic' => '塑料',
    'Polymer' => '聚合物',
    
    # 屋顶
    'Roofing' => '屋顶',
    'Roof' => '屋顶',
    'Shingle' => '瓦片',
    
    # 石材
    'Stone' => '石材',
    'Rock' => '岩石',
    'Granite' => '花岗岩',
    'Marble' => '大理石',
    'Limestone' => '石灰石',
    
    # 瓷砖
    'Tile' => '瓷砖',
    'Ceramic Tile' => '陶瓷砖',
    'Floor Tile' => '地砖',
    'Wall Tile' => '墙砖',
    
    # 木材
    'Wood' => '木材',
    'Timber' => '木材',
    'Lumber' => '木材',
    'Oak' => '橡木',
    'Pine' => '松木',
    'Maple' => '枫木',
    'Cherry' => '樱桃木',
    'Walnut' => '胡桃木',
    
    # 其他常见分类
    'Interior' => '室内',
    'Exterior' => '室外',
    'Decorative' => '装饰',
    'Industrial' => '工业',
    'Commercial' => '商业',
    'Residential' => '住宅',
    'Modern' => '现代',
    'Traditional' => '传统',
    'Classic' => '经典',
    'Contemporary' => '当代',
    
    # 特殊材质
    'Fabrication' => '制造',
    'Manufacturing' => '制造',
    'Construction' => '建筑',
    'Infrastructure' => '基础设施',
    'Transportation' => '交通',
    'Utilities' => '公用设施'
  }
  
  # 初始化材质管理器
  def self.init
    load_material_categories
    create_material_menu
    puts "材质管理器初始化成功"
  rescue => e
    puts "材质管理器初始化失败: #{e.message}"
  end
  
  # 加载材质分类
  def self.load_material_categories
    return unless Dir.exist?(MATERIALS_DIR)
    
    @material_categories.clear
    
    Dir.entries(MATERIALS_DIR).each do |entry|
      next if entry == '.' || entry == '..'
      
      category_path = File.join(MATERIALS_DIR, entry)
      if Dir.exist?(category_path)
        @material_categories[entry] = load_materials_from_category(category_path)
      end
    end
    
    puts "已加载 #{@material_categories.keys.length} 个材质分类"
  rescue => e
    puts "加载材质分类失败: #{e.message}"
  end
  
  # 从分类目录加载材质
  def self.load_materials_from_category(category_path)
    materials = []
    
    Dir.entries(category_path).each do |entry|
      next if entry == '.' || entry == '..'
      
      file_path = File.join(category_path, entry)
      if File.file?(file_path) && entry.downcase.end_with?('.skm')
        # 提取材质名称（去掉.skm扩展名）
        material_name = File.basename(entry, '.skm')
        materials << {
          name: material_name,
          path: file_path,
          filename: entry
        }
      end
    end
    
    materials
  end
  
  # 创建材质菜单
  def self.create_material_menu
    return if @material_categories.empty?
    
    # 创建主菜单
    plugin_menu = UI.menu("Extensions")
    material_menu = plugin_menu.add_submenu("材质管理器")
    
    # 添加刷新材质菜单项
    refresh_cmd = UI::Command.new("刷新材质目录") {
      load_material_categories
      create_material_menu
      UI.messagebox("材质目录已刷新")
    }
    refresh_cmd.tooltip = "重新扫描材质目录"
    material_menu.add_item(refresh_cmd)
    
    # 添加查看翻译对照表菜单项
    translation_cmd = UI::Command.new("查看翻译对照表") {
      show_translation_table
      stats = get_translation_stats
      UI.messagebox("翻译统计信息:\n\n总计分类: #{stats[:total]}\n已翻译: #{stats[:translated]}\n未翻译: #{stats[:untranslated].length}\n翻译率: #{stats[:translation_rate]}%")
    }
    translation_cmd.tooltip = "查看材质分类名称的中英文对照表"
    material_menu.add_item(translation_cmd)
    
    # 添加调试选中对象菜单项
    debug_cmd = UI::Command.new("调试选中对象") {
      debug_selected_entities
    }
    debug_cmd.tooltip = "显示当前选中对象的详细信息"
    material_menu.add_item(debug_cmd)
    
    # 添加强制应用材质菜单项
    force_cmd = UI::Command.new("强制应用材质") {
      # 这里需要用户选择材质，暂时使用测试材质
      test_material = {
        name: "强制测试材质",
        path: "C:\\ProgramData\\SketchUp\\SketchUp 2024\\SketchUp\\Materials\\Paint\\Paint_White.skm"
      }
      force_apply_material_to_selection(test_material)
    }
    force_cmd.tooltip = "强制应用材质到选中对象（处理锁定材质）"
    material_menu.add_item(force_cmd)
    
    # 添加可视化测试菜单项
    visual_cmd = UI::Command.new("可视化测试（红色）") {
      visual_test_material_application
    }
    visual_cmd.tooltip = "应用鲜艳的红色材质进行可视化测试"
    material_menu.add_item(visual_cmd)
    
    material_menu.add_separator
    
    # 获取翻译后的分类名称
    translated_categories = get_translated_categories
    
    # 为每个分类创建子菜单（使用翻译后的名称）
    translated_categories.each do |translated_name, materials|
      next if materials.empty?
      
      category_menu = material_menu.add_submenu(translated_name)
      
      # 为每个材质创建菜单项
      materials.each do |material|
        material_cmd = UI::Command.new(material[:name]) {
          apply_material_to_selection(material)
        }
        material_cmd.tooltip = "应用材质: #{material[:name]}"
        category_menu.add_item(material_cmd)
      end
    end
    
    puts "材质菜单创建成功，共 #{translated_categories.keys.length} 个分类"
    puts "分类名称已翻译为中文"
  rescue => e
    puts "创建材质菜单失败: #{e.message}"
  end
  
  # 应用材质到选中的对象
  def self.apply_material_to_selection(material)
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("请先选择一个对象，然后点击材质进行应用")
      return
    end
    
    begin
      # 加载材质
      material_definition = model.materials.load(material[:path])
      
      if material_definition
        success_count = 0
        failed_count = 0
        
        # 应用材质到选中的对象
        selection.each do |entity|
          begin
            # 处理不同类型的实体
            if entity.is_a?(Sketchup::Face)
              # 直接应用到面
              entity.material = material_definition
              entity.back_material = material_definition
              success_count += 1
            elsif entity.is_a?(Sketchup::Edge)
              # 应用到边
              entity.material = material_definition
              success_count += 1
            elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
              # 直接应用到组内的所有面，而不是组本身
              group_success = apply_material_to_group_entities(entity, material_definition)
              if group_success > 0
                success_count += 1
              else
                failed_count += 1
              end
            elsif entity.respond_to?(:material=)
              entity.material = material_definition
              success_count += 1
            elsif entity.respond_to?(:back_material=)
              entity.back_material = material_definition
              success_count += 1
            else
              failed_count += 1
            end
          rescue => e
            failed_count += 1
            puts "应用材质到实体失败: #{e.message}"
          end
        end
        
        # 显示结果消息
        message = "材质应用结果:\n"
        message += "成功: #{success_count} 个对象\n"
        message += "失败: #{failed_count} 个对象\n"
        message += "材质: #{material[:name]}"
        
        if failed_count > 0
          UI.messagebox(message)
        else
          UI.messagebox("成功应用材质 '#{material[:name]}' 到 #{success_count} 个对象")
        end
        
        # 刷新视图
        model.active_view.invalidate
      else
        UI.messagebox("无法加载材质: #{material[:name]}")
      end
    rescue => e
      UI.messagebox("应用材质失败: #{e.message}")
    end
  end
  
  # 递归应用材质到组内的所有实体
  def self.apply_material_to_group_entities(group, material_definition)
    success_count = 0
    
    group.entities.each do |entity|
      begin
        if entity.is_a?(Sketchup::Face)
          # 确保面是有效的且可见的
          if entity.valid? && !entity.hidden?
            # 跳过窗户玻璃面
            if face_is_window_glass?(entity)
              puts "跳过窗户玻璃面: #{entity}"
              next
            end
            entity.material = material_definition
            entity.back_material = material_definition
            success_count += 1
            puts "成功应用材质到面: #{entity}"
          end
        elsif entity.is_a?(Sketchup::Edge)
          # 确保边是有效的且可见的
          if entity.valid? && !entity.hidden?
            entity.material = material_definition
            success_count += 1
          end
        elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          # 递归处理子组，但跳过隐藏的组与窗户相关实体
          if entity.valid? && !entity.hidden?
            if window_like_entity?(entity)
              puts "跳过窗户子组: #{entity}"
              next
            end
            success_count += apply_material_to_group_entities(entity, material_definition)
          end
        end
      rescue => e
        puts "递归应用材质失败: #{e.message}"
      end
    end
    
    success_count
  end
  
  # 获取材质分类信息
  def self.get_material_categories
    @material_categories
  end
  
  # 检查材质目录是否存在
  def self.materials_directory_exists?
    Dir.exist?(MATERIALS_DIR)
  end
  
  # 获取材质目录路径
  def self.get_materials_directory
    MATERIALS_DIR
  end
  
  # 重新扫描材质目录
  def self.rescan_materials
    load_material_categories
    create_material_menu
  end
  
  # 翻译材质分类名称
  def self.translate_category_name(english_name)
    # 尝试直接匹配
    return CATEGORY_TRANSLATIONS[english_name] if CATEGORY_TRANSLATIONS[english_name]
    
    # 尝试部分匹配（处理包含额外信息的名称）
    CATEGORY_TRANSLATIONS.each do |key, value|
      if english_name.include?(key) || key.include?(english_name)
        return value
      end
    end
    
    # 如果没有找到匹配，返回原名称
    english_name
  end
  
  # 获取翻译后的分类名称
  def self.get_translated_categories
    translated = {}
    @material_categories.each do |english_name, materials|
      translated_name = translate_category_name(english_name)
      translated[translated_name] = materials
    end
    translated
  end
  
  # 显示翻译对照表
  def self.show_translation_table
    puts "=== 材质分类名称翻译对照表 ==="
    puts
    puts "英文名称 => 中文名称"
    puts "-" * 40
    
    @material_categories.keys.each do |english_name|
      translated_name = translate_category_name(english_name)
      puts "#{english_name} => #{translated_name}"
    end
    
    puts "-" * 40
    puts "总计: #{@material_categories.keys.length} 个分类"
  end
  
  # 获取分类翻译统计信息
  def self.get_translation_stats
    total_categories = @material_categories.keys.length
    translated_categories = 0
    untranslated_categories = []
    
    @material_categories.keys.each do |english_name|
      translated_name = translate_category_name(english_name)
      if translated_name != english_name
        translated_categories += 1
      else
        untranslated_categories << english_name
      end
    end
    
    {
      total: total_categories,
      translated: translated_categories,
      untranslated: untranslated_categories,
      translation_rate: (translated_categories.to_f / total_categories * 100).round(2)
    }
  end
  
  # 调试选中对象的详细信息
  def self.debug_selected_entities
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("当前没有选中任何对象")
      return
    end
    
    debug_info = "选中对象详细信息:\n\n"
    
    selection.each_with_index do |entity, index|
      debug_info += "对象 #{index + 1}:\n"
      debug_info += "  类型: #{entity.class.name}\n"
      debug_info += "  名称: #{entity.name rescue '无名称'}\n"
      debug_info += "  有效: #{entity.valid?}\n"
      
      # 检查材质相关方法
      debug_info += "  材质方法:\n"
      debug_info += "    respond_to?(:material=): #{entity.respond_to?(:material=)}\n"
      debug_info += "    respond_to?(:back_material=): #{entity.respond_to?(:back_material=)}\n"
      debug_info += "    respond_to?(:material): #{entity.respond_to?(:material)}\n"
      
      # 显示当前材质信息
      if entity.respond_to?(:material)
        current_material = entity.material
        debug_info += "  当前材质: #{current_material ? current_material.name : '无材质'}\n"
        debug_info += "  材质类型: #{current_material ? current_material.class.name : '无'}\n"
      end
      
      # 如果是组，显示组内实体信息
       if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        debug_info += "  组内实体数量: #{entity.entities.length}\n"
        face_count = entity.entities.count { |e| e.is_a?(Sketchup::Face) }
        edge_count = entity.entities.count { |e| e.is_a?(Sketchup::Edge) }
        debug_info += "  面数量: #{face_count}, 边数量: #{edge_count}\n"
      end
      
      debug_info += "\n"
    end
    
    UI.messagebox(debug_info)
  end
  
  # 强制应用材质（处理可能被锁定的材质）
  def self.force_apply_material_to_selection(material)
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("请先选择一个对象，然后点击材质进行应用")
      return
    end
    
    begin
      # 加载材质
      material_definition = model.materials.load(material[:path])
      
      if material_definition
        success_count = 0
        failed_count = 0
        details = []
        
        # 应用材质到选中的对象
        selection.each do |entity|
          begin
            if entity.is_a?(Sketchup::Face)
              # 直接应用到面
              entity.material = material_definition
              entity.back_material = material_definition
              success_count += 1
              details << "面: 成功"
            elsif entity.is_a?(Sketchup::Edge)
              # 应用到边
              entity.material = material_definition
              success_count += 1
              details << "边: 成功"
            elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
              # 强制应用到组内的所有面
              group_success = force_apply_to_group_entities(entity, material_definition)
              if group_success > 0
                success_count += 1
                details << "组: 成功应用到 #{group_success} 个面"
              else
                failed_count += 1
                details << "组: 失败"
              end
            else
              failed_count += 1
              details << "#{entity.class.name}: 不支持"
            end
          rescue => e
            failed_count += 1
            details << "#{entity.class.name}: 错误 - #{e.message}"
          end
        end
        
        # 显示结果消息
        result = "强制材质应用结果:\n\n"
        result += "成功: #{success_count} 个对象\n"
        result += "失败: #{failed_count} 个对象\n"
        result += "材质: #{material[:name]}\n\n"
        result += "详细信息:\n"
        details.each { |detail| result += "  #{detail}\n" }
        
        UI.messagebox(result)
        
        # 刷新视图
        model.active_view.invalidate
      else
        UI.messagebox("无法加载材质: #{material[:name]}")
      end
    rescue => e
      UI.messagebox("应用材质失败: #{e.message}")
    end
  end
  
  # 强制应用到组内所有实体
  def self.force_apply_to_group_entities(group, material_definition)
    success_count = 0
    
    group.entities.each do |entity|
      begin
        if entity.is_a?(Sketchup::Face)
          # 强制应用到面，即使面被隐藏
          if entity.valid?
            entity.material = material_definition
            entity.back_material = material_definition
            success_count += 1
            puts "强制应用材质到面: #{entity}"
          end
        elsif entity.is_a?(Sketchup::Edge)
          if entity.valid?
            entity.material = material_definition
            success_count += 1
          end
        elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          # 递归处理子组
          if entity.valid?
            success_count += force_apply_to_group_entities(entity, material_definition)
          end
        end
      rescue => e
        puts "强制应用材质失败: #{e.message}"
      end
    end
    
    success_count
  end
  
  # 可视化测试材质应用
  def self.visual_test_material_application
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("请先选择要测试的对象")
      return
    end
    
    # 创建明显的测试材质
    test_material = model.materials.add("可视化测试材质_#{Time.now.to_i}")
    test_material.color = Sketchup::Color.new(255, 0, 0)  # 鲜艳的红色
    
    success_count = 0
    failed_count = 0
    details = []
    
    selection.each do |entity|
      begin
        if entity.is_a?(Sketchup::Face)
          entity.material = test_material
          entity.back_material = test_material
          success_count += 1
          details << "面: 成功应用红色材质"
        elsif entity.is_a?(Sketchup::Edge)
          entity.material = test_material
          success_count += 1
          details << "边: 成功应用红色材质"
        elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          # 直接应用到组内所有面
          group_success = apply_material_to_group_entities(entity, test_material)
          if group_success > 0
            success_count += 1
            details << "组: 成功应用到 #{group_success} 个面"
          else
            failed_count += 1
            details << "组: 没有找到可应用的面"
          end
        else
          failed_count += 1
          details << "#{entity.class.name}: 不支持此类型"
        end
      rescue => e
        failed_count += 1
        details << "#{entity.class.name}: 错误 - #{e.message}"
      end
    end
    
    # 强制刷新视图
    model.active_view.invalidate
    
    # 显示结果
    result = "可视化测试结果:\n\n"
    result += "成功: #{success_count} 个对象\n"
    result += "失败: #{failed_count} 个对象\n"
    result += "材质: #{test_material.name} (鲜艳红色)\n\n"
    result += "详细信息:\n"
    details.each { |detail| result += "  #{detail}\n" }
    
    if success_count > 0
      result += "\n✅ 如果看到红色，说明材质应用成功！"
    else
      result += "\n❌ 没有成功应用材质，请检查选择的对象"
    end
    
    UI.messagebox(result)
  end

  # 判断一个组/组件是否可能为窗户相关
  def self.window_like_entity?(entity)
    return false unless entity.respond_to?(:get_attribute)
    # 通过自定义属性判断
    wtype = entity.get_attribute('FactoryImporter', 'window_type')
    wname = entity.get_attribute('FactoryImporter', 'window_name')
    etype = entity.get_attribute('FactoryImporter', 'type')
    name  = entity.respond_to?(:name) ? entity.name.to_s : ""
    
    return true if etype.to_s == 'window'
    return true if %w[wall_window independent_window].include?(wtype.to_s)
    return true if wname.to_s.downcase.include?('window') || wname.to_s.include?('窗')
    return true if name.downcase.include?('window') || name.include?('窗')
    false
  end

  # 判断一个面是否为窗户玻璃
  def self.face_is_window_glass?(face)
    return false unless face.is_a?(Sketchup::Face)
    return false unless face.respond_to?(:get_attribute)
    ftype = face.get_attribute('FactoryImporter', 'face_type')
    return true if ftype.to_s == 'window_glass'
    false
  end
end 