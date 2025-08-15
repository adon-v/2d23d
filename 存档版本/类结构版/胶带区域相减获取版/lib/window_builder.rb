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
    # 提取窗户尺寸数据（与门的尺寸提取一致）
    dimensions = window_data["size"] || []
    
    # 验证窗户尺寸数据（与门的验证逻辑一致）
    if dimensions.size < 2
      puts "警告: 窗户尺寸数据不足，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户的起点和终点（使用现有Utils方法）
    start_point = Utils.validate_and_create_point(dimensions[0])
    end_point = Utils.validate_and_create_point(dimensions[1])
    
    if !start_point || !end_point
      puts "警告: 窗户坐标无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户的高度 - 毫米转米（与门的单位转换一致）
    height = Utils.parse_number(window_data["height"]) || DEFAULT_HEIGHT
    height = height * 0.001  # 毫米转米
    height = 1.5 if height <= 0  # 窗户默认高度低于门
    
    # 墙体厚度处理（与门的厚度逻辑一致）
    wall_thickness = Utils.parse_number(wall_data["thickness"]) || 200
    wall_thickness = wall_thickness * 0.001  # 毫米转米
    wall_thickness = 0.2 if wall_thickness <= 0.001
    
    puts "在墙体上创建窗户开口: 起点=#{start_point}, 终点=#{end_point}, 高度=#{height.round(2)}m, 墙体厚度=#{wall_thickness.round(2)}m"
    
    # 计算墙体的方向（复用门的墙体方向计算）
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法创建窗户开口"
      return
    end
    
    # 根据墙体厚度处理不同情况（与门的厚度分支一致）
    if wall_thickness <= 0.001
      create_window_on_zero_thickness_wall(wall_group, wall_data, window_data, start_point, end_point, height)
    else
      create_window_on_normal_wall(wall_group, wall_data, window_data, start_point, end_point, height)
    end
  end

  # 零厚度墙体窗户处理（对应门的create_door_on_zero_thickness_wall）
  def self.create_window_on_zero_thickness_wall(wall_group, wall_data, window_data, start_point, end_point, height)
    wall_entities = wall_group.entities
    model = Sketchup.active_model
    model.start_operation("创建零厚度墙体窗户", true)
    
    # 计算窗户平面（与门的平面计算一致）
    face = find_wall_face(wall_group, start_point, end_point)
    unless face
      puts "警告: 未找到墙体表面，无法创建窗户"
      model.abort_operation
      return
    end
    
    # 创建窗户开口（布尔运算，与门的开口逻辑一致）
    window_face = create_window_cut_face(wall_entities, start_point, end_point, height)
    if window_face && face.intersect(window_face)
      window_face.erase!
      puts "零厚度墙体窗户开口创建成功"
    else
      puts "警告: 零厚度墙体窗户开口创建失败"
      model.abort_operation
    end
    
    model.commit_operation
    # 创建窗户几何体（在开口处）
    create_window_geometry(wall_data, window_data, start_point, end_point, height, wall_group)
  end

  # 正常厚度墙体窗户处理（对应门的create_door_on_normal_wall）
  def self.create_window_on_normal_wall(wall_group, wall_data, window_data, start_point, end_point, height)
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
    if wall_vector.length < 0.001
      puts "警告: 墙体向量长度过小，无法创建窗户"
      model.abort_operation
      return
    end
  
    # 计算墙体法线（与门的法线逻辑一致）
    wall_normal = wall_vector.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    wall_normal = wall_normal.reverse if wall_normal.x < 0
  
    # 窗户宽度验证（与门的宽度处理一致）
    window_vector = end_point - start_point
    window_width = window_vector.length
    if window_width < 0.001
      puts "警告: 窗户宽度过小，使用默认值0.8米"
      window_width = 0.8
      window_center = Geom::Point3d.new(
        (start_point.x + end_point.x) / 2,
        (start_point.y + end_point.y) / 2,
        (start_point.z + end_point.z) / 2
      )
      window_direction = wall_vector.normalize
      start_point = window_center - window_direction * (window_width / 2)
      end_point = window_center + window_direction * (window_width / 2)
    end
  
    # 创建窗户开口（与门的开口逻辑一致）
    create_window_cut(wall_group.entities, start_point, end_point, height, wall_normal, wall_data["thickness"])
    
    model.commit_operation
    # 创建窗户几何体
    create_window_geometry(wall_data, window_data, start_point, end_point, height, wall_group)
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
    width = Utils.parse_number(size[0] || DEFAULT_WIDTH)
    height = Utils.parse_number(size[1] || DEFAULT_HEIGHT)
    depth = Utils.parse_number(size[2] || DEFAULT_THICKNESS)
    
    # 尺寸有效性检查（与门的防护一致）
    width = DEFAULT_WIDTH if width <= 0
    height = DEFAULT_HEIGHT if height <= 0
    depth = DEFAULT_THICKNESS if depth <= 0
    
    # 创建窗户组（与独立门组创建一致）
    window_group = parent_group.entities.add_group
    window_group.name = window_data["name"] || "独立窗户"
    window_id = window_data["id"] || "window_#{rand(1000..9999)}"
    
    # 创建窗户基础顶点（与独立门顶点逻辑一致）
    points = [
      position,
      position + Geom::Vector3d.new(width/1000.0, 0, 0),
      position + Geom::Vector3d.new(width/1000.0, 0, height/1000.0),
      position + Geom::Vector3d.new(0, 0, height/1000.0)
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
      window_face.pushpull(depth/1000.0)
      set_material(window_group, window_id)  # 复用现有材质方法
      puts "创建独立窗户成功: #{window_group.name}"
    else
      puts "警告: 独立窗户面创建失败"
      window_group.erase!
    end
  end

  # 创建窗户几何体（在开口处）
  def self.create_window_geometry(wall_data, window_data, start_point, end_point, height, parent_group)
    window_group = parent_group.entities.add_group
    window_id = window_data["id"] || "window_#{rand(1000..9999)}"
    window_group.name = "窗户_#{window_id}"
    
    # 计算窗户宽度
    window_width = (end_point - start_point).length
    
    # 创建窗户框架顶点
    frame_thickness = 0.1  # 框架厚度（米）
    glass_thickness = 0.01 # 玻璃厚度（米）
    
    # 底部框架顶点
    bottom_frame = [
      start_point,
      end_point,
      end_point + Geom::Vector3d.new(0, frame_thickness, 0),
      start_point + Geom::Vector3d.new(0, frame_thickness, 0)
    ]
    
    # 顶部框架顶点
    top_frame = bottom_frame.map { |p| p + Geom::Vector3d.new(0, 0, height) }
    
    # 左侧框架顶点
    left_frame = [
      start_point,
      start_point + Geom::Vector3d.new(0, frame_thickness, 0),
      top_frame[3],
      top_frame[0]
    ]
    
    # 右侧框架顶点
    right_frame = [
      end_point,
      end_point + Geom::Vector3d.new(0, frame_thickness, 0),
      top_frame[2],
      top_frame[1]
    ]
    
    # 玻璃顶点（稍微向内偏移）
    glass_offset = 0.01
    glass_points = [
      start_point + Geom::Vector3d.new(glass_offset, frame_thickness + glass_thickness, glass_offset),
      end_point - Geom::Vector3d.new(glass_offset, 0, glass_offset) + Geom::Vector3d.new(0, frame_thickness + glass_thickness, 0),
      end_point - Geom::Vector3d.new(glass_offset, 0, 0) + Geom::Vector3d.new(0, frame_thickness + glass_thickness, height - glass_offset),
      start_point + Geom::Vector3d.new(glass_offset, frame_thickness + glass_thickness, height - glass_offset)
    ]
    
    # 创建框架面
    [bottom_frame, top_frame, left_frame, right_frame].each do |points|
      face = window_group.entities.add_face(points)
      face.pushpull(glass_thickness) if face
    end
    
    # 创建玻璃面
    glass_face = window_group.entities.add_face(glass_points)
    if glass_face
      glass_face.pushpull(glass_thickness)
      set_glass_material(glass_face, window_id)
    end
    
    # 设置框架材质
    window_group.entities.grep(Sketchup::Face).each do |face|
      next if face == glass_face
      set_frame_material(face, window_id)
    end
    
    window_group
  end

  # 辅助方法：创建窗户切割面（用于布尔运算）
  def self.create_window_cut_face(entities, start_point, end_point, height)
    # 计算窗户底部和顶部点（与门的切割逻辑一致）
    bottom_points = [start_point, end_point]
    top_points = bottom_points.map { |p| Geom::Point3d.new(p.x, p.y, p.z + height) }
    
    # 创建封闭切割面（与门的切割面一致）
    face_points = bottom_points + top_points.reverse
    entities.add_face(face_points)
  rescue => e
    puts "创建窗户切割面失败: #{e.message}"
    nil
  end

  # 辅助方法：创建窗户切割体（用于正常厚度墙体）
  def self.create_window_cut(entities, start_point, end_point, height, normal, wall_thickness)
    # 计算切割体尺寸
    cut_depth = (wall_thickness.to_f * 0.001) + 0.02  # 稍微超出墙体厚度
    
    # 创建切割面
    face = create_window_cut_face(entities, start_point, end_point, height)
    return unless face
    
    # 沿法线方向拉伸切割面
    face.pushpull(normal.reverse.length * cut_depth)
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
    material_name = "窗户框架_#{window_id}"
    material = Sketchup.active_model.materials[material_name]
    
    unless material
      material = Sketchup.active_model.materials.add(material_name)
      material.color = [139, 69, 19]  # 棕色
    end
    
    face.material = material
  end

  # 设置玻璃材质
  def self.set_glass_material(face, window_id)
    material_name = "窗户玻璃_#{window_id}"
    material = Sketchup.active_model.materials[material_name]
    
    unless material
      material = Sketchup.active_model.materials.add(material_name)
      material.color = [173, 216, 230]  # 浅蓝色
      material.alpha = 0.6  # 半透明
    end
    
    face.material = material
  end

  # 兼容门模块的材质设置方法
  def self.set_material(group, window_id)
    group.entities.grep(Sketchup::Face).each do |face|
      set_frame_material(face, window_id)
    end
  end
end
