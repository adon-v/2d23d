# 几何体优化模块：合并和优化mesh以减少数量
module GeometryOptimizer
  @optimization_stats = {
    groups_exploded: 0,
    faces_merged: 0,
    components_merged: 0
  }
  
  # 优化工厂布局模型
  def self.optimize_factory_layout(main_group)
    puts "=== 开始几何体优化 ==="
    
    # 检查是否启用几何体优化
    unless ConfigManager.get(:geometry_optimization)[:enabled]
      puts "⚠️  几何体优化已禁用，跳过优化"
      return
    end
    
    begin
      config = ConfigManager.get(:geometry_optimization)
      
      # 1. 炸开不需要独立交互的组件
      if config[:explode_groups]
        explode_unnecessary_groups(main_group)
      end
      
      # 2. 合并共面面
      if config[:merge_faces]
        merge_coplanar_faces(main_group)
      end
      
      # 3. 合并同类几何体
      if config[:merge_components]
        merge_similar_geometry(main_group)
      end
      
      # 4. 清理孤立边和点
      if config[:cleanup_orphaned]
        cleanup_orphaned_entities(main_group)
      end
      
      # 5. 报告优化结果
      report_optimization_results
      
      puts "✅ 几何体优化完成"
      
    rescue => e
      error_msg = "几何体优化过程中出错: #{Utils.ensure_utf8(e.message)}"
      puts "❌ #{error_msg}"
    end
  end
  
  # 炸开不需要独立交互的组件
  def self.explode_unnecessary_groups(parent_group)
    puts "  🔧 炸开不需要独立交互的组件..."
    
    groups_to_explode = []
    
    parent_group.entities.grep(Sketchup::Group).each do |group|
      if should_explode_group?(group)
        groups_to_explode << group
      end
    end
    
    groups_to_explode.each do |group|
      begin
        group.explode
        @optimization_stats[:groups_exploded] += 1
      rescue => e
        puts "    警告: 炸开组件 #{group.name} 失败: #{e.message}"
      end
    end
    
    puts "    炸开了 #{@optimization_stats[:groups_exploded]} 个组件"
  end
  
  # 判断组件是否应该被炸开
  def self.should_explode_group?(group)
    group_name = group.name.downcase
    
    # 这些类型的组件通常不需要独立交互，可以炸开
    explodeable_types = [
      'wall', '墙体', 'wall_segment', '墙体段',
      'floor', '地板', 'ground', '地面',
      'ceiling', '天花板', 'roof', '屋顶',
      'column', '柱子', 'beam', '梁',
      'zone', '区域', 'area', '区域面'
    ]
    
    return true if explodeable_types.any? { |type| group_name.include?(type) }
    
    # 检查组件是否只包含面
    faces_count = group.entities.grep(Sketchup::Face).size
    other_entities_count = group.entities.size - faces_count
    
    return true if faces_count > 0 && other_entities_count <= 2
    
    false
  end
  
  # 合并共面面
  def self.merge_coplanar_faces(parent_group)
    puts "  🔧 合并共面面..."
    
    faces = parent_group.entities.grep(Sketchup::Face)
    merged_count = 0
    
    faces.each_with_index do |face1, i|
      next unless face1.valid?
      
      faces[(i+1)..-1].each do |face2|
        next unless face2.valid?
        next if face1 == face2
        
        if can_merge_faces?(face1, face2)
          begin
            if merge_faces(face1, face2)
              merged_count += 1
              @optimization_stats[:faces_merged] += 1
            end
          rescue => e
            puts "    警告: 合并面失败: #{e.message}"
          end
        end
      end
    end
    
    puts "    合并了 #{merged_count} 对面"
  end
  
  # 检查两个面是否可以合并
  def self.can_merge_faces?(face1, face2)
    return false unless face1.valid? && face2.valid?
    return false if face1 == face2
    
    # 检查是否共面
    return false unless faces_coplanar?(face1, face2)
    
    # 检查是否有共享边
    shared_edges = face1.edges & face2.edges
    return false if shared_edges.empty?
    
    # 检查材质是否相同
    return false unless faces_same_material?(face1, face2)
    
    true
  end
  
  # 检查两个面是否共面
  def self.faces_coplanar?(face1, face2, tolerance = 0.001)
    normal1 = face1.normal
    normal2 = face2.normal
    
    dot_product = normal1.dot(normal2)
    return false if (dot_product.abs - 1.0).abs > tolerance
    
    point1 = face1.bounds.center
    point2 = face2.bounds.center
    
    distance = (point2 - point1).dot(normal1).abs
    return false if distance > tolerance
    
    true
  end
  
  # 检查两个面是否有相同材质
  def self.faces_same_material?(face1, face2)
    material1 = face1.material
    material2 = face2.material
    
    return true if material1.nil? && material2.nil?
    return false if material1.nil? || material2.nil?
    
    material1 == material2
  end
  
  # 合并两个面
  def self.merge_faces(face1, face2)
    begin
      result = face1.merge(face2)
      return result.is_a?(Sketchup::Face)
    rescue => e
      return false
    end
  end
  
  # 合并同类几何体
  def self.merge_similar_geometry(parent_group)
    puts "  🔧 合并同类几何体..."
    
    geometry_groups = group_geometry_by_type(parent_group)
    
    geometry_groups.each do |type, entities|
      next if entities.size < 2
      
      case type
      when :walls
        merge_walls(entities)
      when :floors
        merge_floors(entities)
      when :zones
        merge_zones(entities)
      end
    end
  end
  
  # 按类型分组几何体
  def self.group_geometry_by_type(parent_group)
    groups = {
      walls: [],
      floors: [],
      zones: []
    }
    
    parent_group.entities.grep(Sketchup::Group).each do |group|
      group_name = group.name.downcase
      
      if group_name.include?('wall') || group_name.include?('墙体')
        groups[:walls] << group
      elsif group_name.include?('floor') || group_name.include?('地板')
        groups[:floors] << group
      elsif group_name.include?('zone') || group_name.include?('区域')
        groups[:zones] << group
      end
    end
    
    groups
  end
  
  # 合并墙体
  def self.merge_walls(wall_groups)
    puts "    合并 #{wall_groups.size} 个墙体组..."
    
    wall_groups_by_height = wall_groups.group_by do |group|
      bounds = group.bounds
      height = bounds.depth
      material = get_group_material(group)
      [height.round(1), material]
    end
    
    wall_groups_by_height.each do |(height, material), groups|
      next if groups.size < 2
      merge_adjacent_walls(groups)
    end
  end
  
  # 合并相邻墙体
  def self.merge_adjacent_walls(wall_groups)
    merged_count = 0
    
    wall_groups.each_with_index do |group1, i|
      next unless group1.valid?
      
      wall_groups[(i+1)..-1].each do |group2|
        next unless group2.valid?
        
        if walls_adjacent?(group1, group2)
          begin
            if merge_wall_groups(group1, group2)
              merged_count += 1
              @optimization_stats[:components_merged] += 1
            end
          rescue => e
            puts "      警告: 合并墙体失败: #{e.message}"
          end
        end
      end
    end
    
    puts "      合并了 #{merged_count} 对相邻墙体"
  end
  
  # 检查两个墙体是否相邻
  def self.walls_adjacent?(group1, group2, tolerance = 1.0)
    bounds1 = group1.bounds
    bounds2 = group2.bounds
    
    return false if bounds1.max.x < bounds2.min.x - tolerance
    return false if bounds1.min.x > bounds2.max.x + tolerance
    return false if bounds1.max.y < bounds2.min.y - tolerance
    return false if bounds1.min.y > bounds2.max.y + tolerance
    return false if bounds1.max.z < bounds2.min.z - tolerance
    return false if bounds1.min.z > bounds2.max.z + tolerance
    
    true
  end
  
  # 合并墙体组
  def self.merge_wall_groups(group1, group2)
    begin
      entities_to_move = group2.entities.to_a
      
      entities_to_move.each do |entity|
        next unless entity.valid?
        
        case entity
        when Sketchup::Face
          group1.entities.add_face(entity.vertices.map(&:position))
        when Sketchup::Edge
          group1.entities.add_line(entity.start.position, entity.end.position)
        end
      end
      
      group2.erase!
      true
    rescue => e
      false
    end
  end
  
  # 获取组的材质
  def self.get_group_material(group)
    group.entities.grep(Sketchup::Face).each do |face|
      return face.material if face.material
    end
    nil
  end
  
  # 合并地板
  def self.merge_floors(floor_groups)
    puts "    合并 #{floor_groups.size} 个地板组..."
  end
  
  # 合并区域
  def self.merge_zones(zone_groups)
    puts "    合并 #{zone_groups.size} 个区域组..."
  end
  
  # 清理孤立的边和点
  def self.cleanup_orphaned_entities(parent_group)
    puts "  🔧 清理孤立实体..."
    
    orphaned_edges = parent_group.entities.grep(Sketchup::Edge).select do |edge|
      edge.faces.empty?
    end
    
    orphaned_edges.each do |edge|
      edge.erase! if edge.valid?
    end
    
    orphaned_vertices = parent_group.entities.grep(Sketchup::Vertex).select do |vertex|
      vertex.edges.empty?
    end
    
    orphaned_vertices.each do |vertex|
      vertex.erase! if vertex.valid?
    end
    
    puts "    清理了 #{orphaned_edges.size} 条孤立边和 #{orphaned_vertices.size} 个孤立点"
  end
  
  # 报告优化结果
  def self.report_optimization_results
    puts "\n=== 几何体优化结果 ==="
    puts "炸开的组件: #{@optimization_stats[:groups_exploded]} 个"
    puts "合并的面: #{@optimization_stats[:faces_merged]} 对"
    puts "合并的组件: #{@optimization_stats[:components_merged]} 对"
  end
  
  # 获取优化统计
  def self.get_optimization_stats
    @optimization_stats.dup
  end
  
  # 重置优化统计
  def self.reset_optimization_stats
    @optimization_stats = {
      groups_exploded: 0,
      faces_merged: 0,
      components_merged: 0
    }
  end
  
  # 检查是否应该进行优化
  def self.should_optimize?(parent_group)
    # 检查是否启用自动优化
    config = ConfigManager.get(:geometry_optimization)
    return false unless config[:auto_optimize]
    
    total_entities = parent_group.entities.size
    groups_count = parent_group.entities.grep(Sketchup::Group).size
    faces_count = parent_group.entities.grep(Sketchup::Face).size
    
    threshold = config[:optimization_threshold]
    
    return true if total_entities > threshold[:total_entities]
    return true if groups_count > threshold[:groups_count]
    return true if faces_count > threshold[:faces_count]
    
    false
  end
  
  # 分析几何体
  def self.analyze_geometry(parent_group)
    {
      total_entities: parent_group.entities.size,
      groups_count: parent_group.entities.grep(Sketchup::Group).size,
      faces_count: parent_group.entities.grep(Sketchup::Face).size,
      edges_count: parent_group.entities.grep(Sketchup::Edge).size
    }
  end
end
