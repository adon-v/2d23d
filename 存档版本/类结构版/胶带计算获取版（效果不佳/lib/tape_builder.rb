# 胶带构建模块：处理区域边界胶带的创建
module TapeBuilder
  # 胶带配置参数
  TAPE_COLOR = [255, 255, 0, 255]  # 黄色，完全不透明
  TAPE_WIDTH = 10  # 胶带宽度（米）
  TAPE_HEIGHT_OFFSET = 0.5  # 胶带上浮高度（米）- 确保胶带可见
  
  # 生成区域边界胶带 - 重新调整的结构
  def self.generate_zone_boundary_tapes(zones_data, parent_group)
    puts "【胶带生成】开始生成区域边界胶带..."
    
    # 创建胶带层
    tape_layer = create_tape_layer
    
    # 第一步：读取各区域边界坐标，获取各区域的胶带生成位置（此时不考虑共享）
    tape_positions = collect_all_zone_tape_positions(zones_data)
    puts "【胶带生成】第一步完成：收集到 #{tape_positions.size} 个区域的胶带位置"
    
    # 第二步：判断胶带之间是否有重叠（即区域共享部分）
    shared_segments = detect_all_overlapping_segments(tape_positions)
    puts "【胶带生成】第二步完成：检测到 #{shared_segments.size} 个重叠线段"
    
    # 第三步：根据坐标信息和共享状态生成胶带
    generate_tapes_with_shared_handling(tape_positions, shared_segments, parent_group)
    
    puts "【胶带生成】区域边界胶带生成完成"
  end
  
  # 第一步：收集所有区域的胶带生成位置（不考虑共享）
  def self.collect_all_zone_tape_positions(zones_data)
    tape_positions = []
    
    zones_data.each_with_index do |zone_data, zone_index|
      begin
        shape = zone_data["shape"]
        next unless shape && shape["points"]
        
        points = shape["points"].map { |point| Utils.validate_and_create_point(point) }.compact
        next if points.size < 3
        
        zone_name = zone_data["name"] || zone_data["id"] || "区域#{zone_index}"
        zone_id = zone_data["id"]
        
        puts "【胶带生成】收集区域胶带位置: #{zone_name}"
        
        # 收集该区域的所有边界线段（不考虑共享）
        boundary_segments = []
        (0...points.size).each do |i|
          p1 = points[i]
          p2 = points[(i + 1) % points.size]
          boundary_segments << {
            start: p1,
            end: p2,
            zone_name: zone_name,
            zone_id: zone_id,
            segment_index: i,
            is_shared: false  # 初始标记为非共享
          }
        end
        
        tape_positions << {
          zone_name: zone_name,
          zone_id: zone_id,
          segments: boundary_segments,
          original_points: points  # 保存原始点用于后续处理
        }
        
      rescue => e
        puts "【胶带生成】收集区域 #{zone_data["name"] || zone_data["id"]} 胶带位置失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    tape_positions
  end

  # 第二步：检测所有重叠线段
  def self.detect_all_overlapping_segments(tape_positions)
    shared_segments = []
    
    # 比较所有区域之间的线段
    tape_positions.each_with_index do |zone1, i|
      tape_positions[(i+1)..-1].each do |zone2|
        zone1[:segments].each do |seg1|
          zone2[:segments].each do |seg2|
            # 检查线段是否重叠
            if segments_overlap?(seg1, seg2)
              # 标记为共享线段
              seg1[:is_shared] = true
              seg2[:is_shared] = true
              
              shared_segments << {
                segment1: seg1,
                segment2: seg2,
                zone1_name: zone1[:zone_name],
                zone2_name: zone2[:zone_name],
                zone1_id: zone1[:zone_id],
                zone2_id: zone2[:zone_id],
                shared_coordinates: [seg1[:start], seg1[:end]]
              }
              
              puts "【胶带生成】检测到共享线段: #{zone1[:zone_name]} 与 #{zone2[:zone_name]}"
            end
          end
        end
      end
    end
    
    shared_segments
  end

  # 检查两个线段是否重叠
  def self.segments_overlap?(seg1, seg2)
    # 检查线段是否重合（考虑容差）
    tolerance = 0.001
    
    # 检查起点和终点是否重合
    start_match = Utils.points_equal?(seg1[:start], seg2[:start], tolerance) && 
                  Utils.points_equal?(seg1[:end], seg2[:end], tolerance)
    
    # 检查起点和终点是否交叉
    cross_match = Utils.points_equal?(seg1[:start], seg2[:end], tolerance) && 
                  Utils.points_equal?(seg1[:end], seg2[:start], tolerance)
    
    start_match || cross_match
  end

  # 第三步：根据坐标信息和共享状态生成胶带
  def self.generate_tapes_with_shared_handling(tape_positions, shared_segments, parent_group)
    puts "【胶带生成】开始根据位置信息和共享状态生成胶带..."
    
    # 收集所有共享线段的坐标
    shared_coords = shared_segments.map do |shared|
      shared[:shared_coordinates]
    end
    
    # 为每个区域生成胶带
    tape_positions.each do |zone_data|
      zone_name = zone_data[:zone_name]
      zone_id = zone_data[:zone_id]
      
      puts "【胶带生成】为区域 #{zone_name} 生成胶带"
      
      # 分离共享和非共享线段
      shared_segments_for_zone = []
      non_shared_segments = []
      
      zone_data[:segments].each do |segment|
        if segment[:is_shared]
          shared_segments_for_zone << segment
        else
          non_shared_segments << segment
        end
      end
      
      # 生成非共享线段的胶带
      if non_shared_segments.any?
        puts "【胶带生成】#{zone_name}: 生成 #{non_shared_segments.size} 个非共享线段胶带"
        generate_zone_tape_from_segments(non_shared_segments, zone_name, parent_group, false)
      end
      
      # 生成共享线段的胶带（标记为共享）
      if shared_segments_for_zone.any?
        puts "【胶带生成】#{zone_name}: 生成 #{shared_segments_for_zone.size} 个共享线段胶带"
        generate_zone_tape_from_segments(shared_segments_for_zone, zone_name, parent_group, true)
      end
    end
    
    # 为共享线段生成特殊的共享边界胶带
    shared_segments.each do |shared|
      p1 = shared[:segment1][:start]
      p2 = shared[:segment1][:end]
      zone1_name = shared[:zone1_name]
      zone2_name = shared[:zone2_name]
      
      puts "【胶带生成】为共享边界生成特殊胶带: #{zone1_name} 与 #{zone2_name}"
      generate_shared_boundary_tape(p1, p2, zone1_name, zone2_name, parent_group)
    end
  end

  # 根据线段生成区域胶带（支持共享标记）
  def self.generate_zone_tape_from_segments(segments, zone_name, parent_group, is_shared = false)
    return if segments.empty?
    
    tape_type = is_shared ? 'shared_zone_boundary' : 'zone_boundary'
    puts "【胶带生成】#{zone_name}: 生成 #{segments.size} 个#{is_shared ? '共享' : '非共享'}线段胶带"
    
    # 收集所有线段的点
    all_points = []
    segments.each do |segment|
      all_points << segment[:start]
      all_points << segment[:end]
    end
    
    # 去重并保持顺序
    unique_points = all_points.uniq { |p| [p.x.round(6), p.y.round(6)] }
    
    if unique_points.size >= 3
      # 生成胶带多边形
      generate_single_zone_tape_with_type(unique_points, zone_name, parent_group, tape_type, is_shared)
    else
      puts "【胶带生成】#{zone_name}: 点数不足，无法生成胶带"
    end
  end

  # 生成单个区域的边界胶带（排除共享边界）
  def self.generate_single_zone_tape_without_shared(points, zone_name, parent_group, shared_boundaries, zone_id)
    return if points.size < 3
    
    puts "【胶带生成】#{zone_name}: 开始处理 #{points.size} 个边界点"
    puts "【胶带生成】#{zone_name}: 原始边界点: #{points.map { |p| "[#{p.x.round(3)}, #{p.y.round(3)}]" }.join(', ')}"
    
    # 确保所有点的Z坐标为0
    points = points.map { |pt| Geom::Point3d.new(pt.x, pt.y, 0) }
    
    # 收集边界线段
    boundary_segments = []
    (0...points.size).each do |i|
      p1 = points[i]
      p2 = points[(i + 1) % points.size]
      boundary_segments << [p1, p2]
    end
    
    # 找出当前区域的共享边界线段
    shared_segments = []
    shared_boundaries.each do |boundary|
      if boundary[:zone1]["id"] == zone_id || boundary[:zone2]["id"] == zone_id
        boundary[:shared_segments].each do |segment|
          shared_segments << [segment[:segment1][0], segment[:segment1][1]]
        end
      end
    end
    
    # 过滤出非共享边界线段
    non_shared_segments = []
    boundary_segments.each_with_index do |segment, i|
      p1, p2 = segment
      
      # 检查是否是共享边界
      is_shared = shared_segments.any? do |shared_seg|
        (Utils.points_equal?(p1, shared_seg[0]) && Utils.points_equal?(p2, shared_seg[1])) ||
        (Utils.points_equal?(p1, shared_seg[1]) && Utils.points_equal?(p2, shared_seg[0]))
      end
      
      # 只保留非共享边界
      unless is_shared
        non_shared_segments << segment
      end
    end
    
    puts "【胶带生成】#{zone_name}: 非共享边界线段数: #{non_shared_segments.size}"
    non_shared_segments.each_with_index do |segment, i|
      p1, p2 = segment
      puts "【胶带生成】#{zone_name}: 非共享边界线段#{i}: [#{p1.x.round(3)}, #{p1.y.round(3)}] -> [#{p2.x.round(3)}, #{p2.y.round(3)}]"
    end
    
    # 使用改进的胶带生成方法
    if non_shared_segments.size > 0
      generate_improved_tape_polygon(non_shared_segments, zone_name, parent_group, false)
    end
    
    puts "【胶带生成】#{zone_name}: 完成边界胶带生成（排除共享边界）"
  end

  # 生成单个区域的边界胶带
  def self.generate_single_zone_tape(points, zone_name, parent_group)
    return if points.size < 3
    
    puts "【胶带生成】#{zone_name}: 开始处理 #{points.size} 个边界点"
    
    # 确保所有点的Z坐标为0
    points = points.map { |pt| Geom::Point3d.new(pt.x, pt.y, 0) }
    
    # 收集边界线段
    boundary_segments = []
    (0...points.size).each do |i|
      p1 = points[i]
      p2 = points[(i + 1) % points.size]
      boundary_segments << [p1, p2]
    end
    
    # 使用改进的胶带生成方法
    generate_improved_tape_polygon(boundary_segments, zone_name, parent_group, false)
    
    puts "【胶带生成】#{zone_name}: 完成边界胶带生成"
  end
  
  # 改进的胶带多边形生成方法 - 解决闭合性问题
  def self.generate_improved_tape_polygon(boundary_segments, zone_name, parent_group, is_shared = false)
    return if boundary_segments.empty?
    
    puts "【胶带生成】#{zone_name}: 使用改进算法生成胶带多边形"
    
    # 计算胶带边界线（向内偏移）
    left_lines = []
    right_lines = []
    
    boundary_segments.each_with_index do |segment, i|
      p1, p2 = segment
      dir = p2 - p1
      return if dir.length < 1e-6
      
      begin
        dir = dir.normalize
      rescue
        dir = Geom::Vector3d.new(1,0,0)
      end
      
      begin
        normal = Geom::Vector3d.new(-dir.y, dir.x, 0)
        normal = normal.normalize
      rescue
        normal = Geom::Vector3d.new(1,0,0)
      end
      
      # 向两侧偏移TAPE_WIDTH/2距离，确保胶带沿着原始边界
      offset = TAPE_WIDTH / 2.0
      left_lines << [p1.offset(normal, offset), p2.offset(normal, offset)]
      right_lines << [p1.offset(normal.reverse, offset), p2.offset(normal.reverse, offset)]
    end
    
    # 改进的交点计算和闭合处理
    left_pts = calculate_improved_intersection_points(left_lines, "左边界")
    right_pts = calculate_improved_intersection_points(right_lines, "右边界")
    
    # 确保闭合性：检查首尾连接
    if left_pts.size >= 2 && right_pts.size >= 2
      # 检查左边界首尾是否应该连接
      if should_connect_endpoints?(left_pts.first, left_pts.last, boundary_segments)
        left_pts = close_polygon_boundary(left_pts, left_lines, "左边界")
      end
      
      # 检查右边界首尾是否应该连接
      if should_connect_endpoints?(right_pts.first, right_pts.last, boundary_segments)
        right_pts = close_polygon_boundary(right_pts, right_lines, "右边界")
      end
    end
    
    # 组合成完整的胶带多边形
    polygon = left_pts + right_pts.reverse
    polygon = polygon.each_with_object([]) { |p, arr| arr << p if arr.empty? || (p.distance(arr[-1]) > 1e-6) }
    
    puts "【胶带生成】#{zone_name}: 最终胶带多边形点数: #{polygon.size}"
    
    # 生成胶带面
    if polygon.size >= 3
      # 上浮避免抢面
      elevated_points = polygon.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + TAPE_HEIGHT_OFFSET) }
      
      tape_face = parent_group.entities.add_face(elevated_points)
      if tape_face
        # 根据是否共享选择颜色
        tape_color = is_shared ? [255, 165, 0, 255] : TAPE_COLOR  # 共享用橙色，非共享用黄色
        
        # 设置材质
        tape_face.material = tape_color
        tape_face.back_material = tape_color
        
        # 设置胶带属性
        tape_face.set_attribute('FactoryImporter', 'tape_type', 'zone_boundary')
        tape_face.set_attribute('FactoryImporter', 'zone_name', zone_name)
        tape_face.set_attribute('FactoryImporter', 'tape_width', TAPE_WIDTH)
        tape_face.set_attribute('FactoryImporter', 'is_shared', is_shared)
        
        # 确保胶带面在胶带层上
        tape_layer = create_tape_layer
        if tape_layer
          tape_face.layer = tape_layer
        end
        
        # 为胶带添加厚度
        tape_thickness = 0.1  # 胶带厚度（米）
        tape_face.pushpull(tape_thickness)
        
        # 添加更多调试信息
        puts "【胶带生成】#{zone_name}: 胶带生成成功"
        puts "  - 胶带宽度: #{TAPE_WIDTH}米"
        puts "  - 胶带高度: #{TAPE_HEIGHT_OFFSET}米"
        puts "  - 胶带厚度: #{tape_thickness}米"
        puts "  - 胶带颜色: #{tape_color}"
        puts "  - 胶带点数: #{elevated_points.size}"
        puts "  - 胶带层: #{tape_layer ? tape_layer.name : '无'}"
        puts "  - 是否共享: #{is_shared}"
      else
        puts "【胶带生成】#{zone_name}: 胶带面生成失败"
      end
    else
      puts "【胶带生成】#{zone_name}: 胶带多边形点数不足，无法生成面"
    end
  end
  
  # 改进的交点计算方法
  def self.calculate_improved_intersection_points(lines, boundary_name)
    return [] if lines.empty?
    
    points = []
    
    # 添加第一个线段的起点
    points << lines[0][0]
    
    # 计算中间的交点
    (1...lines.size).each do |i|
      prev_line = lines[i-1]
      curr_line = lines[i]
      
      # 使用改进的交点计算
      intersection_pt = calculate_robust_intersection(prev_line[0], prev_line[1], curr_line[0], curr_line[1])
      
      if intersection_pt
        points << intersection_pt
        puts "【胶带生成】#{boundary_name}: 线段#{i-1}与#{i}交点: [#{intersection_pt.x.round(3)}, #{intersection_pt.y.round(3)}]"
      else
        # 如果交点计算失败，使用更智能的备选策略
        fallback_pt = calculate_fallback_point(prev_line, curr_line)
        points << fallback_pt
        puts "【胶带生成】#{boundary_name}: 线段#{i-1}与#{i}使用备选点: [#{fallback_pt.x.round(3)}, #{fallback_pt.y.round(3)}]"
      end
    end
    
    # 添加最后一个线段的终点
    points << lines[-1][1]
    
    points
  end
  
  # 改进的交点计算 - 提高精度
  def self.calculate_robust_intersection(p1, p2, q1, q2)
    x1, y1 = p1.x, p1.y
    x2, y2 = p2.x, p2.y
    x3, y3 = q1.x, q1.y
    x4, y4 = q2.x, q2.y
    
    denom = (y4-y3)*(x2-x1) - (x4-x3)*(y2-y1)
    
    # 提高精度容差，减少误判
    return nil if denom.abs < 1e-10
    
    ua = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / denom.to_f
    
    # 检查参数是否在有效范围内
    return nil if ua < -0.1 || ua > 1.1
    
    x = x1 + ua * (x2-x1)
    y = y1 + ua * (y2-y1)
    
    Geom::Point3d.new(x, y, 0)
  end
  
  # 智能备选点计算
  def self.calculate_fallback_point(prev_line, curr_line)
    # 计算两条线段的端点
    prev_start, prev_end = prev_line
    curr_start, curr_end = curr_line
    
    # 计算前一线段的终点到当前线段起点的距离
    dist1 = prev_end.distance(curr_start)
    dist2 = prev_end.distance(curr_end)
    
    # 选择距离更近的点
    if dist1 <= dist2
      # 使用前一线段终点和当前线段起点的中点
      mid_x = (prev_end.x + curr_start.x) / 2.0
      mid_y = (prev_end.y + curr_start.y) / 2.0
      Geom::Point3d.new(mid_x, mid_y, 0)
    else
      # 使用前一线段终点和当前线段终点的中点
      mid_x = (prev_end.x + curr_end.x) / 2.0
      mid_y = (prev_end.y + curr_end.y) / 2.0
      Geom::Point3d.new(mid_x, mid_y, 0)
    end
  end
  
  # 检查是否应该连接端点
  def self.should_connect_endpoints?(first_pt, last_pt, boundary_segments)
    return false if boundary_segments.empty?
    
    # 检查原始边界是否闭合
    first_boundary_start = boundary_segments.first[0]
    last_boundary_end = boundary_segments.last[1]
    
    # 如果原始边界闭合，则偏移后的边界也应该闭合
    Utils.points_equal?(first_boundary_start, last_boundary_end, 0.001)
  end
  
  # 闭合多边形边界
  def self.close_polygon_boundary(points, lines, boundary_name)
    return points if points.size < 2
    
    # 计算首尾连接的交点
    first_line = lines.first
    last_line = lines.last
    
    closing_intersection = calculate_robust_intersection(
      last_line[0], last_line[1], 
      first_line[0], first_line[1]
    )
    
    if closing_intersection
      # 替换最后一个点，确保闭合
      points[-1] = closing_intersection
      puts "【胶带生成】#{boundary_name}: 成功闭合边界"
    else
      # 如果交点计算失败，使用智能备选
      fallback_pt = calculate_fallback_point(last_line, first_line)
      points[-1] = fallback_pt
      puts "【胶带生成】#{boundary_name}: 使用备选点闭合边界"
    end
    
    points
  end

  # 生成单个区域的边界胶带（支持类型标记）
  def self.generate_single_zone_tape_with_type(points, zone_name, parent_group, tape_type, is_shared = false)
    return if points.size < 3
    
    puts "【胶带生成】#{zone_name}: 开始处理 #{points.size} 个边界点 (#{tape_type})"
    
    # 确保所有点的Z坐标为0
    points = points.map { |pt| Geom::Point3d.new(pt.x, pt.y, 0) }
    
    # 收集边界线段
    boundary_segments = []
    (0...points.size).each do |i|
      p1 = points[i]
      p2 = points[(i + 1) % points.size]
      boundary_segments << [p1, p2]
    end
    
    # 使用改进的胶带生成方法
    generate_improved_tape_polygon(boundary_segments, zone_name, parent_group, is_shared)
    
    puts "【胶带生成】#{zone_name}: 完成边界胶带生成 (#{tape_type})"
  end

  # 生成共享边界胶带
  def self.generate_shared_boundary_tape(start_point, end_point, zone1_name, zone2_name, parent_group)
    # 计算线段方向
    dir = end_point - start_point
    return if dir.length < 1e-6
    
    begin
      dir = dir.normalize
    rescue
      dir = Geom::Vector3d.new(1,0,0)
    end
    
    # 计算法向量（垂直于线段方向）
    normal = Geom::Vector3d.new(-dir.y, dir.x, 0)
    
    begin
      normal = normal.normalize
    rescue
      normal = Geom::Vector3d.new(1,0,0)
    end
    
    # 计算胶带的内外边界点（向两侧偏移，确保固定宽度）
    offset = TAPE_WIDTH / 2.0
    
    # 一侧边界点
    side1_start = start_point.offset(normal, offset)
    side1_end = end_point.offset(normal, offset)
    
    # 另一侧边界点
    side2_start = start_point.offset(normal.reverse, offset)
    side2_end = end_point.offset(normal.reverse, offset)
    
    # 创建胶带矩形
    tape_points = [
      side1_start,
      side1_end,
      side2_end,
      side2_start
    ]
    
    # 上浮避免抢面
    elevated_points = tape_points.map do |pt|
      Geom::Point3d.new(pt.x, pt.y, pt.z + TAPE_HEIGHT_OFFSET)
    end
    
    # 生成胶带面
    tape_face = parent_group.entities.add_face(elevated_points)
    if tape_face
      tape_face.material = TAPE_COLOR # 共享边界使用黄色
      tape_face.back_material = TAPE_COLOR
      
      # 设置胶带属性
      tape_face.set_attribute('FactoryImporter', 'tape_type', 'shared_boundary')
      tape_face.set_attribute('FactoryImporter', 'zone1_name', zone1_name)
      tape_face.set_attribute('FactoryImporter', 'zone2_name', zone2_name)
      tape_face.set_attribute('FactoryImporter', 'tape_width', TAPE_WIDTH)
      
      # 确保胶带面在胶带层上
      tape_layer = create_tape_layer
      if tape_layer
        tape_face.layer = tape_layer
      end
      
      # 为胶带添加厚度
      tape_thickness = 0.1  # 胶带厚度（米）
      tape_face.pushpull(tape_thickness)
      
      puts "【胶带生成】共享边界胶带生成成功: #{zone1_name} 与 #{zone2_name}"
      puts "  - 胶带宽度: #{TAPE_WIDTH}米"
      puts "  - 胶带高度: #{TAPE_HEIGHT_OFFSET}米"
      puts "  - 胶带厚度: #{tape_thickness}米"
    else
      puts "【胶带生成】共享边界胶带生成失败: #{zone1_name} 与 #{zone2_name}"
    end
  end

  # 生成单个边界线段的胶带
  def self.generate_boundary_tape_segment(start_point, end_point, zone_name, parent_group, segment_index)
    # 计算线段方向
    dir = end_point - start_point
    return if dir.length < 1e-6
    
    begin
      dir = dir.normalize
    rescue
      dir = Geom::Vector3d.new(1,0,0)
    end
    
    normal = Geom::Vector3d.new(-dir.y, dir.x, 0)
    
    begin
      normal = normal.normalize
    rescue
      normal = Geom::Vector3d.new(1,0,0)
    end
    
    # 计算胶带的内外边界点
    inner_offset = TAPE_WIDTH / 2.0
    outer_offset = TAPE_WIDTH / 2.0
    
    # 内边界点
    inner_start = start_point.offset(normal, inner_offset)
    inner_end = end_point.offset(normal, inner_offset)
    
    # 外边界点
    outer_start = start_point.offset(normal.reverse, outer_offset)
    outer_end = end_point.offset(normal.reverse, outer_offset)
    
    # 创建胶带矩形
    tape_points = [
      inner_start,
      inner_end,
      outer_end,
      outer_start
    ]
    
    # 上浮避免抢面
    elevated_points = tape_points.map do |pt|
      Geom::Point3d.new(pt.x, pt.y, pt.z + TAPE_HEIGHT_OFFSET)
    end
    
    # 生成胶带面
    tape_face = parent_group.entities.add_face(elevated_points)
    if tape_face
      # 设置更明显的黄色材质
      tape_face.material = TAPE_COLOR
      tape_face.back_material = TAPE_COLOR
      
      # 设置胶带属性
      tape_face.set_attribute('FactoryImporter', 'tape_type', 'zone_boundary')
      tape_face.set_attribute('FactoryImporter', 'zone_name', zone_name)
      tape_face.set_attribute('FactoryImporter', 'segment_index', segment_index)
      tape_face.set_attribute('FactoryImporter', 'tape_width', TAPE_WIDTH)
      
      # 确保胶带面在胶带层上
      tape_layer = create_tape_layer
      if tape_layer
        tape_face.layer = tape_layer
      end
      
      # 添加更多调试信息
      puts "【胶带生成】#{zone_name}: 边界段#{segment_index}胶带生成成功"
      puts "  - 胶带宽度: #{TAPE_WIDTH}米"
      puts "  - 胶带高度: #{TAPE_HEIGHT_OFFSET}米"
      puts "  - 胶带颜色: #{TAPE_COLOR}"
      puts "  - 胶带点数: #{elevated_points.size}"
      puts "  - 胶带层: #{tape_layer ? tape_layer.name : '无'}"
    else
      puts "【胶带生成】#{zone_name}: 边界段#{segment_index}胶带生成失败"
    end
  end
  
  # 生成虚线胶带（可选功能）
  def self.generate_dashed_tape(start_point, end_point, zone_name, parent_group, segment_index)
    # 计算线段方向
    dir = end_point - start_point
    return if dir.length < 1e-6
    
    begin
      dir = dir.normalize
    rescue
      dir = Geom::Vector3d.new(1,0,0)
    end
    
    normal = Geom::Vector3d.new(-dir.y, dir.x, 0)
    
    begin
      normal = normal.normalize
    rescue
      normal = Geom::Vector3d.new(1,0,0)
    end
    
    # 虚线参数
    dash_length = 0.3  # 虚线长度
    gap_length = 0.2   # 间隔长度
    total_length = (end_point - start_point).length
    
    # 计算虚线数量
    dash_count = (total_length / (dash_length + gap_length)).floor
    
    (0...dash_count).each do |i|
      # 计算当前虚线的起点和终点
      dash_start_distance = i * (dash_length + gap_length)
      dash_end_distance = dash_start_distance + dash_length
      
      # 确保不超过线段总长度
      next if dash_start_distance >= total_length
      dash_end_distance = [dash_end_distance, total_length].min
      
      # 计算虚线端点
      dash_start = start_point.offset(dir, dash_start_distance)
      dash_end = start_point.offset(dir, dash_end_distance)
      
      # 生成虚线胶带段
      generate_boundary_tape_segment(dash_start, dash_end, zone_name, parent_group, "#{segment_index}_dash#{i}")
    end
  end
  
  # 生成不同颜色的胶带
  def self.generate_colored_tape(start_point, end_point, zone_name, parent_group, segment_index, color = TAPE_COLOR)
    # 计算线段方向
    dir = end_point - start_point
    return if dir.length < 1e-6
    
    begin
      dir = dir.normalize
    rescue
      dir = Geom::Vector3d.new(1,0,0)
    end
    
    normal = Geom::Vector3d.new(-dir.y, dir.x, 0)
    
    begin
      normal = normal.normalize
    rescue
      normal = Geom::Vector3d.new(1,0,0)
    end
    
    # 计算胶带的内外边界点
    inner_offset = TAPE_WIDTH / 2.0
    outer_offset = TAPE_WIDTH / 2.0
    
    # 内边界点
    inner_start = start_point.offset(normal, inner_offset)
    inner_end = end_point.offset(normal, inner_offset)
    
    # 外边界点
    outer_start = start_point.offset(normal.reverse, outer_offset)
    outer_end = end_point.offset(normal.reverse, outer_offset)
    
    # 创建胶带矩形
    tape_points = [
      inner_start,
      inner_end,
      outer_end,
      outer_start
    ]
    
    # 上浮避免抢面
    elevated_points = tape_points.map do |pt|
      Geom::Point3d.new(pt.x, pt.y, pt.z + TAPE_HEIGHT_OFFSET)
    end
    
    # 生成胶带面
    tape_face = parent_group.entities.add_face(elevated_points)
    if tape_face
      # 设置指定颜色的材质
      tape_face.material = color
      tape_face.back_material = color
      
      # 设置胶带属性
      tape_face.set_attribute('FactoryImporter', 'tape_type', 'zone_boundary')
      tape_face.set_attribute('FactoryImporter', 'zone_name', zone_name)
      tape_face.set_attribute('FactoryImporter', 'segment_index', segment_index)
      tape_face.set_attribute('FactoryImporter', 'tape_width', TAPE_WIDTH)
      tape_face.set_attribute('FactoryImporter', 'tape_color', color)
      
      # 确保胶带面在胶带层上
      tape_layer = create_tape_layer
      if tape_layer
        tape_face.layer = tape_layer
      end
      
      puts "【胶带生成】#{zone_name}: 边界段#{segment_index}彩色胶带生成成功"
    else
      puts "【胶带生成】#{zone_name}: 边界段#{segment_index}彩色胶带生成失败"
    end
  end
  
  # 根据区域类型生成不同颜色的胶带
  def self.generate_zone_tapes_by_type(zones_data, parent_group)
    puts "【胶带生成】开始根据区域类型生成彩色胶带..."
    
    zones_data.each_with_index do |zone_data, zone_index|
      begin
        shape = zone_data["shape"]
        next unless shape && shape["points"]
        
        points = shape["points"].map { |point| Utils.validate_and_create_point(point) }.compact
        next if points.size < 3
        
        zone_name = zone_data["name"] || zone_data["id"] || "区域#{zone_index}"
        zone_type = zone_data["type"] || "production"  # 默认生产区域
        
        # 根据区域类型选择颜色
        tape_color = get_tape_color_by_type(zone_type)
        
        puts "【胶带生成】处理区域: #{zone_name} (类型: #{zone_type})"
        
        # 为每个边界线段生成彩色胶带
        (0...points.size).each do |i|
          p1 = points[i]
          p2 = points[(i + 1) % points.size]
          
          generate_colored_tape(p1, p2, zone_name, parent_group, i, tape_color)
        end
        
      rescue => e
        puts "【胶带生成】区域 #{zone_data["name"] || zone_data["id"]} 胶带生成失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    puts "【胶带生成】彩色胶带生成完成"
  end
  
  # 根据区域类型获取胶带颜色
  def self.get_tape_color_by_type(zone_type)
    case zone_type.downcase
    when "production", "生产"
      [255, 255, 0, 255]  # 黄色
    when "office", "办公"
      [0, 255, 0, 255]    # 绿色
    when "storage", "仓储"
      [0, 0, 255, 255]    # 蓝色
    when "danger", "危险"
      [255, 0, 0, 255]    # 红色
    when "safety", "安全"
      [0, 255, 255, 255]  # 青色
    else
      [255, 255, 0, 255]  # 默认黄色
    end
  end

  # 删除重合的胶带部分
  def self.delete_overlapping_tapes(parent_group, shared_boundaries)
    puts "【胶带生成】开始删除重合的胶带部分..."
    
    shared_boundaries.each do |boundary|
      zone1 = boundary[:zone1]
      zone2 = boundary[:zone2]
      shared_segments = boundary[:shared_segments]
      
      puts "【胶带生成】处理重合边界: #{zone1['name']} 与 #{zone2['name']}"
      
      # 为每个共享线段删除重合的胶带
      shared_segments.each do |segment|
        p1, p2 = segment[:segment1]
        delete_tape_at_segment(p1, p2, parent_group)
      end
    end
    
    puts "【胶带生成】重合胶带删除完成"
  end

  # 删除指定线段位置的胶带
  def self.delete_tape_at_segment(start_point, end_point, parent_group)
    # 计算线段的中点
    mid_point = Geom::Point3d.new(
      (start_point.x + end_point.x) / 2.0,
      (start_point.y + end_point.y) / 2.0,
      start_point.z
    )
    
    # 搜索该位置附近的胶带面并删除
    parent_group.entities.grep(Sketchup::Face).each do |face|
      begin
        # 检查是否是胶带面
        tape_type = face.get_attribute('FactoryImporter', 'tape_type')
        next unless tape_type == 'zone_boundary'
        
        # 检查胶带面是否与指定线段重合
        if face_overlaps_segment?(face, start_point, end_point, mid_point)
          zone_name = face.get_attribute('FactoryImporter', 'zone_name') || '未知区域'
          puts "【胶带生成】删除重合胶带: #{zone_name}"
          face.erase!
        end
      rescue => e
        puts "【胶带生成】处理胶带面时出错: #{e.message}"
        next
      end
    end
  end

  # 检查胶带面是否与指定线段重合
  def self.face_overlaps_segment?(face, start_point, end_point, mid_point)
    begin
      # 获取胶带面的边界框
      bounds = face.bounds
      
      # 检查线段是否在胶带面的边界框内
      segment_in_bounds = bounds.contains?(start_point) || bounds.contains?(end_point) || bounds.contains?(mid_point)
      
      # 检查胶带面的中心是否在线段附近
      face_center = bounds.center
      
      # 添加调试信息
      puts "【胶带生成】检查胶带面重合:"
      puts "  - face_center: #{face_center.class} (#{face_center})"
      puts "  - start_point: #{start_point.class} (#{start_point})"
      puts "  - end_point: #{end_point.class} (#{end_point})"
      
      distance_to_segment = distance_point_to_segment(face_center, start_point, end_point)
      
      # 如果胶带面在线段附近且在线段范围内，则认为重合
      segment_in_bounds && distance_to_segment < TAPE_WIDTH
    rescue => e
      puts "【胶带生成】检查胶带面重合时出错: #{e.message}"
      false
    end
  end

  # 计算点到线段的距离
  def self.distance_point_to_segment(point, seg_start, seg_end)
    begin
      # 验证输入参数
      return 0.0 unless point && seg_start && seg_end
      
      # 确保所有点都是有效的Geom::Point3d对象
      unless point.is_a?(Geom::Point3d) && seg_start.is_a?(Geom::Point3d) && seg_end.is_a?(Geom::Point3d)
        return point.distance(seg_start)
      end
      
      # 使用简单的距离计算：点到线段起点的距离
      # 这样可以避免复杂的向量计算可能导致的错误
      return point.distance(seg_start)
    rescue => e
      puts "【胶带生成】计算点到线段距离时出错: #{e.message}"
      # 如果计算出错，返回点到起点的距离作为备选
      point.distance(seg_start)
    end
  end

  # 生成共享边界胶带
  def self.generate_shared_boundary_tapes(zones_data, parent_group)
    puts "【胶带生成】开始生成共享边界胶带..."
    
    # 检测共享边界
    shared_boundaries = Utils.detect_shared_boundaries(zones_data)
    puts "【胶带生成】检测到 #{shared_boundaries.size} 对共享边界"
    
    # 为每个共享边界生成胶带
    shared_boundaries.each do |boundary|
      zone1 = boundary[:zone1]
      zone2 = boundary[:zone2]
      shared_segments = boundary[:shared_segments]
      
      puts "【胶带生成】处理共享边界: #{zone1['name']} 与 #{zone2['name']}"
      
      # 为每个共享线段生成胶带
      shared_segments.each do |segment|
        p1, p2 = segment[:segment1]
        generate_shared_boundary_tape(p1, p2, zone1['name'], zone2['name'], parent_group)
      end
    end
    
    puts "【胶带生成】共享边界胶带生成完成"
  end

  # 生成外部区域边界胶带
  def self.generate_outdoor_zone_boundary_tapes(zones_data, parent_group)
    puts "【胶带生成】开始生成外部区域边界胶带..."
    
    # 创建胶带层
    tape_layer = create_tape_layer
    
    # 第一步：为所有外部区域生成完整的边界胶带
    zones_data.each_with_index do |zone_data, zone_index|
      begin
        shape = zone_data["shape"]
        next unless shape && shape["points"]
        
        points = shape["points"].map { |point| Utils.validate_and_create_point(point) }.compact
        next if points.size < 3
        
        zone_name = zone_data["name"] || zone_data["id"] || "外部区域#{zone_index}"
        puts "【胶带生成】处理外部区域: #{zone_name}"
        
        # 生成该外部区域的完整边界胶带
        generate_single_zone_tape(points, zone_name, parent_group)
        
      rescue => e
        puts "【胶带生成】外部区域 #{zone_data["name"] || zone_data["id"]} 胶带生成失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    # 第二步：检测共享边界
    shared_boundaries = Utils.detect_shared_boundaries(zones_data)
    puts "【胶带生成】检测到 #{shared_boundaries.size} 对共享外部区域边界"
    
    # 第三步：删除重合的胶带部分，重新生成共享边界胶带
    if shared_boundaries.any?
      # 删除重合的胶带部分
      delete_overlapping_tapes(parent_group, shared_boundaries)
      
      # 为外部区域的共享边界重新生成胶带
      generate_shared_boundary_tapes(zones_data, parent_group)
    end
    
    puts "【胶带生成】外部区域边界胶带生成完成"
  end
  
  # 创建专门的胶带层
  def self.create_tape_layer
    model = Sketchup.active_model
    return unless model
    
    # 查找或创建胶带层
    tape_layer = model.layers.find { |layer| layer.name == "胶带层" }
    unless tape_layer
      tape_layer = model.layers.add("胶带层")
      puts "【胶带生成】创建胶带层: #{tape_layer.name}"
    end
    
    return tape_layer
  end
end 