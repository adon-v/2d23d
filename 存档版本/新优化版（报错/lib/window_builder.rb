module WindowBuilder
  # 与门模块保持一致的默认参数定义
  DEFAULT_WIDTH = 1000    # 毫米
  DEFAULT_HEIGHT = 1500   # 毫米
  DEFAULT_THICKNESS = 50  # 毫米（仅独立窗户用）
  DEFAULT_HEIGHT_POS = 1500  # 中心点高度（毫米）

  # 批量创建所有窗户（完全对齐DoorBuilder.create_all_doors）
  def self.create_all_windows(window_data_list, parent_group)
    puts "开始创建窗户..."
    window_count = 0
    
    window_data_list.each do |window_item|
      begin
        window_data = window_item[:window_data]
        wall_data = window_item[:wall_data]
        current_parent = window_item[:parent_group] || parent_group
        
        # 数据完整性验证（与门的前置检查一致）
        next unless validate_window_data(window_data)
        
        # 墙体窗户处理
        if wall_data
          wall_id = wall_data["id"] || wall_data["name"] || "未知墙体"
          puts "处理墙体窗户 (墙体ID: #{wall_id}, 窗户ID: #{window_data['id'] || '未知'})"
          
          # 找到对应的墙体组（复用门的墙体查找逻辑）
          wall_group = Utils.find_wall_group(current_parent, wall_id)
          
          if wall_group
            # 创建窗户开口（对应门的create_door_opening）
            create_window_opening(wall_group, wall_data, window_data, current_parent)
            window_count += 1
          else
            puts "警告: 未找到墙体 '#{wall_id}'，跳过此窗户"
          end
        else
          # 独立窗户处理（对应门的独立处理逻辑）
          puts "处理独立窗户 (ID: #{window_data['id'] || '未知'})"
          import_independent_window(window_data, current_parent)
          window_count += 1
        end
      rescue => e
        window_id = window_data["id"] || "未知"
        error_msg = "警告: 创建窗户时出错 (ID: #{window_id}): #{Utils.ensure_utf8(e.message)}"
        puts Utils.ensure_utf8(error_msg)
        next
      end
    end
    puts "窗户创建完成，共创建 #{window_count} 个窗户"
  end

  # 数据验证（与门的数据验证逻辑一致）
  def self.validate_window_data(window_data)
    return false unless window_data.is_a?(Hash)
    
    # 验证ID或名称存在（至少一个标识）
    unless window_data['id'] || window_data['name']
      puts "警告: 窗户数据缺少ID和名称，跳过"
      return false
    end
    
    # 验证基本尺寸数据
    if window_data['size'].nil? && window_data['position'].nil?
      puts "警告: 窗户数据缺少尺寸或位置信息 (ID: #{window_data['id'] || '未知'})"
      return false
    end
    
    true
  end

  # 在墙体上创建窗户开口（对应门的create_door_opening）
  def self.create_window_opening(wall_group, wall_data, window_data, parent_group)
    # 根据layoutV2.4重新设计：position是中心点，size是长宽
    position_data = window_data["position"]
    size_data = window_data["size"]
    
    unless position_data && size_data && size_data.size >= 2
      puts "警告: 窗户位置或尺寸数据不足，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户中心点坐标
    center_point = Utils.validate_and_create_point(position_data)
    unless center_point
      puts "警告: 窗户中心点坐标无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户尺寸 - SketchUp 2024建筑毫米模式，直接使用毫米单位
    width = Utils.parse_number(size_data[0]) || 800.0
    height = Utils.parse_number(size_data[1]) || 200.0
    
    # 尺寸有效性检查
    width = 800.0 if width <= 0
    height = 200.0 if height <= 0
    
    # 提取窗户高度位置 - SketchUp 2024建筑毫米模式，直接使用毫米单位
    window_height_pos = Utils.parse_number(window_data["height"]) || 1200.0
    window_height_pos = 1200.0 if window_height_pos <= 0
    
    # 墙体厚度处理 - SketchUp 2024建筑毫米模式，直接使用毫米单位
    wall_thickness = Utils.parse_number(wall_data["thickness"]) || 200.0
    wall_thickness = 200.0 if wall_thickness <= 0
    
    puts "在墙体上创建窗户开口: 中心点=#{center_point}, 宽度=#{width.round(2)}mm, 高度=#{height.round(2)}mm, 高度位置=#{window_height_pos.round(2)}mm, 墙体厚度=#{wall_thickness.round(2)}mm"
    
    # 计算墙体的方向（复用门的墙体方向计算）
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法创建窗户开口"
      return
    end
    
    # 根据墙体厚度处理不同情况（与门的厚度分支一致）
    if wall_thickness <= 1.0
      create_window_on_zero_thickness_wall(wall_group, wall_data, window_data, center_point, width, height, window_height_pos)
    else
      create_window_on_normal_wall(wall_group, wall_data, window_data, center_point, width, height, window_height_pos, wall_thickness)
    end
  end

  # 在厚度为0的墙体上创建窗户
  def self.create_window_on_zero_thickness_wall(wall_group, wall_data, window_data, center_point, width, height, window_height_pos)
    model = Sketchup.active_model
    model.start_operation("创建零厚度墙体窗户", true)
    
    wall_entities = wall_group.entities
    
    # 计算墙体的方向
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法在零厚度墙体上创建窗户"
      model.abort_operation
      return
    end
    
    # 计算墙体方向向量
    wall_vector = wall_end - wall_start
    
    # 检查墙体向量有效性
    wall_direction = nil
    if wall_vector.length >= 1.0
      wall_direction = wall_vector.normalize
    else
      # 如果墙体向量无效，使用默认方向（水平向右）
      wall_direction = Geom::Vector3d.new(1, 0, 0)
      puts "警告: 墙体向量无效，使用默认方向"
    end
    
    # 计算窗户的起点和终点
    half_width = width / 2.0
    start_point = center_point.offset(wall_direction.reverse, half_width)
    end_point = center_point.offset(wall_direction, half_width)
    
    # 计算窗户底部和顶部点
    bottom_z = window_height_pos - height / 2
    top_z = window_height_pos + height / 2
    
    start_point_bottom = Geom::Point3d.new(start_point.x, start_point.y, bottom_z)
    end_point_bottom = Geom::Point3d.new(end_point.x, end_point.y, bottom_z)
    start_point_top = Geom::Point3d.new(start_point.x, start_point.y, top_z)
    end_point_top = Geom::Point3d.new(end_point.x, end_point.y, top_z)
    
    # 对于零厚度墙体，直接在墙体位置创建透明玻璃
    window_face = create_window_cut_face(wall_entities, start_point_bottom, end_point_bottom, start_point_top, end_point_top)
    if window_face
      puts "零厚度墙体窗户开口创建成功"
      # 设置窗户开口的材质为透明
      set_glass_material(window_face, window_data["id"] || "window_#{rand(1000..9999)}")
    else
      puts "警告: 零厚度墙体窗户开口创建失败"
      model.abort_operation
      return
    end
    
    model.commit_operation
    
    # 创建窗户几何体（在开口处）
    create_window_geometry(wall_data, window_data, start_point_bottom, end_point_bottom, start_point_top, end_point_top, wall_group)
  end

  # 正常厚度墙体窗户处理（对应门的create_door_on_normal_wall）
  def self.create_window_on_normal_wall(wall_group, wall_data, window_data, center_point, width, height, window_height_pos, wall_thickness)
    model = Sketchup.active_model
    model.start_operation("创建正常墙体窗户", true)
    
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
  
    unless wall_start && wall_end
      puts "警告: 墙体坐标无效，无法创建窗户"
      model.abort_operation
      return
    end
  
    # 计算墙体向量（复用门的向量计算）
    wall_vector = wall_end - wall_start
    if wall_vector.length < 1.0
      puts "警告: 墙体向量长度过小，无法创建窗户"
      model.abort_operation
      return
    end
  
    # 计算墙体法线（与门的法线逻辑一致）
    begin
      wall_normal = wall_vector.cross(Geom::Vector3d.new(0, 0, 1)).normalize
      wall_normal = wall_normal.reverse if wall_normal.x < 0
    rescue => e
      puts "警告: 墙体法线计算失败: #{e.message}"
      puts "  墙体向量: #{wall_vector}"
      model.abort_operation
      return
    end
  
    # 计算窗户的起点和终点（基于中心点和宽度）
    begin
      wall_direction = wall_vector.normalize
    rescue => e
      puts "警告: 墙体方向向量标准化失败: #{e.message}"
      puts "  墙体向量: #{wall_vector}"
      model.abort_operation
      return
    end
    half_width = width / 2.0
    start_point = center_point.offset(wall_direction.reverse, half_width)
    end_point = center_point.offset(wall_direction, half_width)
    
    # 计算窗户底部和顶部点
    bottom_z = window_height_pos - height / 2
    top_z = window_height_pos + height / 2
    
    start_point_bottom = Geom::Point3d.new(start_point.x, start_point.y, bottom_z)
    end_point_bottom = Geom::Point3d.new(end_point.x, end_point.y, bottom_z)
    start_point_top = Geom::Point3d.new(start_point.x, start_point.y, top_z)
    end_point_top = Geom::Point3d.new(end_point.x, end_point.y, top_z)
  
    # 在墙体上创建窗户洞
    create_window_cut(wall_group.entities, start_point_bottom, end_point_bottom, start_point_top, end_point_top, wall_normal, wall_thickness)
    
    model.commit_operation
    
    # 创建窗户几何体（在开口处）
    create_window_geometry(wall_data, window_data, start_point_bottom, end_point_bottom, start_point_top, end_point_top, wall_group)
  end

  # 独立窗户导入（对应门的import_independent_door）
  def self.import_independent_window(window_data, parent_group)
    # 使用现有Utils方法处理点
    position = Utils.validate_and_create_point(window_data["position"])
    
    if !position
      puts "警告: 独立窗户位置无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户尺寸（与独立门尺寸处理一致）
    size = window_data["size"] || []
    # SketchUp 2024建筑毫米模式，直接使用毫米单位
    width = Utils.parse_number(size[0]) || 800.0
    height = Utils.parse_number(size[1]) || 200.0
    depth = Utils.parse_number(size[2]) || 50.0
    
    # 尺寸有效性检查（与门的防护一致）
    width = 800.0 if width <= 0
    height = 200.0 if height <= 0
    depth = 50.0 if depth <= 0
    
    # 创建窗户组（与独立门组创建一致）
    window_group = parent_group.entities.add_group
    window_group.name = window_data["name"] || "独立窗户"
    window_id = window_data["id"] || "window_#{rand(1000..9999)}"
    
    # 创建窗户基础顶点（与独立门顶点逻辑一致）
    points = [
      position,
      position + Geom::Vector3d.new(width, 0, 0),
      position + Geom::Vector3d.new(width, 0, height),
      position + Geom::Vector3d.new(0, 0, height)
    ]
    
    # 应用旋转（与门的旋转处理一致）
    orientation = Utils.parse_number(window_data["orientation"] || 0.0)
    if orientation != 0
      rotation = Geom::Transformation.rotation(position, Geom::Vector3d.new(0, 0, 1), orientation * Math::PI / 180)
      points.map! { |p| p.transform(rotation) }
    end
    
    # 创建窗户面并拉伸（与门的几何体创建一致）
    window_face = window_group.entities.add_face(points)
    if window_face
      window_face.pushpull(depth)
      set_material(window_group, window_id)  # 复用现有材质方法
      puts "创建独立窗户成功: #{window_group.name}"
    else
      puts "警告: 独立窗户面创建失败"
      window_group.erase!
    end
  end

  # 创建窗户几何体（在开口处）
  def self.create_window_geometry(wall_data, window_data, start_point_bottom, end_point_bottom, start_point_top, end_point_top, parent_group)
    window_group = parent_group.entities.add_group
    window_id = window_data["id"] || "window_#{rand(1000..9999)}"
    window_group.name = "窗户_#{window_id}"
    
    # 计算窗户宽度和高度
    window_width = (end_point_bottom - start_point_bottom).length
    window_height = (start_point_top - start_point_bottom).length
    
    # 获取墙体厚度
    wall_thickness = Utils.parse_number(wall_data["thickness"]) || 200.0
    
    # 计算墙体法线方向
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    wall_vector = wall_end - wall_start
    wall_normal = wall_vector.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    wall_normal = wall_normal.reverse if wall_normal.x < 0
    
    # 根据墙体厚度决定玻璃位置
    if wall_thickness <= 1.0
      # 零厚度墙体：直接在墙体位置创建玻璃面
      glass_corners = [
        start_point_bottom,  # 左下
        end_point_bottom,    # 右下
        end_point_top,       # 右上
        start_point_top      # 左上
      ]
      glass_position = "wall_surface"
    else
      # 正常厚度墙体：在洞的中间厚度处创建玻璃面
      middle_offset = wall_thickness / 2.0
      glass_corners = [
        start_point_bottom.offset(wall_normal, middle_offset),  # 左下
        end_point_bottom.offset(wall_normal, middle_offset),    # 右下
        end_point_top.offset(wall_normal, middle_offset),       # 右上
        start_point_top.offset(wall_normal, middle_offset)      # 左上
      ]
      glass_position = "middle"
    end
    
    # 创建透明玻璃面（只生成一个面，不拉伸成立方体）
    glass_face = window_group.entities.add_face(glass_corners)
    if glass_face
      # 设置玻璃材质
      set_glass_material(glass_face, window_id)
      puts "窗户玻璃面创建成功: #{window_group.name} (位置: #{glass_position})"
    else
      puts "警告: 无法创建窗户玻璃面"
    end
    
    # 设置窗户组属性
    window_group.set_attribute('FactoryImporter', 'window_id', window_id)
    window_group.set_attribute('FactoryImporter', 'window_type', 'window')
    window_group.set_attribute('FactoryImporter', 'window_width', window_width)
    window_group.set_attribute('FactoryImporter', 'window_height', window_height)
    window_group.set_attribute('FactoryImporter', 'wall_thickness', wall_thickness)
    window_group.set_attribute('FactoryImporter', 'glass_position', glass_position)
    
    window_group
  end

  # 辅助方法：创建窗户切割面（用于布尔运算）
  def self.create_window_cut_face(entities, start_point_bottom, end_point_bottom, start_point_top, end_point_top)
    # 创建封闭切割面
    face_points = [start_point_bottom, end_point_bottom, end_point_top, start_point_top]
    entities.add_face(face_points)
  rescue => e
    puts "创建窗户切割面失败: #{e.message}"
    nil
  end

  # 辅助方法：创建窗户切割体（用于正常厚度墙体）
  def self.create_window_cut(entities, start_point_bottom, end_point_bottom, start_point_top, end_point_top, normal, wall_thickness)
    # 计算切割体尺寸 - 确保完全穿透墙体
    cut_depth = wall_thickness + 100.0  # 确保完全穿透墙体
    
    # 创建切割面
    face = create_window_cut_face(entities, start_point_bottom, end_point_bottom, start_point_top, end_point_top)
    return unless face
    
    # 使用布尔运算来精准挖洞
    begin
      # 创建切割体
      cut_face = face.dup
      cut_face.pushpull(cut_depth)
      
      # 找到所有墙体面进行布尔减法运算
      wall_faces = entities.grep(Sketchup::Face)
      wall_faces.each do |wall_face|
        next if wall_face == face || wall_face == cut_face
        
        # 检查是否与切割体相交
        if wall_face.bounds.intersect?(cut_face.bounds)
          begin
            # 执行布尔减法运算来挖洞
            result = wall_face.subtract(cut_face)
            if result
              puts "窗户洞精准挖洞成功"
            end
          rescue => e
            puts "布尔运算失败: #{e.message}"
          end
        end
      end
      
      # 清理切割体
      cut_face.erase! if cut_face.valid?
      face.erase! if face.valid?
      
    rescue => e
      puts "精准挖洞失败: #{e.message}"
      # 如果布尔运算失败，尝试简单的拉伸切割
      begin
        face.pushpull(cut_depth)
        puts "使用简单拉伸挖洞"
      rescue => e2
        puts "简单拉伸也失败: #{e2.message}"
      end
    end
  rescue => e
    puts "创建窗户切割体失败: #{e.message}"
    nil
  end

  # 辅助方法：查找墙体表面（复用门的墙体表面查找逻辑）
  def self.find_wall_face(wall_group, start_point, end_point)
    # 利用Utils的点检查方法优化查找
    wall_group.entities.grep(Sketchup::Face).find do |face|
      !Utils.points_equal?(face.classify_point(start_point), Sketchup::Face::POINT_OUTSIDE) &&
      !Utils.points_equal?(face.classify_point(end_point), Sketchup::Face::POINT_OUTSIDE)
    end
  end

  # 设置框架材质
  def self.set_frame_material(face, window_id)
    # 使用2024版SketchUp自带的金属材质或创建合适的框架材质
    frame_material = Sketchup.active_model.materials["Metal - Aluminum"]
    
    # 如果找不到默认的金属材质，则创建一个合适的框架材质
    unless frame_material
      frame_material = Sketchup.active_model.materials.add("Metal - Aluminum")
      frame_material.color = [192, 192, 192]  # 银灰色
    end
    
    face.material = frame_material
  end

  # 设置玻璃材质
  def self.set_glass_material(face, window_id)
    # 使用2024版SketchUp自带的透明玻璃材质
    glass_material = Sketchup.active_model.materials["Glass - Clear"]
    
    # 如果找不到默认的透明玻璃材质，则创建一个类似的
    unless glass_material
      glass_material = Sketchup.active_model.materials.add("Glass - Clear")
      glass_material.color = [255, 255, 255]  # 纯白色
      glass_material.alpha = 0.3  # 高透明度
    end
    
    # 设置材质
    face.material = glass_material
    face.back_material = glass_material
    
    # 确保玻璃面是透明的
    if glass_material.respond_to?(:alpha)
      glass_material.alpha = 0.3  # 设置透明度为30%
    end
    
    # 确保玻璃面是单面的，不拉伸成立方体
    puts "玻璃材质设置成功，透明度: 30%，类型: 单面"
  end

  # 兼容门模块的材质设置方法
  def self.set_material(group, window_id)
    group.entities.grep(Sketchup::Face).each do |face|
      set_frame_material(face, window_id)
    end
  end
end
