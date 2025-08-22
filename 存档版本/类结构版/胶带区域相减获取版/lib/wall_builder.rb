# 墙体构建模块：处理墙体的创建和优化
module WallBuilder
  # 导入墙体 - 修复垂直墙体生成（解决向量转换错误）
  def self.import_walls(walls_data, parent_group)
    # 1. 收集所有外墙线段
    outwall_edges = []
    parent_group.entities.grep(Sketchup::Group).each do |group|
      # 全部转换为小写
      name = group.name.downcase
      if name.include?("outwall") || name.include?("外墙")
        # 看看到底有没有东西叫outwall啊
        puts "111"
        group.entities.grep(Sketchup::Face).each do |face|
          face.edges.each do |edge|
            outwall_edges << [edge.start.position, edge.end.position]
          end
        end
      end
    end
    
    cover_faces_points = []
    wall_entities = []
    
    walls_data.each do |wall_data|
      begin
        puts wall_data["start"]
        puts wall_data["end"]
        start_point = Utils.validate_and_create_point(wall_data["start"])
        end_point = Utils.validate_and_create_point(wall_data["end"])
        puts start_point
        puts end_point

        unless start_point && end_point
          puts "跳过无效墙体：起点或终点坐标错误（数据：#{wall_data["start"]} -> #{wall_data["end"]}）"
          next
        end
        scale_factor = 25.4
        # 加个缩放因子
        thickness = Utils.parse_number(wall_data["thickness"] / scale_factor || 0.2)
        puts "t"
        puts thickness
        height = Utils.parse_number(wall_data["height"] / scale_factor || 3.0)
        
        thickness = 0.2 if thickness < 0 || thickness.nil?
        height = 3.0 if height <= 0 || height.nil?
        
        vector = end_point - start_point
        if vector.length < 0.001
          puts "警告: 墙的起点和终点相同，无法创建 (ID: #{wall_data['id'] || '未知'})"
          next
        end
        
        begin
          normal = vector.cross(Geom::Vector3d.new(0, 0, 1)).normalize
          normal = normal.reverse if normal.x < 0
        rescue
          normal = Geom::Vector3d.new(1, 0, 0)
        end
        
        # 2. 判断与外墙重合，仅保留不重合部分
        skip = false
        if thickness > 0 && !outwall_edges.empty?
          outwall_edges.each do |ow_s, ow_e|
            # 判断两线段是否共线且端点重合/极近
            if (start_point.distance(ow_s) < 0.001 && end_point.distance(ow_e) < 0.001) ||
               (start_point.distance(ow_e) < 0.001 && end_point.distance(ow_s) < 0.001)
              skip = true
              break
            end
          end
        end
        
        next if skip
        
        wall_group = create_vertical_wall(wall_data, start_point, end_point, thickness, height, normal, parent_group)
        
        # 确保每个墙体都有唯一的ID
        wall_id = wall_data["id"] || "wall_#{wall_entities.length + 1}"
        wall_name = wall_data["name"] || "墙体_#{wall_id}"
        
        # 设置墙体的唯一标识
        wall_group.set_attribute('FactoryImporter', 'id', wall_id)
        wall_group.set_attribute('FactoryImporter', 'wall_id', wall_id)
        wall_group.set_attribute('FactoryImporter', 'name', wall_name)
        
        # 更新组名称，确保唯一性
        wall_group.name = wall_name
        
        # 存储到实体存储器（独立功能，不影响主流程）
        begin
          EntityStorage.add_entity("wall", wall_group, {
            wall_id: wall_id,
            wall_name: wall_data["name"],
            start_point: wall_data["start"],
            end_point: wall_data["end"],
            thickness: thickness,
            height: height
          })
        rescue => e
          puts "警告: 存储墙体实体失败: #{e.message}"
        end
        
        wall_entities << wall_group
        
        # 收集顶面四点
        if thickness > 0
          begin
            offset_vec = normal.clone
            offset_vec.length = thickness
          rescue
            offset_vec = Geom::Vector3d.new(thickness, 0, 0)
          end
          
          p1 = start_point + Geom::Vector3d.new(0, 0, height)
          p2 = end_point + Geom::Vector3d.new(0, 0, height)
          p3 = end_point + offset_vec + Geom::Vector3d.new(0, 0, height)
          p4 = start_point + offset_vec + Geom::Vector3d.new(0, 0, height)
          
          cover_faces_points << [p1, p2, p3, p4]
        end
      rescue => e
        wall_id = wall_data['id'] || '未知'
        error_msg = "警告: 创建墙体时出错 (ID: #{wall_id}): #{Utils.ensure_utf8(e.message)}"
        puts Utils.ensure_utf8(error_msg)
      end
    end
    
    # 统一在parent_group下生成所有顶面覆盖面
    cover_faces_points.each do |pts|
      face = parent_group.entities.add_face(pts)
      face.material = [255,255,255] if face
      face.back_material = [255,255,255] if face
    end
    
    # 3. 吸附/软化所有墙体公共边
    begin
      all_edges = wall_entities.flat_map { |g| g.entities.grep(Sketchup::Edge) }
      processed = {}
      
      all_edges.combination(2).each do |e1, e2|
        next if e1.deleted? || e2.deleted?
        
        pts1 = [e1.start.position, e1.end.position]
        pts2 = [e2.start.position, e2.end.position]
        
        if (pts1[0].distance(pts2[0]) < 0.001 && pts1[1].distance(pts2[1]) < 0.001) ||
           (pts1[0].distance(pts2[1]) < 0.001 && pts1[1].distance(pts2[0]) < 0.001)
          
          v1 = pts1[1] - pts1[0]; v2 = pts2[1] - pts2[0]
          
          if v1.length > 0.001 && v2.length > 0.001 && (v1.normalize.dot(v2.normalize).abs > 0.999)
            [e1, e2].each do |e|
              next if processed[e]
              e.soft = true if e.respond_to?(:soft=)
              e.smooth = true if e.respond_to?(:smooth=)
              processed[e] = true
            end
          end
        end
      end
    rescue => e
      puts "墙体吸附/软化失败: #{e.message}"
    end
  end
  
  # 创建垂直墙体 - 修复法线方向问题（支持厚度为0的情况）
  def self.create_vertical_wall(wall_data, start_point, end_point, thickness, height, wall_normal, parent_group)
    # 创建墙体组
    wall_group = parent_group.entities.add_group
    wall_group.name = wall_data["name"] || wall_data["id"] || "墙"
    
    if thickness <= 0
      # 厚度为0时：创建单面墙体
      puts "  厚度为0，创建单面墙体"
      
      points = [
        start_point,
        end_point,
        end_point + Geom::Vector3d.new(0, 0, height),
        start_point + Geom::Vector3d.new(0, 0, height)
      ]
      
      face = wall_group.entities.add_face(points)
      face.material = [128, 128, 128] unless face.deleted?
    else

      
      # 【关键优化：确保偏移向量有效】
      begin
        offset_vec = wall_normal.clone
        offset_vec.length = thickness  # 确保偏移距离正确
      rescue
        offset_vec = Geom::Vector3d.new(thickness, 0, 0)  # 默认偏移方向
      end
      
      # 墙体底部四个点
      points_bottom = [
        start_point,
        end_point,
        end_point + offset_vec,
        start_point + offset_vec
      ]
      
      # 墙体顶部四个点（底部点向上偏移height）
      points_top = points_bottom.map { |p| p + Geom::Vector3d.new(0, 0, height) }
      
      # 创建墙体六个面
      faces = []
      
      # 前面
      front_points = [points_bottom[0], points_bottom[1], points_top[1], points_top[0]]
      faces << wall_group.entities.add_face(front_points)
      
      # 后面
      back_points = [points_bottom[2], points_bottom[3], points_top[3], points_top[2]]
      faces << wall_group.entities.add_face(back_points)
      
      # 左面
      left_points = [points_bottom[0], points_bottom[3], points_top[3], points_top[0]]
      faces << wall_group.entities.add_face(left_points)
      
      # 右面
      right_points = [points_bottom[1], points_bottom[2], points_top[2], points_top[1]]
      faces << wall_group.entities.add_face(right_points)
      
      # 顶面
      top_points = [points_top[0], points_top[1], points_top[2], points_top[3]]
      faces << wall_group.entities.add_face(top_points)
      
      # 底面
      bottom_points = [points_bottom[0], points_bottom[1], points_bottom[2], points_bottom[3]]
      faces << wall_group.entities.add_face(bottom_points)
      
      # 设置墙体材质
      faces.each do |face|
        unless face.deleted?
          # 使用默认颜色
          face.material = [128, 128, 128]
          face.back_material = [128, 128, 128]
          
          # 设置面的属性
          face.set_attribute('FactoryImporter', 'face_type', 'wall_face')
          face.set_attribute('FactoryImporter', 'wall_id', wall_data['id'])
        end
      end
    end
    
    wall_group
  end
end 