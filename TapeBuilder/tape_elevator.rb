require_relative 'tape_constants'

module TapeBuilder
  class TapeElevator
    # 将胶带平面拉高到适当高度
    def self.elevate_tape(tape_face, height, elevation, parent_group)
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
        
        # 上浮胶带面
        if elevation > 0
          # 创建上浮变换
          transform = Geom::Transformation.translation([0, 0, elevation])
          
          puts "调试：准备上浮胶带面，高度: #{elevation}"
          
          # 直接变换整个面，而不是单独变换顶点
          # 这样可以保持面的完整性
          entities = parent_group.entities
          new_face = entities.transform_entities(transform, tape_face)
          
          # 如果变换返回了新面，使用新面
          if new_face.is_a?(Array) && !new_face.empty? && new_face[0].is_a?(Sketchup::Face)
            tape_face = new_face[0]
            puts "调试：上浮后获得新面，有效性: #{tape_face.valid?}"
          else
            puts "调试：上浮后未获得新面，返回类型: #{new_face.class}"
          end
        end
        
        # 再次检查面是否有效
        if !tape_face.valid?
          puts "警告：上浮后胶带面无效，跳过拉高操作"
          return
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
            
            # 获取当前面的材质，以便后续重新应用
            material = tape_face.material
            back_material = tape_face.back_material
            
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
                if material
                  tape_face.material = material
                end
                if back_material
                  tape_face.back_material = back_material
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
              end
            end
            
            # 如果仍然失败，记录详细的诊断信息
            if !result
              puts "警告：pushpull操作失败，可能是几何体问题"
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