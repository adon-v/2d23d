# 胶带构建模块：通过大区域减去小区域生成胶带
module TapeBuilder
  # 胶带配置参数
  TAPE_COLOR = [255, 255, 0, 255]  # 黄色，完全不透明
  TAPE_WIDTH = 5  # 胶带宽度（米）
  TAPE_HEIGHT_OFFSET = 0.5  # 胶带上浮高度（米）- 悬浮到区域上方
  TAPE_THICKNESS = 0.1  # 胶带厚度（米）

  # 生成区域边界胶带
  def self.generate_zone_boundary_tapes(zones_data, parent_group)
    puts "【胶带】开始生成区域边界胶带..."
    
    # 创建胶带层
    tape_layer = create_tape_layer
    
    zones_data.each_with_index do |zone_data, zone_index|
      begin
        shape = zone_data["shape"]
        next unless shape && shape["points"]
        
        points = shape["points"].map { |point| Utils.validate_and_create_point(point) }.compact
        next if points.size < 3
        
        zone_name = zone_data["name"] || zone_data["id"] || "区域#{zone_index}"
        
        # 使用新的胶带生成算法
        generate_tape_by_offset_subtraction(points, zone_name, parent_group, tape_layer)
        
      rescue => e
        puts "【胶带】生成区域 #{zone_data["name"] || zone_data["id"]} 胶带失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    puts "【胶带】区域边界胶带生成完成"
  end

  # 生成外部区域边界胶带（保持兼容性）
  def self.generate_outdoor_zone_boundary_tapes(zones_data, parent_group)
    puts "【胶带】开始生成外部区域边界胶带..."
    
    # 创建胶带层
    tape_layer = create_tape_layer
    
    zones_data.each_with_index do |zone_data, zone_index|
      begin
        shape = zone_data["shape"]
        next unless shape && shape["points"]
        
        points = shape["points"].map { |point| Utils.validate_and_create_point(point) }.compact
        next if points.size < 3
        
        zone_name = zone_data["name"] || zone_data["id"] || "外部区域#{zone_index}"
        
        # 使用相同的胶带生成算法，但标记为外部区域
        generate_tape_by_offset_subtraction(points, zone_name, parent_group, tape_layer, true)
        
      rescue => e
        puts "【胶带】生成外部区域 #{zone_data["name"] || zone_data["id"]} 胶带失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    puts "【胶带】外部区域边界胶带生成完成"
  end

  # 通过偏移减法生成胶带：大区域减去小区域
  def self.generate_tape_by_offset_subtraction(points, zone_name, parent_group, tape_layer, is_outdoor = false)
    return if points.size < 3
    
    # 确保所有点的Z坐标为0
    points = points.map { |pt| Geom::Point3d.new(pt.x, pt.y, 0) }
    
    # 计算偏移距离
    half_width = TAPE_WIDTH / 2.0
    
    # 生成大区域（向外偏移半个宽度）
    large_region_points = generate_offset_polygon(points, half_width)
    return unless large_region_points
    
    # 生成小区域（向内偏移半个宽度）
    small_region_points = generate_offset_polygon(points, -half_width)
    return unless small_region_points
    
    # 生成胶带：大区域减去小区域
    tape_polygon = subtract_polygons(large_region_points, small_region_points, zone_name)
    return unless tape_polygon
    
    # 创建胶带面
    create_tape_face(tape_polygon, zone_name, parent_group, tape_layer, is_outdoor)
  end

  # 生成偏移多边形
  def self.generate_offset_polygon(original_points, offset_distance)
    return [] if original_points.size < 3
    
    # 计算每个边的法向量并生成偏移点
    offset_points = []
    
    (0...original_points.size).each do |i|
      p1 = original_points[i]
      p2 = original_points[(i + 1) % original_points.size]
      
      # 计算边的方向向量
      edge_vector = p2 - p1
      return [] if edge_vector.length < 1e-6
      
      # 计算法向量（垂直于边，指向外部）
      normal_vector = calculate_normal_vector(edge_vector)
      
      # 应用偏移
      offset_p1 = p1.offset(normal_vector, offset_distance)
      offset_p2 = p2.offset(normal_vector, offset_distance)
      
      offset_points << [offset_p1, offset_p2]
    end
    
    # 计算偏移线段的交点，形成闭合多边形
    offset_polygon = calculate_offset_polygon_intersections(offset_points)
    
    offset_polygon
  end

  # 计算边的法向量
  def self.calculate_normal_vector(edge_vector)
    # 2D平面的法向量：(-y, x, 0)
    normal = Geom::Vector3d.new(-edge_vector.y, edge_vector.x, 0)
    normal.normalize
  rescue
    # 如果标准化失败，返回单位向量
    Geom::Vector3d.new(1, 0, 0)
  end

  # 计算偏移多边形的交点
  def self.calculate_offset_polygon_intersections(offset_lines)
    return [] if offset_lines.size < 2
    
    polygon_points = []
    
    # 添加第一个线段的起点
    polygon_points << offset_lines[0][0]
    
    # 计算相邻线段的交点
    (1...offset_lines.size).each do |i|
      prev_line = offset_lines[i-1]
      curr_line = offset_lines[i]
      
      # 计算交点
      intersection = calculate_line_intersection(
        prev_line[0], prev_line[1],
        curr_line[0], curr_line[1]
      )
      
      if intersection
        polygon_points << intersection
      else
        # 如果交点计算失败，使用中点
        mid_point = calculate_midpoint(prev_line[1], curr_line[0])
        polygon_points << mid_point
      end
    end
    
    # 添加最后一个线段的终点
    polygon_points << offset_lines[-1][1]
    
    # 闭合多边形：计算首尾线段的交点
    if offset_lines.size > 2
      first_line = offset_lines[0]
      last_line = offset_lines[-1]
      
      closing_intersection = calculate_line_intersection(
        last_line[0], last_line[1],
        first_line[0], first_line[1]
      )
      
      if closing_intersection
        polygon_points[-1] = closing_intersection
      end
    end
    
    # 去重并保持顺序
    unique_points = []
    polygon_points.each do |point|
      if unique_points.empty? || point.distance(unique_points[-1]) > 1e-6
        unique_points << point
      end
    end
    
    unique_points
  end

  # 计算两条线段的交点
  def self.calculate_line_intersection(p1, p2, q1, q2)
    x1, y1 = p1.x, p1.y
    x2, y2 = p2.x, p2.y
    x3, y3 = q1.x, q1.y
    x4, y4 = q2.x, q2.y
    
    # 计算分母
    denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
    
    # 检查是否平行
    return nil if denom.abs < 1e-10
    
    # 计算参数
    ua = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / denom.to_f
    ub = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / denom.to_f
    
    # 检查参数是否在有效范围内
    return nil if ua < -0.1 || ua > 1.1 || ub < -0.1 || ub > 1.1
    
    # 计算交点坐标
    x = x1 + ua * (x2 - x1)
    y = y1 + ua * (y2 - y1)
    
    Geom::Point3d.new(x, y, 0)
  end

  # 计算两点中点
  def self.calculate_midpoint(p1, p2)
    mid_x = (p1.x + p2.x) / 2.0
    mid_y = (p1.y + p2.y) / 2.0
    Geom::Point3d.new(mid_x, mid_y, 0)
  end

  # 多边形减法：大区域减去小区域
  def self.subtract_polygons(large_polygon, small_polygon, zone_name)
    return [] if large_polygon.size < 3 || small_polygon.size < 3
    
    # 简化处理：直接使用大区域作为胶带外边界，小区域作为内边界
    # 这里先实现一个基础版本，后续可以优化为真正的布尔运算
    
    # 组合成胶带多边形：外边界 + 内边界（反向）
    tape_polygon = large_polygon + small_polygon.reverse
    
    tape_polygon
  end

  # 创建胶带面
  def self.create_tape_face(tape_polygon, zone_name, parent_group, tape_layer, is_outdoor = false)
    return unless tape_polygon && tape_polygon.size >= 3
    
    # 上浮避免与区域重叠
    elevated_points = tape_polygon.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + TAPE_HEIGHT_OFFSET) }
    
    # 生成胶带面
    tape_face = parent_group.entities.add_face(elevated_points)
    return unless tape_face
    
    # 设置材质颜色
    tape_face.material = TAPE_COLOR
    tape_face.back_material = TAPE_COLOR
    
    # 设置胶带属性
    tape_face.set_attribute('FactoryImporter', 'tape_type', 'zone_boundary')
    tape_face.set_attribute('FactoryImporter', 'zone_name', zone_name)
    tape_face.set_attribute('FactoryImporter', 'tape_width', TAPE_WIDTH)
    tape_face.set_attribute('FactoryImporter', 'is_shared', false)
    tape_face.set_attribute('FactoryImporter', 'is_outdoor', is_outdoor)
    
    # 确保胶带面在胶带层上
    if tape_layer
      tape_face.layer = tape_layer
    end
    
    # 为胶带添加厚度
    tape_face.pushpull(TAPE_THICKNESS)
    
    # 输出成功信息
    puts "【胶带】#{zone_name}: 胶带生成成功"
    
    tape_face
  end

  # 创建胶带层
  def self.create_tape_layer
    model = Sketchup.active_model
    return unless model
    
    # 查找或创建胶带层
    tape_layer = model.layers.find { |layer| layer.name == "胶带层" }
    unless tape_layer
      tape_layer = model.layers.add("胶带层")
    end
    
    tape_layer
  end
end
