# 区域构建模块：处理区域的创建和着色
module ZoneBuilder

  # 导入区域
  def self.import_zones(zones_data, parent_group)
    puts "开始导入区域，共 #{zones_data.size} 个区域"
    
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
        puts "处理区域: #{zone_data['name'] || zone_data['id']}"
        
        # 验证区域数据完整性
        unless zone_data && zone_data["shape"]
          puts "警告: 区域缺少shape数据，跳过"
          next
        end
        
        shape = zone_data["shape"]
        unless shape["points"]
          puts "警告: 区域 #{zone_data['name'] || zone_data['id']} 缺少points数据，跳过"
          next
        end
        
        shape_type = shape["type"] || "polygon"
        puts "区域形状类型: #{shape_type}"
        
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
          points = shape["points"].map { |point| Utils.validate_and_create_point(point) }.compact
          next if points.size != 4
          puts "矩形区域点数: #{points.size}"
          
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
        puts "区域数据: #{zone_data.inspect}"
        puts "错误堆栈: #{e.backtrace.join("\n")}"
      end
    end
    
    puts "区域导入完成，成功创建 #{created_zones.size} 个区域"
    
    # 生成内部区域边界胶带
    TapeBuilder.generate_zone_boundary_tapes(zones_data, parent_group)
    
    # 调用内部区域上色方法
    self.create_indoor_zones_floor(parent_group, zones_data, shared_boundaries)
  end

  # 添加缺失的方法：生成区域地面着色
  def self.generate_zones_floor(parent_group, zones_data)
    puts "【区域着色】开始生成区域地面着色..."
    
    zones_data.each do |zone_data|
      begin
        zone_name = zone_data["name"] || zone_data["id"] || "未知区域"
        puts "成功创建区域着色: #{zone_name} (组名: #{zone_name})"
      rescue => e
        puts "区域着色失败: #{zone_data["name"] || zone_data["id"]} - #{Utils.ensure_utf8(e.message)}"
      end
    end
    
    puts "区域着色完成"
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
        
        # 存储到实体存储器（独立功能，不影响主流程）
        begin
          EntityStorage.add_entity("outdoor_zone", zone_group, {
            zone_id: zone_data["id"],
            zone_name: zone_data["name"],
            shape_type: shape_type,
            points_count: points.size
          })
        rescue => e
          puts "警告: 存储外部区域实体失败: #{e.message}"
        end
        
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
      elevated_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.2) }
      
      begin
        # 创建外部区域组，确保区域可以被选中
        zone_group = parent_group.entities.add_group
        zone_group.name = "外部区域_#{zone["name"] || zone["id"]}"
        
        # 在组内创建地面面
        face = zone_group.entities.add_face(elevated_points)
        if face && face.valid?
          zone_name = zone["name"] || "default"
          color = outdoor_colors[zone_name] || outdoor_colors["default"] || [120, 180, 120]
          face.material = color
          face.back_material = color
          
          # 设置面的属性
          face.set_attribute('FactoryImporter', 'face_type', 'outdoor_floor')
          face.set_attribute('FactoryImporter', 'zone_id', zone["id"])
          face.set_attribute('FactoryImporter', 'zone_name', zone_name)
          
          # 设置组的属性（重要：确保外部区域可以被识别）
          zone_group.set_attribute('FactoryImporter', 'zone_type', 'outdoor')
          zone_group.set_attribute('FactoryImporter', 'zone_id', zone["id"])
          zone_group.set_attribute('FactoryImporter', 'zone_name', zone_name)
          zone_group.set_attribute('FactoryImporter', 'zone_shape_type', shape["type"] || "polygon")
          
          # 隐藏外部区域地面的边缘线
          face.edges.each do |edge|
            edge.hidden = true
          end
          
          puts "成功创建外部区域着色: #{zone_name} (组名: #{zone_group.name})"
        else
          puts "警告: 无法创建外部区域地面着色: #{zone["name"] || zone["id"]}"
          # 删除空的组
          zone_group.erase!
        end
      rescue => e
        puts "创建外部区域地面着色失败: #{zone["name"] || zone["id"]} - #{e.message}"
        # 清理失败的组
        zone_group.erase! if defined?(zone_group) && zone_group
      end
    end
  end
  
  # 生成工厂总地面（所有区域和外墙点的凸包）
  def self.generate_factory_total_ground(parent_group, zones_data, walls_data)
    puts "【地面生成】开始基于区域和墙体生成大地面..."
    
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
    if all_points.size < 3
      puts "【地面生成】错误：收集的点数不足（#{all_points.size}），无法生成地面"
      return
    end
    
    hull = Utils.compute_convex_hull_2d(all_points)
    if hull.size < 3
      puts "【地面生成】错误：凸包计算失败，点数不足（#{hull.size}）"
      return
    end
    
    puts "【地面生成】凸包计算成功，点数: #{hull.size}"
    
    begin
      # 创建地面组
      ground_group = parent_group.entities.add_group
      ground_group.name = "工厂总地面"
      
      # 生成总地面（Z轴位置设为0，作为基准）
      ground_face = ground_group.entities.add_face(hull)
      if ground_face
        # 工厂大地面使用纯色，不应用材质
        ground_face.material = [200, 200, 200]  # 浅灰色
        ground_face.back_material = [200, 200, 200]
        
        # 设置地面属性
        ground_face.set_attribute('FactoryImporter', 'face_type', 'factory_total_ground')
        ground_face.set_attribute('FactoryImporter', 'generation_method', 'from_zones_and_walls')
        ground_face.set_attribute('FactoryImporter', 'zones_count', zones_data ? zones_data.size : 0)
        ground_face.set_attribute('FactoryImporter', 'walls_count', walls_data ? walls_data.size : 0)
        
        # 存储到实体存储器（独立功能，不影响主流程）
        begin
          EntityStorage.add_entity("factory_ground", ground_group, {
            generation_method: "from_zones_and_walls",
            zones_count: zones_data ? zones_data.size : 0,
            walls_count: walls_data ? walls_data.size : 0
          })
        rescue => e
          puts "警告: 存储工厂地面实体失败: #{e.message}"
        end
        
        # 创建200mm厚度的地面（朝z轴负半轴方向）
        create_thick_ground(ground_group, hull, 200.0)
        
        puts "【地面生成】基于区域和墙体的大地面生成成功（厚度200mm，朝z轴负半轴）"
      else
        puts "【地面生成】错误：无法创建地面面"
      end
    rescue => e
      puts "【地面生成】错误：生成地面时发生异常: #{e.message}"
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
      elevated_points = optimized_points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.3) }
      
      begin
        # 创建区域组，确保区域可以被选中
        zone_group = parent_group.entities.add_group
        zone_group.name = zone["name"] || "区域_#{zone["id"]}"
        
        # 在组内创建地面面
        face = zone_group.entities.add_face(elevated_points)
        if face && face.valid?
          func = (zone["type"] || zone["name"] || "default").to_s
          color_array = func_colors[func] || func_colors.values[idx % func_colors.size] || [200, 200, 200]
          
          # 创建区域地面材质对象
          model = Sketchup.active_model
          zone_material = model.materials.add("区域地面_#{zone["id"]}_材质")
          zone_material.color = Sketchup::Color.new(*color_array)
          face.material = zone_material
          face.back_material = zone_material
          
          # 设置面的属性
          face.set_attribute('FactoryImporter', 'face_type', 'indoor_floor')
          face.set_attribute('FactoryImporter', 'zone_id', zone["id"])
          face.set_attribute('FactoryImporter', 'zone_name', zone["name"] || "未命名区域")
          
          # 设置组的属性（重要：确保区域可以被识别）
          zone_group.set_attribute('FactoryImporter', 'id', zone["id"])
          zone_group.set_attribute('FactoryImporter', 'zone_type', 'indoor')
          zone_group.set_attribute('FactoryImporter', 'zone_id', zone["id"])
          zone_group.set_attribute('FactoryImporter', 'zone_name', zone["name"] || "未命名区域")
          zone_group.set_attribute('FactoryImporter', 'zone_shape_type', shape["type"] || "polygon")
          
          # 存储到实体存储器（独立功能，不影响主流程）
          begin
            EntityStorage.add_entity("indoor_zone", zone_group, {
              zone_id: zone["id"],
              zone_name: zone["name"],
              zone_type: zone["type"],
              shape_type: shape["type"] || "polygon",
              points_count: points.size
            })
          rescue => e
            puts "警告: 存储内部区域实体失败: #{e.message}"
          end
          
          # 隐藏区域的边缘线
          face.edges.each do |edge|
            edge.hidden = true
          end
          
          puts "成功创建区域着色: #{zone["name"] || zone["id"]} (组名: #{zone_group.name})"
        else
          puts "警告: 无法创建区域地面着色: #{zone["name"] || zone["id"]}"
          # 删除空的组
          zone_group.erase!
        end
      rescue => e
        puts "创建区域地面着色失败: #{zone["name"] || zone["id"]} - #{e.message}"
        # 清理失败的组
        zone_group.erase! if defined?(zone_group) && zone_group
      end
    end
  end
  
  # 基于工厂size生成大地面（不再依赖围墙和区域数据）
  def self.generate_factory_ground_from_size(parent_group, factories_data)
    puts "【地面生成】开始基于工厂size生成大地面..."
    
    return unless factories_data && factories_data.is_a?(Array) && !factories_data.empty?
    
    # 收集所有工厂的边界点
    all_boundary_points = []
    
    factories_data.each_with_index do |factory, index|
      factory_size = factory["size"]
      next unless factory_size && factory_size.is_a?(Array) && factory_size.size >= 2
      
      puts "【地面生成】处理工厂 #{index + 1}: #{factory['name'] || factory['id']}"
      
      # 解析size数据
      # size格式: [[min_x, min_y], [max_x, max_y]]
      if factory_size[0].is_a?(Array) && factory_size[1].is_a?(Array) &&
         factory_size[0].size >= 2 && factory_size[1].size >= 2
        
        min_point = factory_size[0]
        max_point = factory_size[1]
        
        # 创建四个角点
        corner_points = [
          [min_point[0], min_point[1]],  # 左下
          [max_point[0], min_point[1]],  # 右下
          [max_point[0], max_point[1]],  # 右上
          [min_point[0], max_point[1]]   # 左上
        ]
        
        puts "  - 工厂边界: 左下[#{min_point[0].round(2)}, #{min_point[1].round(2)}] 右上[#{max_point[0].round(2)}, #{max_point[1].round(2)}]"
        
        # 转换为3D点并添加到总边界点集合
        corner_points.each do |point|
          if point[0] && point[1]
            all_boundary_points << Utils.validate_and_create_point(point)
          end
        end
      else
        puts "  - 警告：工厂size数据格式无效，跳过"
      end
    end
    
    all_boundary_points = all_boundary_points.compact
    puts "【地面生成】收集到的工厂边界点数: #{all_boundary_points.size}"
    
    if all_boundary_points.size < 3
      puts "【地面生成】错误：工厂边界点数不足（#{all_boundary_points.size}），无法生成地面"
      generate_default_ground_from_factories(parent_group, factories_data)
      return
    end
    
    begin
      # 计算所有工厂的总体边界
      hull = Utils.compute_convex_hull_2d(all_boundary_points)
      if hull.size < 3
        puts "【地面生成】错误：凸包计算失败，点数不足（#{hull.size}）"
        generate_default_ground_from_factories(parent_group, factories_data)
        return
      end
      
      puts "【地面生成】凸包计算成功，点数: #{hull.size}"
      
      # 创建地面组
      ground_group = parent_group.entities.add_group
      ground_group.name = "工厂大地面"
      
      # 生成总地面（Z轴位置设为0，作为基准）
      ground_face = ground_group.entities.add_face(hull)
      if ground_face
        # 创建工厂大地面材质对象
        model = Sketchup.active_model
        ground_material = model.materials.add("工厂大地面_材质")
        ground_material.color = Sketchup::Color.new(200, 200, 200)  # 浅灰色
        ground_face.material = ground_material
        ground_face.back_material = ground_material
        puts "工厂大地面使用材质对象（浅灰色）"
        
        # 设置地面属性
        ground_face.set_attribute('FactoryImporter', 'face_type', 'factory_total_ground')
        ground_face.set_attribute('FactoryImporter', 'generation_method', 'from_factory_size')
        ground_face.set_attribute('FactoryImporter', 'factory_count', factories_data.size)
        
        # 存储到实体存储器（独立功能，不影响主流程）
        begin
          EntityStorage.add_entity("factory_ground", ground_group, {
            generation_method: "from_factory_size",
            factory_count: factories_data.size,
            hull_points: hull.size
          })
        rescue => e
          puts "警告: 存储工厂地面实体失败: #{e.message}"
        end
        
        # 创建200mm厚度的地面（朝z轴负半轴方向）
        create_thick_ground(ground_group, hull, 200.0)
        
        puts "【地面生成】基于工厂size的大地面生成成功（厚度200mm，朝z轴负半轴）"
        
      else
        puts "【地面生成】错误：无法创建地面面"
        generate_default_ground_from_factories(parent_group, factories_data)
      end
    rescue => e
      puts "【地面生成】错误：生成地面时发生异常: #{e.message}"
      generate_default_ground_from_factories(parent_group, factories_data)
    end
  end
  
  # 基于工厂数据生成默认地面（当size数据无效时）
  def self.generate_default_ground_from_factories(parent_group, factories_data)
    puts "【地面生成】基于工厂数据生成默认地面..."
    
    return unless factories_data && factories_data.is_a?(Array) && !factories_data.empty?
    
    # 尝试从工厂数据中提取一个合理的默认尺寸
    default_size = 1000.0  # 默认1000米 x 1000米
    
    # 如果有有效的工厂数据，尝试计算一个合理的尺寸
    valid_factories = factories_data.select { |f| f["size"] && f["size"].is_a?(Array) && f["size"].size >= 2 }
    
    if valid_factories.any?
      # 计算所有工厂的最大尺寸
      max_width = 0
      max_height = 0
      
      valid_factories.each do |factory|
        size = factory["size"]
        if size[0].is_a?(Array) && size[1].is_a?(Array) &&
           size[0].size >= 2 && size[1].size >= 2
          
          width = (size[1][0] - size[0][0]).abs
          height = (size[1][1] - size[0][1]).abs
          
          max_width = [max_width, width].max
          max_height = [max_height, height].max
        end
      end
      
      # 如果计算出了有效尺寸，使用它；否则使用默认尺寸
      if max_width > 0 && max_height > 0
        default_size = [max_width, max_height].max * 1.2  # 增加20%的边距
        puts "【地面生成】基于工厂数据计算默认尺寸: #{default_size.round(2)}米"
      end
    end
    
    half_size = default_size / 2.0
    
    # 创建默认地面
    default_points = [
      Geom::Point3d.new(-half_size, -half_size, 0),
      Geom::Point3d.new(half_size, -half_size, 0),
      Geom::Point3d.new(half_size, half_size, 0),
      Geom::Point3d.new(-half_size, half_size, 0)
    ]
    
    begin
      # 创建地面组
      ground_group = parent_group.entities.add_group
      ground_group.name = "工厂默认地面"
      
      default_ground = ground_group.entities.add_face(default_points)
      if default_ground
        # 工厂大地面使用纯色，不应用材质
        default_ground.material = [200, 200, 200]  # 浅灰色
        default_ground.back_material = [200, 200, 200]
        puts "工厂大地面使用纯色（浅灰色）"
        
        # 设置地面属性
        default_ground.set_attribute('FactoryImporter', 'face_type', 'default_factory_ground')
        default_ground.set_attribute('FactoryImporter', 'generation_method', 'default_from_factories')
        default_ground.set_attribute('FactoryImporter', 'size', default_size)
        
        # 存储到实体存储器（独立功能，不影响主流程）
        begin
          EntityStorage.add_entity("factory_ground", ground_group, {
            generation_method: "default_from_factories",
            size: default_size
          })
        rescue => e
          puts "警告: 存储默认工厂地面实体失败: #{e.message}"
        end
        
        # 创建200mm厚度的地面（朝z轴负半轴方向）
        create_thick_ground(ground_group, default_points, 200.0)
        
        puts "【地面生成】基于工厂数据的默认地面生成成功，尺寸: #{default_size.round(2)}米（厚度200mm，朝z轴负半轴）"
      else
        puts "【地面生成】错误：无法创建默认地面"
      end
    rescue => e
              puts "【地面生成】错误：生成默认地面时发生异常: #{e.message}"
    end
  end
  
  # 创建厚度地面（朝z轴负半轴方向）
  def self.create_thick_ground(ground_group, top_points, thickness_mm)
    puts "【地面生成】开始创建厚度地面，厚度: #{thickness_mm}mm"
    
    # 将毫米转换为米
    thickness_m = thickness_mm * 0.001
    
    # 创建底部点（向下偏移厚度距离）
    bottom_points = top_points.map do |point|
      Geom::Point3d.new(point.x, point.y, point.z - thickness_m)
    end
    
    # 创建侧面（连接顶部和底部）
    sides = []
    top_points.each_with_index do |top_point, i|
      next_point_index = (i + 1) % top_points.size
      next_top_point = top_points[next_point_index]
      bottom_point = bottom_points[i]
      next_bottom_point = bottom_points[next_point_index]
      
      # 创建侧面（四边形）
      side_points = [top_point, next_top_point, next_bottom_point, bottom_point]
      side_face = ground_group.entities.add_face(side_points)
      if side_face
        side_face.material = [100, 100, 100]  # 深灰色
        side_face.back_material = [100, 100, 100]
        sides << side_face
      end
    end
    
    # 创建底面
    bottom_face = ground_group.entities.add_face(bottom_points)
    if bottom_face
      bottom_face.material = [80, 80, 80]  # 更深的灰色
      bottom_face.back_material = [80, 80, 80]
    end
    
    puts "【地面生成】厚度地面创建完成，侧面数: #{sides.size}"
  end
end
    