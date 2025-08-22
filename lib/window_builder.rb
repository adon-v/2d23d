# 窗户构建模块：处理窗户的创建和优化
module WindowBuilder
  # 默认参数定义
  DEFAULT_WIDTH = 1000    # 毫米
  DEFAULT_HEIGHT = 1500   # 毫米
  DEFAULT_THICKNESS = 50  # 毫米（仅独立窗户用）
  DEFAULT_HEIGHT_POS = 1500  # 中心点高度（毫米）

  # 统一创建所有窗户
  def self.create_all_windows(window_data_list, parent_group)
    puts "开始创建窗户..."
    window_count = 0
    
    window_data_list.each do |window_item|
      begin
        window_data = window_item[:window_data]
        wall_data = window_item[:wall_data]
        current_parent = window_item[:parent_group]
        
        if wall_data
          # 墙体窗户处理
          wall_id = wall_data["id"] || wall_data["name"] || "未知墙体"
          puts "处理墙体窗户 (墙体ID: #{wall_id}, 窗户ID: #{window_data['id'] || '未知'})"
          
          wall_group = Utils.find_wall_group(current_parent, wall_id)
          if wall_group
            create_wall_window(wall_group, wall_data, window_data)
            window_count += 1
          else
            puts "警告: 未找到墙体 '#{wall_id}'，跳过此窗户"
          end
        else
          # 独立窗户处理
          puts "处理独立窗户 (ID: #{window_data['id'] || '未知'})"
          create_independent_window(window_data, parent_group)
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

  # 在墙体上创建窗户
  def self.create_wall_window(wall_group, wall_data, window_data)
    # 添加调试信息
    puts "=== 调试：原始窗户数据 ==="
    puts "window_data: #{window_data.inspect}"
    puts "size: #{window_data['size'].inspect}"
    puts "position: #{window_data['position'].inspect}"
    puts "height: #{window_data['height'].inspect}"
    
    # 验证数据
    unless validate_window_data(window_data)
      puts "警告: 窗户数据无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end

    # 解析窗户参数
    position = Utils.validate_and_create_point(window_data["position"])
    size = window_data["size"] || []
    height_above_ground = window_data["height"] || DEFAULT_HEIGHT_POS

    if !position || size.size < 2
      puts "警告: 窗户位置或尺寸数据无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end

    # 单位转换：确保所有尺寸都是毫米
    width_mm = normalize_to_millimeters(size[0], DEFAULT_WIDTH)
    height_mm = normalize_to_millimeters(size[1], DEFAULT_HEIGHT)
    height_pos_mm = normalize_to_millimeters(height_above_ground, DEFAULT_HEIGHT_POS)

    puts "窗户参数: 宽度=#{width_mm}mm, 高度=#{height_mm}mm, 离地高度=#{height_pos_mm}mm"

    # 获取墙体信息
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    # 墙体厚度直接使用毫米单位，不需要normalize_to_millimeters
    wall_thickness_mm = Utils.parse_number(wall_data["thickness"]) || 200

    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法创建窗户"
      return
    end

    # 创建窗户
    create_window_on_wall(wall_group, wall_data, window_data, position, width_mm, height_mm, height_pos_mm, wall_thickness_mm)
  end

  # 在墙体上创建窗户（主要方法）
  def self.create_window_on_wall(wall_group, wall_data, window_data, position, width_mm, height_mm, height_pos_mm, wall_thickness_mm)
    puts "=== 开始创建墙体窗户 ==="
    
    model = Sketchup.active_model
    model.start_operation("创建墙体窗户", true)
    
    begin
      # 第一步：计算墙体方向
      wall_start = Utils.validate_and_create_point(wall_data["start"])
      wall_end = Utils.validate_and_create_point(wall_data["end"])
      wall_vector = wall_end - wall_start
      wall_direction = wall_vector.normalize
      
      puts "墙体信息:"
      puts "  起点: #{wall_start.inspect}"
      puts "  终点: #{wall_end.inspect}"
      puts "  方向: #{wall_direction.inspect}"
      
      # 第二步：计算窗户面中心点的3D坐标
      # position已经是米单位（通过Utils.validate_and_create_point处理）
      # height_pos_mm是毫米，需要转换为米
      center_x = position.x
      center_y = position.y
      center_z = height_pos_mm/25.4
      
      window_center_3d = Geom::Point3d.new(center_x, center_y, center_z)
      puts "窗户中心点: #{window_center_3d.inspect} (米)"
      
      # 第三步：根据position、size、height和墙体方向计算窗户面角点
      puts "\n=== 计算窗户面角点 ==="
      window_corners = calculate_window_corners(window_center_3d, width_mm, height_mm, wall_direction)
      
      puts "窗户面角点（初始）:"
      window_corners.each_with_index do |point, i|
        puts "  点#{i+1}: #{point.inspect}"
      end
      
      # 第四步：将窗户面角点投影到墙面上
      puts "\n=== 投影到墙面 ==="
      projected_corners = project_corners_to_wall(window_corners, wall_start, wall_end, wall_direction)
      
      puts "投影后角点:"
      projected_corners.each_with_index do |point, i|
        puts "  点#{i+1}: #{point.inspect}"
      end
      
      # 第五步：在墙面上挖洞
      puts "\n=== 挖洞操作 ==="
      success = create_window_hole(wall_group, projected_corners, wall_thickness_mm)
      
      if success
        puts "窗户洞创建成功！"
        
        # 第六步：在窗洞中心厚度处生成玻璃平面
        puts "\n=== 生成玻璃平面 ==="
        create_glass_plane(wall_group, window_data, projected_corners, wall_thickness_mm)
        
        puts "窗户创建完成！"
      else
        puts "警告: 窗户洞创建失败"
      end
      
      model.commit_operation
      
    rescue => e
      model.abort_operation
      puts "创建窗户失败: #{e.message}"
      puts "错误详情: #{e.backtrace.join("\n")}"
    end
  end

  # 计算窗户面角点坐标
  def self.calculate_window_corners(center, width_mm, height_mm, wall_direction)
    half_width_mm = (width_mm/25.4) / 2
    half_height_mm = (height_mm/25.4) / 2
    
    puts "  窗户尺寸: 半宽=#{half_width_mm}m, 半高=#{half_height_mm}m"
    puts "  原始尺寸: 宽度=#{width_mm}mm, 高度=#{height_mm}mm"
    
    # 计算宽度方向的偏移向量（沿墙体方向）
    width_left_vec = wall_direction.clone
    width_left_vec.length = -half_width_mm
    
    width_right_vec = wall_direction.clone
    width_right_vec.length = half_width_mm
    
    # 计算高度方向的偏移向量（Z轴方向）
    height_down_vec = Geom::Vector3d.new(0, 0, -half_height_mm)
    height_up_vec = Geom::Vector3d.new(0, 0, half_height_mm)
    
    # 计算四个角点（逆时针顺序）
    bottom_left = center + width_left_vec + height_down_vec
    bottom_right = center + width_right_vec + height_down_vec
    top_right = center + width_right_vec + height_up_vec
    top_left = center + width_left_vec + height_up_vec
    
    [bottom_left, bottom_right, top_right, top_left]
  end

  # 将窗户角点投影到墙面上
  def self.project_corners_to_wall(window_corners, wall_start, wall_end, wall_direction)
    wall_vector = wall_end - wall_start
    wall_length = wall_vector.length
    
    if wall_length < 0.001
      puts "警告: 墙体长度过小，无法投影"
      return window_corners
    end
    
    # 检查窗户面是否与墙体方向平行
    window_width_vector = window_corners[1] - window_corners[0]
    window_height_vector = window_corners[3] - window_corners[0]
    
    # 计算窗户面法线
    window_normal = window_width_vector.cross(window_height_vector).normalize
    
    # 检查窗户面是否与墙体方向平行（法线垂直于墙体方向）
    if window_normal.dot(wall_direction).abs < 0.001
      puts "  警告: 窗户面与墙体方向平行，使用特殊投影方法"
      
      # 对于平行的情况，我们需要保持窗户的原始尺寸
      # 计算窗户中心点在墙体上的投影
      window_center = Geom::Point3d.new(
        window_corners.map(&:x).sum / 4.0,
        window_corners.map(&:y).sum / 4.0,
        window_corners.map(&:z).sum / 4.0
      )
      
      # 将窗户中心点投影到墙面上
      # 对于平行的情况，需要将窗户投影到墙面上
      # 计算窗户中心点到墙体的投影
      projected_center = project_point_to_wall(window_center, wall_start, wall_end, wall_direction)
      puts "  窗户中心点投影到墙面: #{projected_center.inspect}"
      
      # 计算窗户的宽度和高度向量
      window_width = window_width_vector.length
      window_height = window_height_vector.length
      
      puts "  窗户尺寸: 宽度=#{window_width}m, 高度=#{window_height}m"
      puts "  窗户宽度向量: #{window_width_vector.inspect}"
      puts "  窗户高度向量: #{window_height_vector.inspect}"
      
      # 检查向量有效性
      if window_width < 0.001 || window_height < 0.001
        puts "  警告: 窗户尺寸过小，使用默认尺寸"
        window_width = 1.0  # 1米
        window_height = 1.0  # 1米
      end
      
      puts "  使用计算尺寸: 宽度=#{window_width}m, 高度=#{window_height}m"
      
      # 在投影中心点周围重建窗户角点
      # 使用计算出的窗户尺寸
      half_width = window_width / 2.0
      half_height = window_height / 2.0
      
      puts "  调试: half_width=#{half_width}, 类型=#{half_width.class}"
      puts "  调试: half_height=#{half_height}, 类型=#{half_height.class}"
      
      # 创建宽度和高度方向的单位向量
      puts "  调试: window_width_vector类型=#{window_width_vector.class}"
      puts "  调试: window_height_vector类型=#{window_height_vector.class}"
      
      width_direction = window_width_vector.normalize
      height_direction = window_height_vector.normalize
      
      puts "  调试: width_direction=#{width_direction.inspect}"
      puts "  调试: height_direction=#{height_direction.inspect}"
      
      # 使用 set_length 方法而不是乘法
      half_width_vec = width_direction.clone
      half_width_vec.length = half_width
      
      half_height_vec = height_direction.clone
      half_height_vec.length = half_height
      
      # 重建四个角点（保持原始尺寸）
      # 使用计算出的尺寸和投影中心点
      bottom_left = projected_center - half_width_vec - half_height_vec
      bottom_right = projected_center + half_width_vec - half_height_vec
      top_right = projected_center + half_width_vec + half_height_vec
      top_left = projected_center - half_width_vec + half_height_vec
      
      puts "  投影中心点: #{projected_center.inspect}"
      puts "  重建的角点:"
      puts "    点1: #{bottom_left.inspect}"
      puts "    点2: #{bottom_right.inspect}"
      puts "    点3: #{top_right.inspect}"
      puts "    点4: #{top_left.inspect}"
      
      return [bottom_left, bottom_right, top_right, top_left]
    else
      # 正常投影
      projected_corners = window_corners.map do |corner|
        project_point_to_wall(corner, wall_start, wall_end, wall_direction)
      end
      
      return projected_corners
    end
  end

  # 将单个点投影到墙体上
  def self.project_point_to_wall(point, wall_start, wall_end, wall_direction)
    wall_vector = wall_end - wall_start
    wall_length = wall_vector.length
    
    # 计算点到墙体的投影
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
    
    # 保持原始的Z坐标（高度）
    Geom::Point3d.new(projected_point.x, projected_point.y, point.z)
  end

  # 在墙面上创建窗户洞
  def self.create_window_hole(wall_group, window_corners, wall_thickness_mm)
    wall_entities = wall_group.entities
    
    # 创建窗户面
    window_face = wall_entities.add_face(window_corners)
    
    unless window_face
      puts "  警告: 无法创建窗户面，点可能共线或无效"
      return false
    end
    
    puts "  窗户面创建成功"
    
    # 计算墙体法线方向（用于确定挖洞方向）
    # 对于这个墙体，方向是Vector3d(0, 1, 0)，所以法线应该是Vector3d(1, 0, 0)
    wall_normal = Geom::Vector3d.new(1, 0, 0)  # 直接使用X轴正方向作为法线
    
    puts "  墙体法线: #{wall_normal.inspect}"
    
    # 沿墙体法线方向挖洞（穿透墙体）
    puts "  调试: wall_thickness_mm=#{wall_thickness_mm}"
    wall_thickness_m = wall_thickness_mm * 0.001
    wall_thickness_inch = wall_thickness_m / 0.0254
    cut_depth = wall_thickness_inch  # 额外1cm确保穿透
    
    puts "  开始挖洞，深度: #{cut_depth}m"
    puts "  墙体厚度: #{wall_thickness_m}m"
    
    # 执行挖洞操作 - 使用pushpull方法
    begin
      # 先尝试正向挖洞
      window_face.pushpull(cut_depth)
      puts "  挖洞操作成功（正向）"
      return true
    rescue => e
      puts "  正向挖洞失败，尝试反向挖洞: #{e.message}"
      begin
        # 如果正向失败，尝试反向挖洞
        window_face.pushpull(-cut_depth)
        puts "  挖洞操作成功（反向）"
        return true
      rescue => e2
        puts "  反向挖洞也失败: #{e2.message}"
        return false
      end
    end
  end

  # 在窗洞中心厚度处生成玻璃平面
  def self.create_glass_plane(wall_group, window_data, window_corners, wall_thickness_mm)
    # 创建窗户组
    window_group = wall_group.entities.add_group
    window_group.name = "Window-Glass-#{window_data['id'] || 'unknown'}"
    
    # 计算墙体法线方向
    wall_direction = (window_corners[1] - window_corners[0]).normalize
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 计算玻璃平面的位置（在墙厚度的中心）
    wall_thickness_m = wall_thickness_mm * 0.001
    wall_thickness_inch = wall_thickness_m / 0.0254
    glass_offset = wall_thickness_inch / 2
    
    puts "  玻璃偏移: #{glass_offset}m"
    
    # 创建玻璃四点（沿墙体法线方向偏移）
    glass_corners = window_corners.map do |corner|
      offset_vector = wall_normal.clone
      offset_vector.length = glass_offset
      corner + offset_vector
    end
    
    # 创建玻璃面
    glass_face = window_group.entities.add_face(glass_corners)
    
    if glass_face
      set_glass_material(glass_face, window_data['id'] || 'unknown')
      
      # 设置窗户组属性
      window_group.set_attribute('FactoryImporter', 'window_id', window_data['id'])
      window_group.set_attribute('FactoryImporter', 'window_name', window_data['name'])
      window_group.set_attribute('FactoryImporter', 'window_type', 'wall_window')
      
      # 存储到实体存储器（独立功能，不影响主流程）
      begin
        if defined?(EntityStorage)
          # 创建窗户实体记录
          window_record = EntityStorage.add_entity("window", window_group, {
            window_id: window_data['id'],
            window_name: window_data['name'],
            window_type: 'wall_window',
            wall_id: wall_group.get_attribute('FactoryImporter', 'wall_id'),
            position: window_data['position'],
            size: window_data['size']
          })
          
          # 建立墙体和窗户的对应关系
          wall_id = wall_group.get_attribute('FactoryImporter', 'wall_id')
          if wall_id
            # 获取刚添加的窗户实体记录
            window_entities = EntityStorage.get_entities_by_type("window")
            window_record = window_entities.find { |record| record[:entity] == window_group }
            if window_record
              EntityStorage.add_wall_window_mapping(wall_id, window_record)
              puts "已建立墙体和窗户对应关系: 墙体ID=#{wall_id}, 窗户=#{window_record[:name]}"
            else
              puts "警告: 无法找到刚创建的窗户实体记录"
            end
          else
            puts "警告: 无法获取墙体ID，无法建立对应关系"
          end
        end
      rescue => e
        puts "警告: 存储窗户实体失败: #{e.message}"
      end
      
      puts "  玻璃平面创建成功"
    else
      puts "  警告: 玻璃平面创建失败"
    end
  end

  # 创建独立窗户
  def self.create_independent_window(window_data, parent_group)
    position = Utils.validate_and_create_point(window_data["position"])
    
    if !position
      puts "警告: 独立窗户位置无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    # 解析尺寸
    size = window_data["size"] || []
    width_mm = normalize_to_millimeters(size[0] || 1000, DEFAULT_WIDTH)
    height_mm = normalize_to_millimeters(size[1] || 1500, DEFAULT_HEIGHT)
    depth_mm = normalize_to_millimeters(size[2] || 100, DEFAULT_THICKNESS)
    
    # 转换为米
    width_m = width_mm * 0.001
    height_m = height_mm * 0.001
    depth_m = depth_mm * 0.001
    
    # 创建窗户组
    window_group = parent_group.entities.add_group
    window_group.name = window_data["name"] || "独立窗户"
    
    # 创建窗户几何体
    points = [
      position,
      position + Geom::Vector3d.new(width_m, 0, 0),
      position + Geom::Vector3d.new(width_m, 0, height_m),
      position + Geom::Vector3d.new(0, 0, height_m)
    ]
    
    # 创建面并拉伸
    window_face = window_group.entities.add_face(points)
    if window_face
      window_face.pushpull(depth_m)
      set_glass_material(window_face, window_data['id'] || 'unknown')
      
      # 设置窗户组属性
      window_group.set_attribute('FactoryImporter', 'window_id', window_data['id'])
      window_group.set_attribute('FactoryImporter', 'window_name', window_data['name'])
      window_group.set_attribute('FactoryImporter', 'window_type', 'independent_window')
      
      # 存储到实体存储器（独立功能，不影响主流程）
      begin
        if defined?(EntityStorage)
          EntityStorage.add_entity("window", window_group, {
            window_id: window_data['id'],
            window_name: window_data['name'],
            window_type: 'independent_window',
            position: window_data['position'],
            size: window_data['size']
          })
        end
      rescue => e
        puts "警告: 存储独立窗户实体失败: #{e.message}"
      end
      
      puts "独立窗户创建成功: #{window_group.name}"
    else
      puts "警告: 创建独立窗户失败"
    end
  end

  # 单位标准化：确保输入值转换为毫米
  def self.normalize_to_millimeters(value, default_mm)
    return default_mm if value.nil?
    
    value_num = Utils.parse_number(value)
    return default_mm if value_num.nil?
    
    # 假设所有JSON数据中的尺寸都是毫米单位
    # 不再进行单位转换，直接返回原值
    puts "  单位保持: #{value_num}mm (JSON数据默认为毫米)"
    value_num
  end

  # 数据验证
  def self.validate_window_data(window_data)
    return false unless window_data.is_a?(Hash)
    
    # 验证ID或名称存在
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
    # 创建自定义玻璃材质
    material_name = "窗户玻璃_#{window_id}"
    material = Sketchup.active_model.materials[material_name]
    
    unless material
      material = Sketchup.active_model.materials.add(material_name)
      material.color = [173, 216, 230]  # 浅蓝色
      material.alpha = 0.5  # 半透明
    end
    
    # 同时设置正面和背面材质，确保两个方向都能看到透明效果
    face.material = material
    face.back_material = material
    puts "已应用自定义玻璃材质: #{material_name}"
    
    # 设置面的属性
    face.set_attribute('FactoryImporter', 'face_type', 'window_glass')
    face.set_attribute('FactoryImporter', 'window_id', window_id)
  end
end
