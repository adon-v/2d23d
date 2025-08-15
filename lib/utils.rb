module Utils
  # 验证并创建点
  def self.validate_and_create_point(point_data)
    return nil unless point_data
    if point_data.is_a?(Geom::Point3d)
      return point_data
    elsif point_data.is_a?(Array)
      x = parse_number(point_data[0])
      y = parse_number(point_data[1])
      z = point_data.size > 2 ? parse_number(point_data[2]) : 0.0
      return nil if x.nil? || y.nil? || z.nil?
      scale_factor = 25.4
      return Geom::Point3d.new(x / scale_factor, y / scale_factor, z / scale_factor)
    end
    nil
  end
  
  # 解析数值
  def self.parse_number(value)
    case value
    when Numeric
      value.to_f
    when String
      begin
        Float(value)
      rescue ArgumentError
        nil
      end
    else
      nil
    end
  end
  
  # 确保字符串是UTF-8编码
  def self.ensure_utf8(str)
    return str unless str.is_a?(String)
    
    if str.encoding == Encoding::ASCII_8BIT
      utf8_str = str.force_encoding(Encoding::UTF_8)
      
      if utf8_str.valid_encoding?
        return utf8_str
      else
        utf8_str = str.force_encoding("Windows-1252").encode(Encoding::UTF_8)
        return utf8_str if utf8_str.valid_encoding?
      end
    else
      return str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '?')
    end
    
    str
  end
  
  # 找到对应的墙体组
  def self.find_wall_group(parent_group, wall_id)
    parent_group.entities.grep(Sketchup::Group).each do |group|
      stored_id = group.get_attribute('FactoryImporter', 'wall_id')
      return group if stored_id == wall_id
    end
    
    parent_group.entities.grep(Sketchup::Group).each do |group|
      return group if group.name == wall_id
    end
    
    wall_id_lower = wall_id.downcase
    parent_group.entities.grep(Sketchup::Group).each do |group|
      return group if group.name.downcase == wall_id_lower
    end
    
    nil
  end
  
  # 对矩形点进行排序
  def self.sort_rectangle_points(points)
    center = Geom::Point3d.new(
      points.map(&:x).sum / points.size,
      points.map(&:y).sum / points.size,
      points.map(&:z).sum / points.size
    )
    
    points.sort_by! do |point|
      Math.atan2(point.y - center.y, point.x - center.x)
    end
    
    points
  end
  
  # 计算二维凸包（Graham scan，忽略z）
  def self.compute_convex_hull_2d(points)
    pts = points.map { |p| Geom::Point3d.new(p.x, p.y, 0) }.uniq { |p| [p.x.round(6), p.y.round(6)] }
    return pts if pts.size <= 3
    pts = pts.sort_by { |p| [p.y, p.x] }
    lower = []
    pts.each do |p|
      while lower.size >= 2 && cross(lower[-2], lower[-1], p) <= 0
        lower.pop
      end
      lower << p
    end
    upper = []
    pts.reverse.each do |p|
      while upper.size >= 2 && cross(upper[-2], upper[-1], p) <= 0
        upper.pop
      end
      upper << p
    end
    (lower[0...-1] + upper[0...-1])
  end
  
  # 叉积计算（用于凸包算法）
  def self.cross(o, a, b)
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
  end
  
  # 2D线段交点（忽略z）
  def self.line_intersection_2d(p1, p2, q1, q2)
    x1, y1 = p1.x, p1.y
    x2, y2 = p2.x, p2.y
    x3, y3 = q1.x, q1.y
    x4, y4 = q2.x, q2.y
    denom = (y4-y3)*(x2-x1) - (x4-x3)*(y2-y1)
    return nil if denom.abs < 1e-8
    ua = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / denom.to_f
    x = x1 + ua * (x2-x1)
    y = y1 + ua * (y2-y1)
    Geom::Point3d.new(x, y, 0)
  end
  
  # 检查两个数组是否接近（用于流程排序）
  def self.arr_close?(a, b, tol=0.001)
    a && b && a.size>=2 && b.size>=2 && (a[0]-b[0]).abs<tol*1000 && (a[1]-b[1]).abs<tol*1000
  end
  
  # 自动排序通道段，确保首尾相连
  def self.sort_corridors(corridors)
    return corridors if corridors.size <= 1
    used = [false]*corridors.size
    result = [corridors[0]]
    used[0] = true
    while result.size < corridors.size
      last = result[-1]
      found = false
      corridors.each_with_index do |c, i|
        next if used[i]
        if arr_close?(c["start"], last["end"]) || arr_close?(c["end"], last["end"]) || 
           arr_close?(c["start"], last["start"]) || arr_close?(c["end"], last["start"]) then
          if arr_close?(c["start"], last["end"]) then 
            result << c; used[i]=true; found=true; break
          elsif arr_close?(c["end"], last["end"]) then 
            c2 = c.dup; c2["start"],c2["end"] = c2["end"],c2["start"]; result << c2; used[i]=true; found=true; break
          elsif arr_close?(c["end"], last["start"]) then 
            c2 = c.dup; c2["start"],c2["end"] = c2["end"],c2["start"]; result.unshift c2; used[i]=true; found=true; break
          elsif arr_close?(c["start"], last["start"]) then 
            result.unshift c; used[i]=true; found=true; break
          end
        end
      end
      break unless found
    end
    result
  end
  
  # ========== 区域处理功能 ==========
  
  # 创建区域并处理相邻关系
  def self.create_zone_with_adjacency_handling(parent_group, zone_data, existing_zones = [])
    zone_id = zone_data["id"]
    zone_name = zone_data["name"] || "Zone_#{zone_id}"
    
    # 修复：正确获取points数据
    shape = zone_data["shape"]
    unless shape && shape["points"]
      puts "警告: 区域 #{zone_name} 缺少shape或points数据"
      return nil
    end
    
    points = shape["points"].map { |p| validate_and_create_point(p) }.compact
    
    return nil if points.size < 3
    
    puts "创建区域: #{zone_name}, 点数: #{points.size}"
    
    optimized_points = optimize_zone_points(points, zone_name)
    
    has_overlap = existing_zones.any? { |z| self.zones_overlap?(z, optimized_points) }
    
    zone_group = parent_group.entities.add_group
    zone_group.name = "Zone_#{zone_id}_#{zone_name}"
    
    begin
      zone_face = zone_group.entities.add_face(optimized_points)
      
      if zone_face && zone_face.valid?
        # 设置区域面材质（半透明灰色）
        zone_face.material = [150, 150, 150, 100]
        zone_face.back_material = [150, 150, 150, 100]
        
        # 隐藏区域面的所有边界线（关键修改：隐藏地面上的边界线）
        zone_face.edges.each do |edge|
          edge.hidden = true
        end
        
        # 存储区域属性信息
        zone_group.set_attribute('FactoryImporter', 'zone_id', zone_id)
        zone_group.set_attribute('FactoryImporter', 'zone_name', zone_name)
        zone_group.set_attribute('FactoryImporter', 'has_adjacency', has_overlap)
        zone_group.set_attribute('FactoryImporter', 'points', points.map { |p| [p.x, p.y, p.z] })
        
        if has_overlap
          zone_group.set_attribute('FactoryImporter', 'overlap_status', 'needs_review')
        end
        
        puts "区域创建成功: #{zone_name}"
        return zone_group
      else
        puts "无法创建区域面: #{zone_name} (ID: #{zone_id})"
        return nil
      end
    rescue => e
      puts "创建区域时出错: #{e.message}\n区域: #{zone_name} (ID: #{zone_id})"
      puts "区域创建错误: #{e.backtrace.join("\n")}"
      return nil
    end
  end
  
  # 检查两个区域是否重叠
  def self.zones_overlap?(zone_group, points)
    zone_points = zone_group.get_attribute('FactoryImporter', 'points')
    return false unless zone_points
    
    zone_bounds = self.calculate_bounds(zone_points)
    new_bounds = self.calculate_bounds(points)
    
    !(new_bounds[:min_x] > zone_bounds[:max_x] || 
      new_bounds[:max_x] < zone_bounds[:min_x] || 
      new_bounds[:min_y] > zone_bounds[:max_y] || 
      new_bounds[:max_y] < zone_bounds[:min_y])
  end
  
  # 计算点集的边界框
  def self.calculate_bounds(points)
    return {} if points.empty?
    
    points_3d = points.map { |p| p.is_a?(Array) ? Geom::Point3d.new(p[0], p[1], p[2]) : p }
    
    {
      min_x: points_3d.map(&:x).min,
      max_x: points_3d.map(&:x).max,
      min_y: points_3d.map(&:y).min,
      max_y: points_3d.map(&:y).max,
      min_z: points_3d.map(&:z).min,
      max_z: points_3d.map(&:z).max
    }
  end
  
  # 检查两个点是否相同（考虑精度误差）
  def self.points_equal?(p1, p2, tolerance = 0.001)
    return false unless p1 && p2
    (p1.x - p2.x).abs < tolerance && (p1.y - p2.y).abs < tolerance && (p1.z - p2.z).abs < tolerance
  end
  
  # 检查两个线段是否共享边界
  def self.segments_share_boundary?(seg1_start, seg1_end, seg2_start, seg2_end, tolerance = 0.001)
    (points_equal?(seg1_start, seg2_start, tolerance) && points_equal?(seg1_end, seg2_end, tolerance)) ||
    (points_equal?(seg1_start, seg2_end, tolerance) && points_equal?(seg1_end, seg2_start, tolerance)) ||
    (points_equal?(seg1_start, seg2_start, tolerance) && !points_equal?(seg1_end, seg2_end, tolerance)) ||
    (points_equal?(seg1_start, seg2_end, tolerance) && !points_equal?(seg1_end, seg2_start, tolerance)) ||
    (points_equal?(seg1_end, seg2_start, tolerance) && !points_equal?(seg1_start, seg2_end, tolerance)) ||
    (points_equal?(seg1_end, seg2_end, tolerance) && !points_equal?(seg1_start, seg2_start, tolerance))
  end
  
  # 检测区域之间的共享边界
  def self.detect_shared_boundaries(zones_data)
    shared_boundaries = []
    
    zones_data.each_with_index do |zone1, i|
      next unless zone1["shape"] && zone1["shape"]["points"]
      points1 = zone1["shape"]["points"].map { |p| validate_and_create_point(p) }.compact
      next if points1.size < 3
      
      zones_data[(i+1)..-1].each_with_index do |zone2, j|
        next unless zone2["shape"] && zone2["shape"]["points"]
        points2 = zone2["shape"]["points"].map { |p| validate_and_create_point(p) }.compact
        next if points2.size < 3
        
        shared_segments = []
        points1.each_with_index do |p1, idx1|
          p1_next = points1[(idx1 + 1) % points1.size]
          
          points2.each_with_index do |p2, idx2|
            p2_next = points2[(idx2 + 1) % points2.size]
            
            if segments_share_boundary?(p1, p1_next, p2, p2_next)
              shared_segments << {
                zone1_id: zone1["id"],
                zone1_name: zone1["name"],
                zone2_id: zone2["id"], 
                zone2_name: zone2["name"],
                segment1: [p1, p1_next],
                segment2: [p2, p2_next]
              }
            end
          end
        end
        
        if shared_segments.any?
          shared_boundaries << {
            zone1: zone1,
            zone2: zone2,
            shared_segments: shared_segments
          }
        end
      end
    end
    
    shared_boundaries
  end

  # 计算线段长度（忽略Z轴）
  def self.segment_length_2d(p1, p2)
    Math.hypot(p2.x - p1.x, p2.y - p1.y)
  end

  # 线段上的点投影（忽略Z轴）
  def self.project_point_on_segment_2d(point, seg_start, seg_end)
    seg_vec_x = seg_end.x - seg_start.x
    seg_vec_y = seg_end.y - seg_start.y
    
    point_vec_x = point.x - seg_start.x
    point_vec_y = point.y - seg_start.y
    
    seg_len_sq = seg_vec_x**2 + seg_vec_y**2
    
    return seg_start.dup if seg_len_sq < 1e-12
    
    t = (point_vec_x * seg_vec_x + point_vec_y * seg_vec_y) / seg_len_sq
    t = [[t, 0.0].max, 1.0].min
    
    proj_x = seg_start.x + t * seg_vec_x
    proj_y = seg_start.y + t * seg_vec_y
    
    Geom::Point3d.new(proj_x, proj_y, 0)
  end

  # 检查点是否在线段上（忽略Z轴）
  def self.point_on_segment_2d?(point, seg_start, seg_end, tolerance = 0.001)
    cross_product = (seg_end.x - seg_start.x) * (point.y - seg_start.y) - 
                    (seg_end.y - seg_start.y) * (point.x - seg_start.x)
    return false if cross_product.abs > tolerance
    
    dot_product = (point.x - seg_start.x) * (seg_end.x - seg_start.x) + 
                  (point.y - seg_start.y) * (seg_end.y - seg_start.y)
    return false if dot_product < -tolerance
    
    seg_len_sq = (seg_end.x - seg_start.x)**2 + (seg_end.y - seg_start.y)** 2
    return dot_product <= seg_len_sq + tolerance
  end
  
  # 优化区域点，移除重复点并确保正确的方向
  def self.optimize_zone_points(points, zone_name = "")
    return points if points.size < 3
    
    optimized_points = []
    points.each_with_index do |point, i|
      next_point = points[(i + 1) % points.size]
      unless points_equal?(point, next_point)
        optimized_points << point
      end
    end
    
    if optimized_points.size < 3
      puts "警告: 区域 #{zone_name} 优化后点数不足3个，使用原始点"
      return points
    end
    
    if !is_counterclockwise(optimized_points)
      optimized_points.reverse!
    end
    
    optimized_points
  end
  
  # 检查点序列是否为逆时针方向
  def self.is_counterclockwise(points)
    return true if points.size < 3
    
    area = 0
    points.each_with_index do |point, i|
      next_point = points[(i + 1) % points.size]
      area += (next_point.x - point.x) * (next_point.y + point.y)
    end
    
    area < 0
  end
  
  # 为紧邻区域添加微小偏移以避免面冲突
  def self.add_zone_offset(points, zone_id, offset_distance = 0.001)
    return points if points.size < 3
    
    center_x = points.map(&:x).sum / points.size
    center_y = points.map(&:y).sum / points.size
    center_z = points.map(&:z).sum / points.size
    center = Geom::Point3d.new(center_x, center_y, center_z)
    
    offset_points = points.map do |point|
      vec = Geom::Vector3d.new(point.x - center.x, point.y - center.y, 0)
      
      if vec.length < 1e-12
        point.dup
      else
        dir = vec.normalize
        offset_vec = dir * offset_distance
        Geom::Point3d.new(point.x + offset_vec.x, point.y + offset_vec.y, point.z)
      end
    end
    
    offset_points
  end
end
