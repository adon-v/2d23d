# 区域构建模块：处理区域的创建和着色
module ZoneBuilder

  # 导入区域
  def self.import_zones(zones_data, parent_group)
    # 检测共享边界
    shared_boundaries = Utils.detect_shared_boundaries(zones_data)
    if shared_boundaries.any?
      puts "检测到 #{shared_boundaries.size} 对紧邻区域，启用优化处理"
      shared_boundaries.each do |boundary|
        puts "  - #{boundary[:zone1][:zone1_name]} 与 #{boundary[:zone2][:zone2_name]} 共享边界"
      end
    end
    
    # 记录已创建的区域，用于后续检查
    created_zones = []
    zones_data.each do |zone_data|
      begin
        shape = zone_data["shape"]
        next unless shape && shape["points"]
        shape_type = shape["type"] || "polygon"
        
        case shape_type.downcase
        when "polygon", "多边形"
          # 使用新的紧邻处理功能
          zone_group = Utils.create_zone_with_adjacency_handling(parent_group, zone_data, created_zones)
          if zone_group
            # 隐藏基础区域平面和边缘线
            hide_base_plane_and_edges(zone_group)
            
            created_zones << zone_group
            puts "成功创建区域: #{zone_data["name"] || zone_data["id"]}"
          else
            puts "跳过创建区域: #{zone_data["name"] || zone_data["id"]} (可能存在冲突)"
          end
        when "rectangle", "矩形"
          # 对于矩形，先转换为多边形处理
          points = shape["points"].map { |point| Utils.validate_and_create_point(point) }
          next if points.size != 4
          # 检查矩形点是否按顺序排列，如果不是则重新排序
          points = Utils.sort_rectangle_points(points)
          # 创建临时的多边形数据
          polygon_zone_data = zone_data.dup
          polygon_zone_data["shape"] = {
            "type" => "polygon",
            "points" => shape["points"]
          }
          # 使用新的紧邻处理功能
          zone_group = Utils.create_zone_with_adjacency_handling(parent_group, polygon_zone_data, created_zones)
          if zone_group
            # 隐藏基础区域平面和边缘线
            hide_base_plane_and_edges(zone_group)
            
            created_zones << zone_group
            puts "成功创建矩形区域: #{zone_data["name"] || zone_data["id"]}"
          else
            puts "跳过创建矩形区域: #{zone_data["name"] || zone_data["id"]} (可能存在冲突)"
          end
        else
          puts "不支持的区域形状类型: #{shape_type}"
        end
      rescue => e
        puts "创建区域失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    # 生成内部区域边界胶带
    TapeBuilder.generate_zone_boundary_tapes(zones_data, parent_group)
    
    # 调用内部区域上色方法
    self.create_indoor_zones_floor(parent_group, zones_data, shared_boundaries)
  end


  # 导入外部区域及围墙
  def self.import_zones_out_factory(zones_data, parent_group)
    # 检测外部区域的共享边界
    shared_boundaries = Utils.detect_shared_boundaries(zones_data)
    if shared_boundaries.any?
      puts "检测到 #{shared_boundaries.size} 对紧邻外部区域，启用优化处理"
      shared_boundaries.each do |boundary|
        puts "  - 外部区域: #{boundary[:zone1][:zone1_name]} 与 #{boundary[:zone2][:zone2_name]} 共享边界"
      end
    end
    
    # 记录已创建的外部区域
    created_outdoor_zones = []
    # 为外部区域创建专门的组
    outdoor_group = parent_group.entities.add_group
    outdoor_group.name = "外部区域组"
    
    zones_data.each_with_index do |zone_data, zone_index|
      begin
        shape = zone_data["shape"]
        next unless shape && shape["points"]
        shape_type = shape["type"] || "polygon"
        points = shape["points"].map { |point| Utils.validate_and_create_point(point) }
        next if points.size < 3
        
        # 使用新的紧邻处理功能创建外部区域
        zone_group = Utils.create_zone_with_adjacency_handling(outdoor_group, zone_data, created_outdoor_zones)
        next unless zone_group
        
        # 隐藏基础区域平面和边缘线
        hide_base_plane_and_edges(zone_group)
        
        # 设置外部区域的特殊材质和属性
        zone_group.entities.grep(Sketchup::Face).each do |face|
          # 只对非基础平面设置材质（避免影响已隐藏的基础面）
          next if face.hidden?
          face.material = [100, 200, 100, 100] # 更明显的绿色
          face.back_material = [100, 200, 100, 100]
        end
        
        # 设置区域属性
        zone_group.set_attribute('FactoryImporter', 'zone_type', 'outdoor')
        zone_group.set_attribute('FactoryImporter', 'zone_id', zone_data["id"])
        zone_group.set_attribute('FactoryImporter', 'zone_name', zone_data["name"])
        created_outdoor_zones << zone_group
        puts "成功创建外部区域: #{zone_data["name"]} (#{zone_data["id"]})"
        
        # 外部区域不生成围墙，只生成胶带
        puts "外部区域 #{zone_data["name"]} 只生成胶带，不生成围墙"
        puts "外部区域 #{zone_data["name"]} 只生成胶带，不生成围墙"
      rescue => e
        puts "创建外部区域失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    # 生成外部区域共享边界胶带
    TapeBuilder.generate_outdoor_zone_boundary_tapes(zones_data, outdoor_group)
    
    # 为外部区域创建地面着色
    create_outdoor_zones_floor(outdoor_group, zones_data, shared_boundaries)
  end
  
  # 隐藏基础区域平面和边缘线的通用方法
  def self.hide_base_plane_and_edges(zone_group)
    # 遍历组内所有面，识别并隐藏基础平面（通常是Z=0的面）
    zone_group.entities.grep(Sketchup::Face).each do |face|
      # 判断是否为基础平面（Z坐标接近0）
      is_base_plane = face.vertices.all? { |v| v.position.z.abs < 0.01 }
      
      if is_base_plane
        # 隐藏基础平面
        face.hidden = true
        
        # 隐藏该面的所有边缘线
        face.edges.each do |edge|
          edge.hidden = true
        end
      end
    end
  end
  
  # 为外部区域创建地面着色
  def self.create_outdoor_zones_floor(parent_group, zones_data, shared_boundaries = [])
    return if !zones_data || zones_data.empty?
    
    # 外部区域专用颜色
    outdoor_colors = {
      "空压机房" => [100, 200, 100],      # 绿色
      "废气处理区" => [150, 100, 50],     # 棕色
      "非标零星钣金打磨" => [200, 150, 100], # 橙色
      "喷粉原材区" => [100, 150, 200],    # 蓝色
      "喷粉废品区" => [200, 100, 100],    # 红色
      "机修房" => [150, 100, 150],        # 紫色
      "油品仓库" => [100, 100, 150],      # 深蓝色
      "default" => [120, 180, 120]        # 默认绿色
    }
    
    has_adjacent_zones = shared_boundaries.any?
    zones_data.each_with_index do |zone, idx|
      shape = zone["shape"]
      next unless shape && shape["points"]
      
      points = shape["points"].map { |p| Utils.validate_and_create_point(p) }
      next if points.size < 3
      
      # 优化点序列
      optimized_points = Utils.optimize_zone_points(points, zone["name"])
      
      # 如果有紧邻区域，添加微小偏移
      if has_adjacent_zones
        is_adjacent = shared_boundaries.any? do |boundary|
          boundary[:zone1][:zone1_id] == zone["id"] || boundary[:zone2][:zone2_id] == zone["id"]
        end
        if is_adjacent
          optimized_points = Utils.add_zone_offset(optimized_points, zone["id"], 0.001)
        end
      end
      
      # 外部区域地面上浮高度调整为0.2（解决抢面问题）
      optimized_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.2) }
      
      begin
        face = parent_group.entities.add_face(optimized_points)
        if face && face.valid?
          zone_name = zone["name"] || "default"
          color = outdoor_colors[zone_name] || outdoor_colors["default"] || [120, 180, 120]
          face.material = color
          face.back_material = color
          
          # 设置面的属性
          face.set_attribute('FactoryImporter', 'face_type', 'outdoor_floor')
          face.set_attribute('FactoryImporter', 'zone_id', zone["id"])
          face.set_attribute('FactoryImporter', 'zone_name', zone_name)
          
          # 隐藏外部区域地面的边缘线
          face.edges.each do |edge|
            edge.hidden = true
          end
        else
          puts "警告: 无法创建外部区域地面着色: #{zone["name"] || zone["id"]}"
        end
      rescue => e
        puts "创建外部区域地面着色失败: #{zone["name"] || zone["id"]} - #{e.message}"
      end
    end
  end
  
  # 生成工厂总地面（所有区域和外墙点的凸包）
  def self.generate_factory_total_ground(parent_group, zones_data, walls_data)
    # 收集所有区域和外墙的点
    all_points = []
    
    # 区域点
    if zones_data
      zones_data.each do |zone|
        shape = zone["shape"]
        next unless shape && shape["points"]
        pts = shape["points"].map { |p| Utils.validate_and_create_point(p) }
        all_points.concat(pts)
      end
    end
    
    # 外墙点
    if walls_data
      walls_data.each do |wall|
        start_point = wall["start"]
        all_points << Utils.validate_and_create_point(start_point) if start_point
        end_point = wall["end"]
        all_points << Utils.validate_and_create_point(end_point) if end_point
      end
    end
    
    all_points = all_points.compact
    return if all_points.size < 3
    
    hull = Utils.compute_convex_hull_2d(all_points)
    return if hull.size < 3
    
    # 生成总地面（Z轴位置设为0，作为基准）
    ground_face = parent_group.entities.add_face(hull)
    if ground_face
      ground_face.material = [0, 128, 64]
      ground_face.back_material = [0, 128, 64]
      
      # 隐藏大地面的边缘线
      ground_face.edges.each do |edge|
        edge.hidden = true
      end
    end
  end
  
  # 内部区域地面着色（修复上色和抢面问题）
  def self.create_indoor_zones_floor(parent_group, zones_data, shared_boundaries = [])
    return if !zones_data || zones_data.empty?
    
    # 内部区域专用颜色映射
    func_colors = {
      "装配区" => [255, 255, 204],    # 浅黄色
      "加工区" => [204, 255, 204],    # 浅绿色
      "仓储区" => [204, 204, 255],    # 浅蓝色
      "办公区" => [255, 204, 255],    # 浅粉色
      "质检区" => [255, 204, 153],    # 浅橙色
      "default" => [220, 220, 220]    # 默认灰色
    }
    
    has_adjacent_zones = shared_boundaries.any?
    
    zones_data.each_with_index do |zone, idx|
      shape = zone["shape"]
      next unless shape && shape["points"]
      
      points = shape["points"].map { |p| Utils.validate_and_create_point(p) }
      next if points.size < 3
      
      # 优化点序列
      optimized_points = Utils.optimize_zone_points(points, zone["name"])
      
      # 如果有紧邻区域，添加微小偏移
      if has_adjacent_zones
        is_adjacent = shared_boundaries.any? do |boundary|
          boundary[:zone1][:zone1_id] == zone["id"] || boundary[:zone2][:zone2_id] == zone["id"]
        end
        if is_adjacent
          optimized_points = Utils.add_zone_offset(optimized_points, zone["id"], 0.001)
        end
      end
      
      # 内部区域地面上浮高度调整为0.3（高于外部区域，解决抢面问题）
      optimized_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.3) }
      
      begin
        face = parent_group.entities.add_face(optimized_points)
        if face && face.valid?
          func = (zone["type"] || zone["name"] || "default").to_s
          color = func_colors[func] || func_colors.values[idx % func_colors.size] || [200, 200, 200]
          face.material = color
          face.back_material = color
          
          # 设置面的属性
          face.set_attribute('FactoryImporter', 'face_type', 'indoor_floor')
          face.set_attribute('FactoryImporter', 'zone_id', zone["id"])
          face.set_attribute('FactoryImporter', 'zone_name', zone["name"] || "未命名区域")
          
          # 隐藏区域的边缘线
          face.edges.each do |edge|
            edge.hidden = true
          end
        else
          puts "警告: 无法创建区域地面着色: #{zone["name"] || zone["id"]}"
        end
      rescue => e
        puts "创建区域地面着色失败: #{zone["name"] || zone["id"]} - #{e.message}"
      end
    end
  end
end
    