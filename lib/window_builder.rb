# 窗户构建模块：处理窗户的创建和优化
module WindowBuilder
  # 默认参数定义
  DEFAULT_WIDTH = 1000    # 毫米
  DEFAULT_HEIGHT = 1500   # 毫米
  DEFAULT_THICKNESS = 50  # 毫米（仅独立窗户用）
  DEFAULT_HEIGHT_POS = 1500  # 中心点高度（毫米）

  # 统一创建所有窗户（核心优化：滞后创建窗户，确保墙体已存在）
  def self.create_all_windows(window_data_list, parent_group)
    puts "开始创建窗户..."
    window_count = 0
    
    window_data_list.each do |window_item|
      begin
        window_data = window_item[:window_data]
        wall_data = window_item[:wall_data]
        current_parent = window_item[:parent_group]
        
        # 墙体窗户处理
        if wall_data
          wall_id = wall_data["id"] || wall_data["name"] || "未知墙体"
          puts "处理墙体窗户 (墙体ID: #{wall_id}, 窗户ID: #{window_data['id'] || '未知'})"
          
          # 找到对应的墙体组
          wall_group = Utils.find_wall_group(current_parent, wall_id)
          
          if wall_group
            # 创建窗户开口
            create_window_opening(wall_group, wall_data, window_data, parent_group)
            window_count += 1
          else
            puts "警告: 未找到墙体 '#{wall_id}'，跳过此窗户"
          end
        else
          # 独立窗户处理
          puts "处理独立窗户 (ID: #{window_data['id'] || '未知'})"
          import_independent_window(window_data, parent_group)
          window_count += 1
        end
      rescue => e
        window_id = window_data["id"] || "未知"
        error_msg = "警告: 创建窗户时出错 (ID: #{window_id}): #{Utils.ensure_utf8(e.message)}"
        puts Utils.ensure_utf8(error_msg)
      end
    end
    
    puts "窗户创建完成，共创建 #{window_count} 个窗户"
  end
  
  # 在墙体上创建窗户开口（支持厚度为0的墙体）
  def self.create_window_opening(wall_group, wall_data, window_data, parent_group)
    # 验证窗户数据
    unless validate_window_data(window_data)
      puts "警告: 窗户数据无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户参数
    position = Utils.validate_and_create_point(window_data["position"])
    size = window_data["size"] || []
    height_above_ground = Utils.parse_number(window_data["height"]) || DEFAULT_HEIGHT_POS
    
    if !position || size.size < 2
      puts "警告: 窗户位置或尺寸数据无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户的长宽（毫米）
    width = Utils.parse_number(size[0]) || DEFAULT_WIDTH
    height = Utils.parse_number(size[1]) || DEFAULT_HEIGHT
    
    # 验证尺寸
    width = DEFAULT_WIDTH if width <= 0
    height = DEFAULT_HEIGHT if height <= 0
    height_above_ground = DEFAULT_HEIGHT_POS if height_above_ground <= 0
    
    # 墙体厚度 - 毫米转米
    wall_thickness = Utils.parse_number(wall_data["thickness"]) * 0.001
    wall_thickness = 0.2 if wall_thickness <= 0.001
    
    puts "在墙体上创建窗户开口: 中心点=#{position}, 宽度=#{width}mm, 高度=#{height}mm, 离地高度=#{height_above_ground}mm, 墙体厚度=#{wall_thickness}m"
    
    # 计算墙体的方向
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法创建窗户开口"
      return
    end
    
    # 计算墙体方向向量
    wall_vector = wall_end - wall_start
    if wall_vector.length < 0.001
      puts "警告: 墙体向量长度过小，无法创建窗户开口"
      return
    end
    
    # 根据墙体厚度处理不同情况
    if wall_thickness <= 0.001
      # 厚度为0的墙体处理
      create_window_on_zero_thickness_wall(wall_group, wall_data, window_data, position, width, height, height_above_ground)
    else
      # 正常厚度墙体处理
      create_window_on_normal_wall(wall_group, wall_data, window_data, position, width, height, height_above_ground, wall_thickness)
    end
  end
  
  # 在厚度为0的墙体上创建窗户
  def self.create_window_on_zero_thickness_wall(wall_group, wall_data, window_data, center_position, width, height, height_above_ground)
    wall_entities = wall_group.entities
    
    # 计算墙体的方向
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法在零厚度墙体上创建窗户"
      return
    end
    
    # 计算墙体方向向量
    wall_vector = wall_end - wall_start
    
    # 检查墙体向量有效性
    wall_direction = nil
    if wall_vector.length >= 0.001
      wall_direction = wall_vector.normalize
    else
      # 如果墙体向量无效，使用默认方向（水平向右）
      wall_direction = Geom::Vector3d.new(1, 0, 0)
      puts "警告: 墙体向量无效，使用默认方向"
    end
    
    # 计算窗户的四个端点坐标（毫米转米）
    half_width = (width * 0.001) / 2
    half_height = (height * 0.001) / 2
    center_z = (height_above_ground * 0.001) + half_height
    
    # 计算窗户中心点（投影到墙体上）
    projected_center = project_point_to_wall(center_position, wall_start, wall_end)
    
    # 计算窗户的四个角点
    window_points = calculate_window_corners(projected_center, wall_direction, half_width, half_height, center_z)
    
    # 找到墙体的面（单面墙只有一个面）
    wall_face = wall_entities.grep(Sketchup::Face).find { |f| 
      normal = f.normal
      (normal.z.abs < 0.001) && !f.deleted?
    }
    
    if !wall_face
      puts "警告: 未找到墙体面，无法创建窗户开口"
      return
    end
    
    # 创建窗户组
    window_group = wall_group.entities.add_group
    window_group.name = "Window-#{window_data['id'] || 'unknown'}"
    
    # 在窗户的位置创建一个新面
    begin
      window_face = window_group.entities.add_face(window_points)
      
      if window_face
        # 设置窗户的材质（玻璃材质）
        set_glass_material(window_face, window_data['id'] || 'unknown')
        puts "在厚度为0的墙体上创建窗户成功，窗户点: #{window_points.inspect}"
      else
        puts "警告: 创建窗户的面失败，点可能共线或无效"
        puts "  窗户点: #{window_points.inspect}"
      end
    rescue Exception => e
      puts "警告: 创建窗户时出错: #{e.message}"
      puts "  窗户点: #{window_points.inspect}"
    end
  end
  
  # 在正常厚度墙体上创建窗户 - 使用智能投影方法
  def self.create_window_on_normal_wall(wall_group, wall_data, window_data, center_position, width, height, height_above_ground, wall_thickness)
    model = Sketchup.active_model
    model.start_operation("创建墙体窗户", true)
  
    # 获取墙体坐标
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
  
    unless wall_start && wall_end
      puts "[DEBUG] wall_start: #{wall_start.inspect}, wall_end: #{wall_end.inspect}"
      puts "警告: 墙体坐标无效，无法创建窗户"
      model.abort_operation
      return
    end
  
    puts "=== 智能窗户生成 ==="
    puts "墙体起点: #{wall_start.inspect}"
    puts "墙体终点: #{wall_end.inspect}"
    puts "窗户中心点: #{center_position.inspect}"
    puts "窗户尺寸: #{width}mm x #{height}mm"
    puts "离地高度: #{height_above_ground}mm"
    
    # 智能投影：将窗户中心点投影到墙体上
    puts "\n=== 坐标投影阶段 ==="
    projected_center = project_point_to_wall(center_position, wall_start, wall_end)
    puts "投影后窗户中心点: #{projected_center.inspect}"
    
    # 计算墙体方向向量
    wall_vector = wall_end - wall_start
    wall_direction = wall_vector.normalize
    
    # 计算窗户的四个端点坐标（毫米转米）
    half_width = (width * 0.001) / 2
    half_height = (height * 0.001) / 2
    center_z = (height_above_ground * 0.001) + half_height
    
    # 计算窗户的四个角点
    window_points = calculate_window_corners(projected_center, wall_direction, half_width, half_height, center_z)
    
    puts "\n=== 窗户四点计算 ==="
    puts "窗户四点:"
    window_points.each_with_index do |point, i|
      puts "  点#{i+1}: #{point.inspect}"
    end
    
    # 计算墙体法线方向
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 计算窗户洞的地面四点坐标
    puts "\n=== 窗户洞四点计算 ==="
    ground_points = calculate_window_ground_points(window_points[0], window_points[1], wall_thickness)
    
    puts "窗户洞地面四点:"
    ground_points.each_with_index do |point, i|
      puts "  点#{i+1}: #{point.inspect}"
    end
    
    # 创建窗户洞面
    wall_entities = wall_group.entities
    window_base_face = wall_entities.add_face(ground_points)
    
    if window_base_face
      puts "窗户洞面创建成功"
      
      # 沿Z轴正方向挖洞
      window_height = height * 0.001  # 毫米转米
      puts "开始沿Z轴正方向挖洞，高度: #{window_height}米"
      window_base_face.pushpull(window_height / 0.0254)
      
      puts "窗户洞生成完成！"
      puts "窗户高度: #{window_height}米"
      puts "窗户洞深度: #{wall_thickness * 0.0254}米"
      
      # 在墙厚度的中心位置生成玻璃材质的窗户平面
      create_window_glass_plane(wall_group, window_data, window_points, wall_thickness)
    else
      puts "警告: 窗户洞面创建失败"
      puts "  地面四点: #{ground_points.inspect}"
    end
  
    model.commit_operation
  rescue => e
    model.abort_operation if model
    puts "创建窗户失败: #{Utils.ensure_utf8(e.message)}"
    puts "错误详情: #{e.backtrace.join("\n")}"
  end
  
  # 将点投影到墙体上
  def self.project_point_to_wall(point, wall_start, wall_end)
    wall_vector = wall_end - wall_start
    wall_length = wall_vector.length
    
    if wall_length < 0.001
      puts "警告: 墙体长度过小，无法投影"
      return point
    end
    
    # 计算点到墙体的投影
    wall_direction = wall_vector.normalize
    point_to_wall_start = point - wall_start
    
    # 计算投影参数 t (0 <= t <= 1 表示在墙体上)
    t = point_to_wall_start.dot(wall_direction) / wall_length
    
    # 限制投影点在墙体范围内
    t = [0.0, [t, 1.0].min].max
    
    # 计算投影点
    projection_distance = t * wall_length
    projection_vector = wall_direction.clone
    projection_vector.length = projection_distance
    projected_point = wall_start + projection_vector
    
    puts "  原始点: #{point.inspect}"
    puts "  投影参数 t: #{t}"
    puts "  投影距离: #{projection_distance}"
    puts "  投影点: #{projected_point.inspect}"
    
    projected_point
  end
  
  # 计算窗户的四个角点
  def self.calculate_window_corners(center, wall_direction, half_width, half_height, center_z)
    # 计算窗户的四个角点（逆时针顺序）
    bottom_left = center + wall_direction * (-half_width) + Geom::Vector3d.new(0, 0, center_z - half_height)
    bottom_right = center + wall_direction * half_width + Geom::Vector3d.new(0, 0, center_z - half_height)
    top_right = center + wall_direction * half_width + Geom::Vector3d.new(0, 0, center_z + half_height)
    top_left = center + wall_direction * (-half_width) + Geom::Vector3d.new(0, 0, center_z + half_height)
    
    [bottom_left, bottom_right, top_right, top_left]
  end
  
  # 计算窗户洞地面四点坐标
  def self.calculate_window_ground_points(start_point, end_point, wall_thickness)
    # 计算墙体方向向量
    wall_vector = end_point - start_point
    wall_direction = wall_vector.normalize
    
    # 计算墙体法线（垂直于墙体方向和向上方向）
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 计算厚度向量
    thickness_vec = wall_normal.clone
    thickness_vec.length = wall_thickness
    
    # 计算窗户洞地面四点（逆时针顺序）
    ground_points = [
      start_point,                                    # 点1：起点
      start_point + thickness_vec,                    # 点2：起点+厚度
      end_point + thickness_vec,                      # 点3：终点+厚度
      end_point                                       # 点4：终点
    ]
    
    puts "  墙体方向: #{wall_direction.inspect}"
    puts "  墙体法线: #{wall_normal.inspect}"
    puts "  厚度向量: #{thickness_vec.inspect}"
    
    ground_points
  end
  
  # 在墙厚度的中心位置生成玻璃材质的窗户平面
  def self.create_window_glass_plane(wall_group, window_data, window_points, wall_thickness)
    # 创建窗户组
    window_group = wall_group.entities.add_group
    window_group.name = "Window-Glass-#{window_data['id'] || 'unknown'}"
    
    # 计算墙体法线方向（用于确定玻璃平面的位置）
    wall_direction = (window_points[1] - window_points[0]).normalize
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 计算玻璃平面的位置（在墙厚度的中心）
    glass_offset = wall_thickness / 2
    glass_points = window_points.map do |point|
      point + wall_normal * glass_offset
    end
    
    # 创建玻璃面
    begin
      glass_face = window_group.entities.add_face(glass_points)
      
      if glass_face
        # 设置玻璃材质
        set_glass_material(glass_face, window_data['id'] || 'unknown')
        puts "玻璃平面创建成功，位置偏移: #{glass_offset}米"
      else
        puts "警告: 玻璃平面创建失败"
        puts "  玻璃点: #{glass_points.inspect}"
      end
    rescue Exception => e
      puts "警告: 创建玻璃平面时出错: #{e.message}"
      puts "  玻璃点: #{glass_points.inspect}"
    end
  end
  
  # 导入独立窗户（非墙体上的窗户）
  def self.import_independent_window(window_data, parent_group)
    position = Utils.validate_and_create_point(window_data["position"])
    
    if !position
      puts "警告: 独立窗户位置无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 提取窗户的尺寸
    size = window_data["size"] || []
    width = Utils.parse_number(size[0] || 1.0)
    height = Utils.parse_number(size[1] || 2.0)
    depth = Utils.parse_number(size[2] || 0.1)
    
    # 确保尺寸有效
    width = 1.0 if width <= 0
    height = 2.0 if height <= 0
    depth = 0.1 if depth <= 0
    
    # 创建窗户组
    window_group = parent_group.entities.add_group
    window_group.name = window_data["name"] || "独立窗户"
    
    # 创建窗户的四个角点
    points = [
      position,
      position + Geom::Vector3d.new(width, 0, 0),
      position + Geom::Vector3d.new(width, 0, height),
      position + Geom::Vector3d.new(0, 0, height)
    ]
    
    # 应用旋转（如果有）
    orientation = Utils.parse_number(window_data["orientation"] || 0.0)
    if orientation != 0
      rotation = Geom::Transformation.rotation(position, Geom::Vector3d.new(0, 0, 1), orientation * Math::PI / 180)
      points.map! { |p| p.transform(rotation) }
    end
    
    # 创建窗户的面并拉伸
    window_face = window_group.entities.add_face(points)
    if window_face
      window_face.pushpull(depth)
      set_glass_material(window_face, window_data['id'] || 'unknown')
    end
    
    puts "创建独立窗户成功: #{window_group.name}"
  end
  
  # 数据验证
  def self.validate_window_data(window_data)
    return false unless window_data.is_a?(Hash)
    
    # 验证ID或名称存在（至少一个标识）
    unless window_data['id'] || window_data['name']
      puts "警告: 窗户数据缺少ID和名称，跳过"
      return false
    end
    
    # 验证基本数据
    if window_data['position'].nil? || window_data['size'].nil?
      puts "警告: 窗户数据缺少位置或尺寸信息 (ID: #{window_data['id'] || '未知'})"
      return false
    end
    
    true
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
end
