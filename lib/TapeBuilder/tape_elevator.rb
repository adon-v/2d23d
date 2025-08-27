require_relative 'tape_constants'

module TapeBuilder
  class TapeElevator
    # 功能开关：设置为false时关闭拉高操作（现在使用简单上浮）
    ENABLE_ELEVATION = false
    
    # 将胶带平面拉高到适当高度（此功能已废弃，现在使用简单上浮）
    def self.elevate_tape(tape_face, height, elevation, parent_group)
      # 检查功能开关
      unless ENABLE_ELEVATION
        puts "调试：拉高功能已关闭，现在使用简单上浮方法"
        return tape_face
      end
      
      begin
        # 检查面是否有效
        if !tape_face || !tape_face.valid?
          puts "警告：无效的胶带面，跳过拉高操作"
          return
        end
        
        puts "调试：开始拉高胶带，初始面有效性: #{tape_face.valid?}"
        puts "调试：初始面顶点数: #{tape_face.vertices.length}"
        puts "调试：初始面边数: #{tape_face.edges.length}"
        puts "调试：初始面法线: #{tape_face.normal.to_s}"
        
        # 检测并处理相邻面冲突
        puts "调试：检测相邻面冲突"
        adjacent_faces = find_adjacent_faces(tape_face, parent_group)
        if !adjacent_faces.empty?
          puts "调试：发现 #{adjacent_faces.length} 个相邻面，尝试调整几何以避免冲突"
          tape_face = adjust_geometry_for_adjacent_faces(tape_face, adjacent_faces, parent_group)
          return nil unless tape_face
        end
        
        # 保存原始面的引用和属性
        original_face_id = tape_face.entityID
        original_vertices = tape_face.vertices.map { |v| v.position.dup }
        original_material = tape_face.material
        original_back_material = tape_face.back_material
        
        # 上浮胶带面
        if elevation > 0
          # 创建上浮变换
          transform = Geom::Transformation.translation([0, 0, elevation])
          
          puts "调试：准备上浮胶带面，高度: #{elevation}"
          
          # 使用更安全的变换方法
          begin
            # 先检查面是否仍然有效
            if !tape_face.valid?
              puts "警告：上浮前胶带面已失效，尝试恢复"
              tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
              return nil unless tape_face
            end
            
            # 直接变换整个面，而不是单独变换顶点
            entities = parent_group.entities
            new_face = entities.transform_entities(transform, tape_face)
            
            # 如果变换返回了新面，使用新面
            if new_face.is_a?(Array) && !new_face.empty? && new_face[0].is_a?(Sketchup::Face)
              tape_face = new_face[0]
              puts "调试：上浮后获得新面，有效性: #{tape_face.valid?}"
            else
              puts "调试：上浮后未获得新面，返回类型: #{new_face.class}"
              # 检查原始面是否仍然有效
              if !tape_face.valid?
                puts "警告：上浮后胶带面失效，尝试恢复"
                tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
                return nil unless tape_face
              end
            end
          rescue => e
            puts "调试：上浮操作出错: #{e.message}"
            # 尝试恢复面
            tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
            return nil unless tape_face
          end
        end
        
        # 再次检查面是否有效
        if !tape_face.valid?
          puts "警告：上浮后胶带面无效，尝试恢复"
          tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
          return nil unless tape_face
        end
        
        puts "调试：上浮后面顶点数: #{tape_face.vertices.length}"
        puts "调试：上浮后面边数: #{tape_face.edges.length}"
        puts "调试：上浮后面法线: #{tape_face.normal.to_s}"
        
        # 检查面的几何形状是否平面
        is_planar = true
        vertices = tape_face.vertices
        if vertices.length > 3
          normal = tape_face.normal
          first_vertex = vertices[0].position
          for i in 1...vertices.length
            vertex = vertices[i].position
            vector = Geom::Vector3d.new(vertex.x - first_vertex.x, 
                                       vertex.y - first_vertex.y, 
                                       vertex.z - first_vertex.z)
            if (vector.dot(normal)).abs > 0.001
              is_planar = false
              puts "调试：面不是完全平面的，可能影响pushpull操作"
              break
            end
          end
        end
        puts "调试：面的平面性检查结果: #{is_planar ? '平面' : '非平面'}"
        
        # 检查并修复可能的几何问题
        if !is_planar
          puts "调试：尝试修复非平面面"
          begin
            # 尝试通过重新创建面来修复
            vertices_positions = tape_face.vertices.map { |v| v.position }
            
            # 删除原来的面
            old_face_id = tape_face.entityID
            parent_group.entities.erase_entities(tape_face)
            
            # 尝试重新创建面
            new_face = nil
            begin
              new_face = parent_group.entities.add_face(vertices_positions)
              if new_face && new_face.valid?
                puts "调试：成功重新创建面"
                tape_face = new_face
                
                # 重新应用材质
                if original_material
                  tape_face.material = original_material
                end
                if original_back_material
                  tape_face.back_material = original_back_material
                end
                
                # 确保法线朝上
                if tape_face.normal.z < 0
                  tape_face.reverse!
                end
              else
                puts "调试：重新创建面失败"
              end
            rescue => e
              puts "调试：重新创建面时出错: #{e.message}"
            end
          rescue => e
            puts "调试：修复几何问题时出错: #{e.message}"
          end
        end
        
        # 拉高胶带
        if height > 0
          begin
            puts "调试：开始pushpull操作，高度: #{height}"
            
            # 再次检查面是否有效
            if !tape_face.valid?
              puts "警告：pushpull前胶带面失效，尝试恢复"
              tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
              return nil unless tape_face
            end
            
            # 尝试使用不同的方法进行拉高
            result = nil
            
            # 方法1：直接使用pushpull
            begin
              result = tape_face.pushpull(height)
              if result
                puts "调试：标准pushpull操作成功"
              else
                puts "调试：标准pushpull操作失败，尝试替代方法"
              end
            rescue => e
              puts "调试：标准pushpull出错: #{e.message}"
            end
            
            # 如果标准pushpull失败，尝试替代方法
            if !result
              puts "调试：尝试替代拉高方法"
              
              # 方法2：使用API的extrude方法
              begin
                # 再次检查面是否有效
                if !tape_face.valid?
                  puts "警告：替代方法前胶带面失效，尝试恢复"
                  tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
                  return nil unless tape_face
                end
                
                # 获取面的边界
                edges = tape_face.outer_loop.edges
                
                # 创建拉高向量
                extrude_vector = Geom::Vector3d.new(0, 0, height)
                
                # 创建组以包含拉高结果
                group = parent_group.entities.add_group
                
                # 复制原始面到组中
                face_copy = group.entities.add_face(tape_face.vertices.map { |v| v.position })
                
                # 执行拉高
                result = face_copy.pushpull(height)
                
                if result
                  puts "调试：组内pushpull操作成功"
                  # 将组爆炸回原始实体集合
                  group.explode
                  result = true
                else
                  puts "调试：组内pushpull操作失败，尝试手动拉高"
                  
                  # 方法3：手动创建侧面和顶面
                  begin
                    # 获取顶点位置
                    vertices = tape_face.vertices
                    bottom_vertices = vertices.map { |v| v.position }
                    
                    # 创建顶部顶点
                    top_vertices = bottom_vertices.map { |v| 
                      Geom::Point3d.new(v.x, v.y, v.z + height)
                    }
                    
                    # 创建顶面
                    top_face = parent_group.entities.add_face(top_vertices)
                    
                    # 创建侧面
                    side_faces = []
                    vertices.length.times do |i|
                      next_i = (i + 1) % vertices.length
                      side_face = parent_group.entities.add_face([
                        bottom_vertices[i],
                        bottom_vertices[next_i],
                        top_vertices[next_i],
                        top_vertices[i]
                      ])
                      side_faces << side_face if side_face && side_face.valid?
                    end
                    
                    if top_face && top_face.valid? && !side_faces.empty?
                      puts "调试：手动拉高成功"
                      result = true
                    else
                      puts "调试：手动拉高失败"
                    end
                  rescue => e
                    puts "调试：手动拉高出错: #{e.message}"
                  end
                  
                  # 清理临时组
                  parent_group.entities.erase_entities(group) if group && group.valid?
                end
              rescue => e
                puts "调试：替代拉高方法出错: #{e.message}"
                # 尝试恢复面
                tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
                return nil unless tape_face
              end
            end
            
            # 如果仍然失败，记录详细的诊断信息
            if !result
              puts "警告：pushpull操作失败，可能是几何体问题"
              
              # 检查面是否仍然有效
              if !tape_face.valid?
                puts "警告：pushpull失败后胶带面失效，尝试恢复"
                tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
                return nil unless tape_face
              end
              
              puts "调试：检查面的边界情况:"
              
              # 检查面的边界是否有问题
              edges = tape_face.edges
              puts "调试：边数量: #{edges.length}"
              edges.each_with_index do |edge, index|
                puts "调试：边#{index} 长度: #{edge.length}, 起点: #{edge.start.position}, 终点: #{edge.end.position}"
                puts "调试：边#{index} 关联面数: #{edge.faces.length}"
              end
              
              # 检查面的环是否闭合
              loops = tape_face.loops
              puts "调试：环数量: #{loops.length}"
              loops.each_with_index do |loop, index|
                puts "调试：环#{index} 边数: #{loop.edges.length}, 是否外环: #{loop.outer?}"
              end
            else
              puts "调试：pushpull操作成功完成"
              
              # 在pushpull成功后，找到所有相关的面
              puts "调试：查找pushpull后产生的所有面"
              all_tape_faces = find_all_tape_faces(tape_face, parent_group)
              puts "调试：找到 #{all_tape_faces.length} 个胶带面"
              
              # 返回包含所有面的数组，这样材质应用器就能为整个立方体应用材质
              return all_tape_faces
            end
          rescue => e
            puts "拉高时出错: #{e.message}"
            puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
            
            # 尝试恢复面
            tape_face = restore_face_from_vertices(original_vertices, original_material, original_back_material, parent_group)
            return nil unless tape_face
          end
        end
        
        return tape_face
      rescue => e
        puts "拉高胶带时出错: #{e.message}"
        puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
        return nil
      end
    end

    private

    # 检测相邻面
    def self.find_adjacent_faces(tape_face, parent_group)
      adjacent_faces = []
      
      begin
        if tape_face && tape_face.valid?
          # 获取当前面的边界框
          current_bounds = tape_face.bounds
          tolerance = 0.01 # 减少容差到1cm，避免误判共享边界的面
          
          # 在父组中查找所有面
          parent_group.entities.each do |entity|
            if entity.is_a?(Sketchup::Face) && entity.valid? && entity != tape_face
              # 检查面是否相邻
              if is_face_adjacent(entity, current_bounds, tolerance)
                adjacent_faces << entity
              end
            end
          end
        end
        
        puts "调试：找到 #{adjacent_faces.length} 个相邻面"
        
      rescue => e
        puts "检测相邻面时出错: #{e.message}"
      end
      
      adjacent_faces
    end

    # 检查面是否相邻
    def self.is_face_adjacent(face, reference_bounds, tolerance)
      return false unless face && face.valid? && reference_bounds
      
      # 获取面的边界框
      face_bounds = face.bounds
      
      # 检查边界框是否重叠或非常接近
      # 扩展参考边界框以包含容差
      expanded_bounds = Geom::BoundingBox.new
      expanded_bounds.add(Geom::Point3d.new(
        reference_bounds.min.x - tolerance,
        reference_bounds.min.y - tolerance,
        reference_bounds.min.z - tolerance
      ))
      expanded_bounds.add(Geom::Point3d.new(
        reference_bounds.max.x + tolerance,
        reference_bounds.max.y + tolerance,
        reference_bounds.max.z + tolerance
      ))
      
      # 检查是否有重叠 - 使用正确的SketchUp API方法
      # 检查两个边界框是否相交
      return bounds_intersect(expanded_bounds, face_bounds)
    end

    # 检查两个边界框是否相交
    def self.bounds_intersect(bounds1, bounds2)
      return false unless bounds1 && bounds2
      
      # 检查是否有重叠：一个边界框的最小值小于另一个的最大值
      return !(bounds1.max.x < bounds2.min.x || 
               bounds1.min.x > bounds2.max.x ||
               bounds1.max.y < bounds2.min.y || 
               bounds1.min.y > bounds2.max.y ||
               bounds1.max.z < bounds2.min.z || 
               bounds1.min.z > bounds2.max.z)
    end

    # 调整几何以避免相邻面冲突
    def self.adjust_geometry_for_adjacent_faces(tape_face, adjacent_faces, parent_group)
      begin
        puts "调试：开始调整几何以避免相邻面冲突"
        
        # 获取当前面的顶点
        vertices = tape_face.vertices.map { |v| v.position.dup }
        material = tape_face.material
        back_material = tape_face.back_material
        
        # 检查是否真的需要调整（避免误判共享边界的面）
        if !really_needs_adjustment(vertices, adjacent_faces)
          puts "调试：检测到共享边界的面，无需调整几何"
          return tape_face
        end
        
        # 计算调整后的顶点位置
        adjusted_vertices = calculate_adjusted_vertices(vertices, adjacent_faces)
        
        if adjusted_vertices && adjusted_vertices.length == vertices.length
          puts "调试：成功计算调整后的顶点位置"
          
          # 检查调整后的顶点是否仍然有效（不是所有点都在同一位置）
          if vertices_are_valid(adjusted_vertices)
            puts "调试：调整后的顶点有效，继续处理"
            
            # 去除重复顶点
            unique_adjusted_vertices = remove_duplicate_vertices(adjusted_vertices)
            puts "调试：调整后顶点数: #{adjusted_vertices.length}, 去重后顶点数: #{unique_adjusted_vertices.length}"
            
            # 检查是否有足够的顶点创建面
            if unique_adjusted_vertices.length < 3
              puts "警告：去重后顶点数不足，无法创建调整后的面"
              puts "调试：尝试使用原始顶点创建面"
              # 如果调整失败，尝试使用原始顶点
              unique_adjusted_vertices = remove_duplicate_vertices(vertices)
              if unique_adjusted_vertices.length < 3
                puts "警告：原始顶点也无法创建有效面"
                return nil
              end
            end
            
            # 删除原来的面
            parent_group.entities.erase_entities(tape_face)
            
            # 创建调整后的面
            new_face = parent_group.entities.add_face(unique_adjusted_vertices)
            
            if new_face && new_face.valid?
              puts "调试：成功创建调整后的面"
              
              # 应用材质
              if material
                new_face.material = material
              end
              if back_material
                new_face.back_material = back_material
              end
              
              # 确保法线朝上
              if new_face.normal.z < 0
                new_face.reverse!
              end
              
              return new_face
            else
              puts "警告：创建调整后的面失败"
              return nil
            end
          else
            puts "警告：调整后的顶点无效，跳过几何调整"
            return tape_face
          end
        else
          puts "警告：计算调整后的顶点位置失败"
          return nil
        end
        
      rescue => e
        puts "调整几何时出错: #{e.message}"
        puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
        return nil
      end
    end

    # 检查是否真的需要调整（避免误判共享边界的面）
    def self.really_needs_adjustment(vertices, adjacent_faces)
      return false if adjacent_faces.empty?
      
      # 检查是否只是共享边界（这是正常情况，不需要调整）
      # 如果相邻面与当前面共享边界，且没有重叠，则不需要调整
      adjacent_faces.each do |adjacent_face|
        if adjacent_face.valid?
          # 检查是否有真正的几何冲突，而不仅仅是共享边界
          if has_real_geometry_conflict(vertices, adjacent_face)
            return true
          end
        end
      end
      
      false
    end

    # 检查是否有真正的几何冲突
    def self.has_real_geometry_conflict(vertices, adjacent_face)
      return false unless adjacent_face.valid?
      
      # 检查顶点是否真的与相邻面重叠，而不仅仅是共享边界
      # 使用更严格的检查，避免误判共享边界的情况
      tolerance = 0.001 # 1mm的容差
      
      # 首先检查是否只是共享边界（这是正常情况）
      if is_just_shared_boundary(vertices, adjacent_face)
        puts "调试：检测到共享边界，不是真正的几何冲突"
        return false
      end
      
      vertices.each do |vertex|
        if is_vertex_inside_face(vertex, adjacent_face, tolerance)
          puts "调试：顶点 (#{vertex.x}, #{vertex.y}, #{vertex.z}) 在相邻面内部，检测到真正的几何冲突"
          return true
        end
      end
      
      false
    end

    # 检查是否只是共享边界
    def self.is_just_shared_boundary(vertices, adjacent_face)
      return false unless adjacent_face.valid?
      
      # 获取相邻面的顶点
      adjacent_vertices = adjacent_face.vertices.map { |v| v.position }
      
      # 检查是否有共享的顶点（共享边界的情况）
      shared_vertices = 0
      vertices.each do |vertex|
        adjacent_vertices.each do |adj_vertex|
          if vertex.distance(adj_vertex) < 0.001
            shared_vertices += 1
            break
          end
        end
      end
      
      # 如果有共享顶点，检查是否只是边界共享
      if shared_vertices > 0
        puts "调试：发现 #{shared_vertices} 个共享顶点，检查是否为边界共享"
        
        # 检查两个面的边界框是否只是边界接触，而不是重叠
        current_bounds = get_vertices_bounds(vertices)
        adjacent_bounds = adjacent_face.bounds
        
        # 如果两个面的边界框只是边界接触，则认为是共享边界
        if bounds_just_touch(current_bounds, adjacent_bounds)
          puts "调试：边界框只是边界接触，确认为共享边界"
          return true
        end
      end
      
      false
    end

    # 获取顶点的边界框
    def self.get_vertices_bounds(vertices)
      return nil if vertices.nil? || vertices.empty?
      
      bounds = Geom::BoundingBox.new
      vertices.each do |vertex|
        bounds.add(vertex)
      end
      bounds
    end

    # 检查两个边界框是否只是边界接触
    def self.bounds_just_touch(bounds1, bounds2)
      return false unless bounds1 && bounds2
      
      # 检查是否只是边界接触（一个维度完全接触，其他维度不重叠）
      x_touch = (bounds1.max.x - bounds2.min.x).abs < 0.001 || (bounds2.max.x - bounds1.min.x).abs < 0.001
      y_touch = (bounds1.max.y - bounds2.min.y).abs < 0.001 || (bounds2.max.y - bounds1.min.y).abs < 0.001
      z_touch = (bounds1.max.z - bounds2.min.z).abs < 0.001 || (bounds2.max.z - bounds1.min.z).abs < 0.001
      
      # 检查是否有重叠
      x_overlap = bounds1.max.x > bounds2.min.x && bounds1.min.x < bounds2.max.x
      y_overlap = bounds1.max.y > bounds2.min.y && bounds1.min.y < bounds2.max.y
      z_overlap = bounds1.max.z > bounds2.min.z && bounds1.min.z < bounds2.max.z
      
      # 如果只是边界接触（一个维度接触，其他维度不重叠），则认为是共享边界
      if x_touch && !y_overlap && !z_overlap
        return true
      elsif y_touch && !x_overlap && !z_overlap
        return true
      elsif z_touch && !x_overlap && !y_overlap
        return true
      end
      
      false
    end

    # 检查顶点是否真的在面内部（不仅仅是边界上）
    def self.is_vertex_inside_face(vertex, face, tolerance)
      return false unless face.valid?
      
      # 获取面的边界框
      face_bounds = face.bounds
      
      # 扩展边界框以包含容差
      expanded_bounds = Geom::BoundingBox.new
      expanded_bounds.add(Geom::Point3d.new(
        face_bounds.min.x - tolerance,
        face_bounds.min.y - tolerance,
        face_bounds.min.z - tolerance
      ))
      expanded_bounds.add(Geom::Point3d.new(
        face_bounds.max.x + tolerance,
        face_bounds.max.y + tolerance,
        face_bounds.max.z + tolerance
      ))
      
      # 检查顶点是否在扩展边界框内
      if expanded_bounds.contains?(vertex)
        # 进一步检查：顶点是否真的在面的几何内部，而不仅仅是边界上
        # 这里可以添加更复杂的几何检查，但为了简化，我们使用边界框检查
        return true
      end
      
      false
    end

    # 检查顶点是否有效（不是所有点都在同一位置）
    def self.vertices_are_valid(vertices)
      return false if vertices.nil? || vertices.length < 3
      
      # 检查是否有至少两个不同的点
      first_vertex = vertices[0]
      has_different_vertex = false
      
      vertices[1..-1].each do |vertex|
        if vertex.distance(first_vertex) > 0.001
          has_different_vertex = true
          break
        end
      end
      
      has_different_vertex
    end

    # 计算避免向量
    def self.calculate_avoidance_vector(vertex, face)
      return Geom::Vector3d.new(0, 0, 1) unless face && face.valid?
      
      # 获取面的法线
      face_normal = face.normal
      
      # 如果法线是垂直的，使用水平方向
      if face_normal.z.abs > 0.9
        # 根据面的位置选择避免方向
        face_bounds = face.bounds
        face_center = face_bounds.center
        
        # 计算从面中心到顶点的向量
        to_vertex = Geom::Vector3d.new(vertex.x - face_center.x, vertex.y - face_center.y, vertex.z - face_center.z)
        
        # 如果顶点在面的左侧，向右调整；如果在右侧，向左调整
        if to_vertex.x < 0
          return Geom::Vector3d.new(1, 0, 0)   # 向右
        else
          return Geom::Vector3d.new(-1, 0, 0)  # 向左
        end
      else
        # 使用法线的反方向，但确保不是零向量
        avoidance = face_normal.reverse
        if avoidance.length < 0.001
          # 如果法线接近零，使用默认方向
          return Geom::Vector3d.new(1, 0, 0)
        end
        return avoidance
      end
    end

    # 计算调整后的顶点位置
    def self.calculate_adjusted_vertices(vertices, adjacent_faces)
      begin
        adjusted_vertices = []
        adjustment_distance = 0.001 # 1mm的调整距离
        
        # 检查是否需要调整
        needs_adjustment = false
        vertices.each do |vertex|
          adjacent_faces.each do |adjacent_face|
            if is_vertex_near_face(vertex, adjacent_face, 0.001)
              needs_adjustment = true
              break
            end
          end
          break if needs_adjustment
        end
        
        if !needs_adjustment
          puts "调试：无需调整几何，所有顶点都远离相邻面"
          return vertices
        end
        
        # 计算调整方向（基于面的整体位置）
        adjustment_direction = calculate_overall_adjustment_direction(vertices, adjacent_faces)
        puts "调试：整体调整方向: (#{adjustment_direction.x}, #{adjustment_direction.y}, #{adjustment_direction.z})"
        
        vertices.each_with_index do |vertex, index|
          # 应用调整
          adjusted_vertex = Geom::Point3d.new(
            vertex.x + adjustment_direction.x * adjustment_distance,
            vertex.y + adjustment_direction.y * adjustment_distance,
            vertex.z + adjustment_direction.z * adjustment_distance
          )
          adjusted_vertices << adjusted_vertex
          puts "调试：顶点#{index} (#{vertex.x}, #{vertex.y}, #{vertex.z}) 调整到 (#{adjusted_vertex.x}, #{adjusted_vertex.y}, #{adjusted_vertex.z})"
        end
        
        puts "调试：成功计算调整后的顶点位置，调整了 #{vertices.length} 个顶点"
        adjusted_vertices
        
      rescue => e
        puts "计算调整后的顶点位置时出错: #{e.message}"
        puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
        return nil
      end
    end

    # 计算整体调整方向
    def self.calculate_overall_adjustment_direction(vertices, adjacent_faces)
      return Geom::Vector3d.new(0, 0, 1) if adjacent_faces.empty?
      
      # 计算所有相邻面的平均法线
      total_normal = Geom::Vector3d.new(0, 0, 0)
      adjacent_faces.each do |face|
        if face.valid?
          total_normal += face.normal
        end
      end
      
      # 如果所有面都是垂直的，使用水平方向
      if total_normal.z.abs > total_normal.length * 0.9
        # 根据面的位置选择调整方向
        first_face = adjacent_faces.first
        if first_face && first_face.valid?
          face_bounds = first_face.bounds
          # 使用Y轴方向调整（垂直于面的边界）
          return Geom::Vector3d.new(0, 1, 0)
        end
      end
      
      # 使用平均法线的反方向
      if total_normal.length > 0.001
        return total_normal.reverse.normalize
      else
        # 默认调整方向
        return Geom::Vector3d.new(0, 1, 0)
      end
    end

    # 检查顶点是否靠近面
    def self.is_vertex_near_face(vertex, face, tolerance)
      return false unless face && face.valid?
      
      # 计算顶点到面的距离
      # 使用面的边界框来估算距离
      face_bounds = face.bounds
      distance = point_to_bounds_distance(vertex, face_bounds)
      
      distance < tolerance
    end

    # 计算点到边界框的距离
    def self.point_to_bounds_distance(point, bounds)
      return 0 unless point && bounds
      
      # 计算点到边界框的最小距离
      dx = [bounds.min.x - point.x, 0, point.x - bounds.max.x].max
      dy = [bounds.min.y - point.y, 0, point.y - bounds.max.y].max
      dz = [bounds.min.z - point.z, 0, point.z - bounds.max.z].max
      
      # 如果点在边界框内，距离为0
      if dx == 0 && dy == 0 && dz == 0
        return 0
      end
      
      # 计算欧几里得距离
      Math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    # 从顶点恢复面的方法
    def self.restore_face_from_vertices(vertices, material, back_material, parent_group)
      begin
        puts "调试：尝试从顶点恢复面"
        
        # 检查顶点是否有效
        if vertices.nil? || vertices.empty?
          puts "警告：无法恢复面，顶点数据无效"
          return nil
        end
        
        # 去除重复的顶点
        unique_vertices = remove_duplicate_vertices(vertices)
        puts "调试：原始顶点数: #{vertices.length}, 去重后顶点数: #{unique_vertices.length}"
        
        # 检查是否有足够的顶点创建面
        if unique_vertices.length < 3
          puts "警告：去重后顶点数不足，无法创建面"
          return nil
        end
        
        # 创建新面
        new_face = parent_group.entities.add_face(unique_vertices)
        
        if new_face && new_face.valid?
          puts "调试：成功恢复面"
          
          # 应用材质
          if material
            new_face.material = material
          end
          if back_material
            new_face.back_material = back_material
          end
          
          # 确保法线朝上
          if new_face.normal.z < 0
            new_face.reverse!
          end
          
          return new_face
        else
          puts "警告：恢复面失败"
          return nil
        end
      rescue => e
        puts "恢复面时出错: #{e.message}"
        return nil
      end
    end

    # 去除重复顶点
    def self.remove_duplicate_vertices(vertices, tolerance = 0.001)
      return [] if vertices.nil? || vertices.empty?
      
      unique_vertices = []
      vertices.each do |vertex|
        # 检查是否与已有顶点重复
        is_duplicate = false
        unique_vertices.each do |existing_vertex|
          if vertex.distance(existing_vertex) < tolerance
            is_duplicate = true
            break
          end
        end
        
        # 如果不是重复的，添加到唯一顶点列表
        unique_vertices << vertex unless is_duplicate
      end
      
      unique_vertices
    end

    # 查找pushpull后产生的所有胶带面
    def self.find_all_tape_faces(tape_face, parent_group)
      all_faces = []
      
      begin
        if tape_face && tape_face.valid?
          # 添加原始面
          all_faces << tape_face
          
          # 通过边的连接关系找到所有相关面
          tape_face.edges.each do |edge|
            edge.faces.each do |connected_face|
              if connected_face != tape_face && connected_face.valid? && 
                 connected_face.parent == parent_group && 
                 !all_faces.include?(connected_face)
                all_faces << connected_face
              end
            end
          end
          
          # 如果通过边连接找到的面太少，尝试通过几何位置查找
          if all_faces.length < 3
            puts "调试：通过边连接找到的面太少，尝试通过几何位置查找"
            
            # 获取原始面的边界框
            bounds = tape_face.bounds
            tolerance = 0.001
            
            # 在父组中查找所有面
            parent_group.entities.each do |entity|
              if entity.is_a?(Sketchup::Face) && entity.valid?
                # 检查面是否在胶带的几何范围内
                if is_face_in_tape_bounds(entity, bounds, tolerance)
                  all_faces << entity unless all_faces.include?(entity)
                end
              end
            end
          end
        end
        
        puts "调试：总共找到 #{all_faces.length} 个胶带面"
        
      rescue => e
        puts "查找所有胶带面时出错: #{e.message}"
      end
      
      all_faces.uniq
    end

    # 检查面是否在胶带的边界范围内
    def self.is_face_in_tape_bounds(face, tape_bounds, tolerance)
      return false unless face && face.valid? && tape_bounds
      
      # 检查面的中心点是否在边界内
      face_bounds = face.bounds
      face_center = face_bounds.center
      
      # 扩展边界以包含侧面和顶面
      expanded_bounds = Geom::BoundingBox.new
      expanded_bounds.add(tape_bounds.min)
      expanded_bounds.add(tape_bounds.max)
      
      # 添加高度方向的扩展
      height = TapeBuilder::TAPE_HEIGHT
      expanded_bounds.add(Geom::Point3d.new(tape_bounds.min.x, tape_bounds.min.y, tape_bounds.min.z + height))
      expanded_bounds.add(Geom::Point3d.new(tape_bounds.max.x, tape_bounds.max.y, tape_bounds.max.z + height))
      
      # 检查面的中心点是否在扩展边界内
      expanded_bounds.contains?(face_center)
    end
  end
end 