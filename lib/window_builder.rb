# 窗户构建模块：处理窗户的创建和优化
module WindowBuilder
  # 默认参数定义（英寸）
  DEFAULT_WIDTH = 39.37      # 1000mm -> 39.37英寸
  DEFAULT_HEIGHT = 59.06     # 1500mm -> 59.06英寸
  DEFAULT_THICKNESS = 1.97   # 50mm -> 1.97英寸（仅独立窗户用）
  DEFAULT_HEIGHT_POS = 59.06 # 1500mm -> 59.06英寸（中心点高度）

  # 统一创建所有窗户
  def self.create_all_windows(window_data_list, parent_group)
    puts "=== 开始创建窗户 ==="
    puts "输入数据: #{window_data_list.length} 个窗户"
    puts "父组: #{parent_group.name rescue '未知'}"
    puts "父组类型: #{parent_group.class}"
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

    # 统一单位转换：毫米 -> 英寸
    width_inches = normalize_to_inches(size[0], DEFAULT_WIDTH)
    height_inches = normalize_to_inches(size[1], DEFAULT_HEIGHT)
    height_pos_inches = normalize_to_inches(height_above_ground, DEFAULT_HEIGHT_POS)

    # 获取墙体信息
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    # 墙体厚度转换为英寸
    wall_thickness_inches = normalize_to_inches(wall_data["thickness"], 7.87) # 200mm -> 7.87英寸

    puts "=== 窗户关键参数信息 ==="
    puts "窗户ID: #{window_data['id'] || '未知'}"
    puts "窗户名称: #{window_data['name'] || '未知'}"
    puts "原始position数据: #{window_data['position'].inspect}"
    puts "转换后position对象: #{position.inspect}"
    puts "窗户XY坐标: X=#{position.x.round(6)}m, Y=#{position.y.round(6)}m"
    puts "窗户尺寸: 宽度=#{width_inches.round(3)}英寸 (#{(width_inches*25.4).round(1)}mm), 高度=#{height_inches.round(3)}英寸 (#{(height_inches*25.4).round(1)}mm)"
    puts "窗户离地高度: #{height_pos_inches.round(3)}英寸 (#{(height_pos_inches*25.4).round(1)}mm)"
    puts "墙体厚度: #{wall_thickness_inches.round(3)}英寸 (#{(wall_thickness_inches*25.4).round(1)}mm)"

    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法创建窗户"
      return
    end

    puts "墙体起点: #{wall_start.inspect}"
    puts "墙体终点: #{wall_end.inspect}"
    puts "墙体长度: #{(wall_end - wall_start).length.round(3)}m"

    # 创建窗户
    create_window_on_wall(wall_group, wall_data, window_data, position, width_inches, height_inches, height_pos_inches, wall_thickness_inches)
  end

  # 在墙体上创建窗户（主要方法）
  def self.create_window_on_wall(wall_group, wall_data, window_data, position, width_inches, height_inches, height_pos_inches, wall_thickness_inches)
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
      # position已经是英寸单位（通过Utils.validate_and_create_point处理，毫米转英寸）
      # height_pos_inches是英寸，表示窗户下表面到地面的距离
      # height_inches是英寸，表示窗户本身的垂直高度
      center_x = position.x
      center_y = position.y
      
      # 计算窗户中心点的Z坐标（英寸）
      # 窗户中心点Z坐标 = 离地高度 + 窗户高度的一半
      center_z = height_pos_inches + (height_inches / 2.0)
      
      window_center_3d = Geom::Point3d.new(center_x, center_y, center_z)
      puts "=== 窗户3D中心点计算 ==="
      puts "原始XY坐标: X=#{center_x.round(6)}m, Y=#{center_y.round(6)}m"
      puts "窗户离地高度: #{height_pos_inches.round(3)}英寸"
      puts "窗户高度: #{height_inches.round(3)}英寸"
      puts "窗户中心点Z坐标: #{center_z.round(3)}英寸 (离地高度 + 窗户高度/2)"
      puts "原始3D中心点: #{window_center_3d.inspect}"
      puts "原始中心点类型: #{window_center_3d.class}"
      puts "原始中心点坐标: X=#{window_center_3d.x.round(6)}m, Y=#{window_center_3d.y.round(6)}m, Z=#{window_center_3d.z.round(3)}英寸"
      
      # 将窗户中心点移动到墙体中线上
      puts "\n=== 将窗户中心点移动到墙体中线 ==="
      # 计算窗户中心点到墙体中线的垂直投影
      window_to_wall_start = window_center_3d - wall_start
      t = window_to_wall_start.dot(wall_direction) / wall_vector.length
      t = [0.0, [t, 1.0].min].max  # 限制在墙体范围内
      
      puts "投影参数 t: #{t.round(6)} (0=起点, 1=终点)"
      
      # 计算窗户中心点在墙体中线上的投影点
      projection_distance = t * wall_vector.length
      projection_vector = wall_direction.clone
      projection_vector.length = projection_distance
      projected_center_midline = wall_start + projection_vector
      
      # 关键修复：恢复在投影过程中丢失的Z坐标
      projected_center_midline.z = center_z
      
      puts "窗户中心点投影到墙体中线 (已修正Z坐标): #{projected_center_midline.inspect}"
      
      # 计算窗户在墙体中线上应该偏移的距离
      # 窗户应该居中于投影点，所以偏移距离是窗户宽度的一半
      half_window_width = width_inches / 2.0  # 使用英寸值
      
      # 计算窗户在墙体中线上偏移后的最终中心点
      if t == 0.0
        # 窗户在墙体起点附近，向右偏移
        offset_vector = wall_direction.clone
        offset_vector.length = half_window_width
        final_center = projected_center_midline + offset_vector
        puts "窗户在墙体起点附近，向右偏移到: #{final_center.inspect}"
      elsif t == 1.0
        # 窗户在墙体终点附近，向左偏移
        offset_vector = wall_direction.clone
        offset_vector.length = half_window_width
        final_center = projected_center_midline - offset_vector
        puts "窗户在墙体终点附近，向左偏移到: #{final_center.inspect}"
      else
        # 窗户在墙体中间，居中放置
        final_center = projected_center_midline
        puts "窗户在墙体中间，居中放置: #{final_center.inspect}"
      end
      
      puts "最终3D中心点: #{final_center.inspect}"
      puts "最终中心点坐标: X=#{final_center.x.round(6)}m, Y=#{final_center.y.round(6)}m, Z=#{final_center.z.round(6)}m"
      
      # 第三步：根据变换后的中心点计算窗户面角点（此时角点位于墙体中线）
      puts "\n=== 计算窗户面角点（墙体中线） ==="
      centerline_corners = calculate_window_corners(final_center, width_inches, height_inches, wall_direction)
      
      puts "窗户面角点（中线）:"
      centerline_corners.each_with_index do |point, i|
        puts "  点#{i+1}: #{point.inspect}"
      end
      
      # 第四步：将窗户面角点平移到墙体表面
      puts "\n=== 平移角点到墙面 ==="
      surface_corners = project_corners_to_wall(centerline_corners, wall_start, wall_end, wall_direction, wall_thickness_inches)
      
      puts "平移后角点（墙面）:"
      surface_corners.each_with_index do |point, i|
        puts "  点#{i+1}: #{point.inspect} (X=#{point.x.round(6)}m, Y=#{point.y.round(6)}m, Z=#{point.z.round(6)}m)"
      end
      
      # 计算投影后的窗户尺寸
      if surface_corners.length >= 4
        width_vector = surface_corners[1] - surface_corners[0]
        height_vector = surface_corners[3] - surface_corners[0]
        projected_width = width_vector.length
        projected_height = height_vector.length
        
        puts "=== 墙面窗户尺寸 ==="
        puts "  宽度: #{projected_width.round(6)}m"
        puts "  高度: #{projected_height.round(6)}m"
        puts "  宽度向量: #{width_vector.inspect}"
        puts "  高度向量: #{height_vector.inspect}"
      end
      
      # 第五步：在墙面上挖洞
      puts "\n=== 挖洞操作 ==="
      success = create_window_hole(wall_group, surface_corners, wall_direction, wall_thickness_inches)
      
      if success
        puts "窗户洞创建成功！"
        
        # 第六步：在窗洞中心厚度处生成玻璃平面
        puts "\n=== 生成玻璃平面 ==="
        create_glass_plane(wall_group, window_data, surface_corners, wall_direction, wall_thickness_inches)
        
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
  def self.calculate_window_corners(center, width_inches, height_inches, wall_direction)
    puts "=== 窗户角点计算详情 ==="
    puts "  输入中心点: #{center.inspect}"
    puts "  墙体方向向量: #{wall_direction.inspect}"
    puts "  墙体方向长度: #{wall_direction.length.round(6)}"
    
    half_width_inches = width_inches / 2
    half_height_inches = height_inches / 2
    
    puts "  窗户尺寸: 半宽=#{half_width_inches}英寸, 半高=#{half_height_inches}英寸"
    puts "  原始尺寸: 宽度=#{width_inches}英寸, 高度=#{height_inches}英寸"
    
    # 计算宽度方向的偏移向量（沿墙体方向）
    width_left_vec = wall_direction.clone
    width_left_vec.length = -half_width_inches
    
    width_right_vec = wall_direction.clone
    width_right_vec.length = half_width_inches
    
    puts "  宽度偏移向量: 左=#{width_left_vec.inspect}, 右=#{width_right_vec.inspect}"
    
    # 计算高度方向的偏移向量（Z轴方向）
    height_down_vec = Geom::Vector3d.new(0, 0, -half_height_inches)
    height_up_vec = Geom::Vector3d.new(0, 0, half_height_inches)
    
    puts "  高度偏移向量: 下=#{height_down_vec.inspect}, 上=#{height_up_vec.inspect}"
    
    # 计算四个角点（逆时针顺序）
    bottom_left = center + width_left_vec + height_down_vec
    bottom_right = center + width_right_vec + height_down_vec
    top_right = center + width_right_vec + height_up_vec
    top_left = center + width_left_vec + height_up_vec
    
    puts "  计算出的角点坐标:"
    puts "    左下角: #{bottom_left.inspect} (X=#{bottom_left.x.round(6)}m, Y=#{bottom_left.y.round(6)}m, Z=#{bottom_left.z.round(6)}m)"
    puts "    右下角: #{bottom_right.inspect} (X=#{bottom_right.x.round(6)}m, Y=#{bottom_right.y.round(6)}m, Z=#{bottom_right.z.round(6)}m)"
    puts "    右上角: #{top_right.inspect} (X=#{top_right.x.round(6)}m, Y=#{top_right.y.round(6)}m, Z=#{top_right.z.round(6)}m)"
    puts "    左上角: #{top_left.inspect} (X=#{top_left.x.round(6)}m, Y=#{top_left.y.round(6)}m, Z=#{top_left.z.round(6)}m)"
    
    [bottom_left, bottom_right, top_right, top_left]
  end

  # 将位于墙体中线的窗户角点，平移到墙体的一个表面上
  def self.project_corners_to_wall(centerline_corners, wall_start, wall_end, wall_direction, wall_thickness_inches)
    puts "=== 将中线角点平移到墙面 ==="
    
    # 1. 计算墙体法线向量 (在XY平面上与墙体方向垂直)
    # 我们假设墙体是沿着X或Y轴的，所以这个cross产品会得到正确的法线
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    puts "墙体法线: #{wall_normal.inspect}"
    
    # 2. 计算从中心线到墙体表面的偏移向量
    offset_distance = wall_thickness_inches / 2.0
    offset_vector = wall_normal.clone
    offset_vector.length = offset_distance
    puts "偏移距离: #{offset_distance.round(3)}英寸"
    puts "偏移向量: #{offset_vector.inspect}"
    
    # 3. 将中心线上的所有角点沿法线方向平移
    surface_corners = centerline_corners.map do |corner|
      corner + offset_vector
    end
    
    puts "平移后角点:"
    surface_corners.each_with_index do |point, i|
      puts "  点#{i+1}: #{point.inspect}"
    end
    
    return surface_corners
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
  def self.create_window_hole(wall_group, surface_corners, wall_direction, wall_thickness_inches)
    wall_entities = wall_group.entities
    
    # 1. 创建窗户切削面
    window_face = wall_entities.add_face(surface_corners)
    
    unless window_face
      puts "  警告: 无法创建窗户切削面，角点可能共线或无效"
      return false
    end
    
    puts "  窗户切削面创建成功"
    
    # 2. 确定推拉方向
    # 我们希望向墙体内部挖洞。
    # project_corners_to_wall 将角点向 wall_normal 方向移动了半个墙厚
    # 所以挖洞方向是 wall_normal 的反方向
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 检查新创建的面的法线方向是否与我们期望的挖洞方向一致
    # 如果不一致，我们需要反转推拉距离
    cut_depth = wall_thickness_inches
    
    # 如果面的法线与墙体法线方向相同，说明面的朝向是墙外，我们应该用负距离推拉
    if window_face.normal.samedirection?(wall_normal)
      cut_depth = -cut_depth
    end
    
    puts "  墙体法线: #{wall_normal.inspect}"
    puts "  切削面法线: #{window_face.normal.inspect}"
    puts "  推拉深度: #{cut_depth.round(3)}英寸"
    
    # 3. 执行挖洞操作
    begin
      window_face.pushpull(cut_depth)
      puts "  挖洞操作成功"
      return true
    rescue => e
      puts "  挖洞失败: #{e.message}"
      # 尝试删除失败时可能残留的面
      window_face.erase! if window_face && !window_face.deleted?
      return false
    end
  end

  # 在窗洞中心厚度处生成玻璃平面
  def self.create_glass_plane(wall_group, window_data, surface_corners, wall_direction, wall_thickness_inches)
    # 创建窗户组
    window_group = wall_group.entities.add_group
    window_group.name = "Window-Glass-#{window_data['id'] || 'unknown'}"
    
    # 1. 计算墙体法线方向 (垂直于墙面)
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 2. 计算玻璃平面的位置（在墙厚度的中心）
    # surface_corners 位于墙体表面，我们需要向内移动半个墙体厚度
    offset_distance = -wall_thickness_inches / 2.0
    
    puts "  玻璃平面偏移: #{offset_distance.round(3)}英寸 (向内)"
    
    # 3. 创建玻璃四点（沿墙体法线反方向偏移）
    offset_vector = wall_normal.clone
    offset_vector.length = offset_distance
    
    glass_corners = surface_corners.map do |corner|
      corner + offset_vector
    end
    
    # 4. 创建玻璃面
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
            position: window_group.bounds.center,
            dimensions: [
              window_group.bounds.width,
              window_group.bounds.depth,
              window_group.bounds.height
            ]
          })
          puts "  窗户实体已存储 (ID: #{window_record.id})" if window_record
        end
      rescue => e
        puts "  警告: 存储窗户实体时出错: #{e.message}"
      end
      
    else
      puts "  警告: 无法创建玻璃面"
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

  # 创建独立窗户
  def self.create_independent_window(window_data, parent_group)
    puts "=== 创建独立窗户 ==="
    puts "窗户ID: #{window_data['id'] || '未知'}"
    puts "窗户名称: #{window_data['name'] || '未知'}"
    
    position = Utils.validate_and_create_point(window_data["position"])
    
    if !position
      puts "警告: 独立窗户位置无效，跳过 (ID: #{window_data['id'] || '未知'})"
      return
    end
    
    puts "独立窗户位置: #{position.inspect}"
    puts "独立窗户XY坐标: X=#{position.x.round(6)}m, Y=#{position.y.round(6)}m, Z=#{position.z.round(6)}m"
    
    # 解析尺寸并转换为英寸
    size = window_data["size"] || []
    width_inches = normalize_to_inches(size[0] || 1000, DEFAULT_WIDTH)
    height_inches = normalize_to_inches(size[1] || 1500, DEFAULT_HEIGHT)
    depth_inches = normalize_to_inches(size[2] || 100, DEFAULT_THICKNESS)
    
    puts "独立窗户尺寸: 宽度=#{width_inches.round(3)}英寸, 高度=#{height_inches.round(3)}英寸, 深度=#{depth_inches.round(3)}英寸"
    
    # 创建窗户组
    window_group = parent_group.entities.add_group
    window_group.name = window_data["name"] || "独立窗户"
    
    # 创建窗户几何体（使用英寸值）
    points = [
      position,
      position + Geom::Vector3d.new(width_inches, 0, 0),
      position + Geom::Vector3d.new(width_inches, 0, height_inches),
      position + Geom::Vector3d.new(0, 0, height_inches)
    ]
    
    # 创建面并拉伸
    window_face = window_group.entities.add_face(points)
    if window_face
      window_face.pushpull(depth_inches)
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
      puts "最终窗户位置: 起点=#{points[0].inspect}, 终点=#{points[2].inspect}"
      puts "窗户几何体: 宽度=#{width_inches.round(3)}英寸, 高度=#{height_inches.round(3)}英寸, 深度=#{depth_inches.round(3)}英寸"
    else
      puts "警告: 创建独立窗户失败"
    end
  end

  # 单位标准化：确保输入值转换为英寸
  def self.normalize_to_inches(value, default_inches)
    return default_inches if value.nil?
    
    value_num = Utils.parse_number(value)
    return default_inches if value_num.nil?
    
    # 假设所有JSON数据中的尺寸都是毫米单位
    # 转换为英寸
    inches = value_num / 25.4
    puts "  单位转换: #{value_num}mm -> #{inches.round(3)}英寸"
    inches
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
