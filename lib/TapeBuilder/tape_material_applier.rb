require_relative 'tape_constants'

module TapeBuilder
  class TapeMaterialApplier
    # 功能开关：设置为false时关闭材质应用功能
    ENABLE_MATERIAL_APPLYING = true
    
    # 立方体材质应用功能开关：设置为false时关闭立方体相关功能
    ENABLE_CUBE_MATERIAL_APPLYING = false
    
    # 应用胶带材质到单个面
    def self.apply_tape_material(tape_face)
      # 检查功能开关
      unless ENABLE_MATERIAL_APPLYING
        puts "调试：材质应用功能已关闭"
        return
      end
      
      begin
        # 检查面是否有效
        if !tape_face || !tape_face.valid?
          puts "警告：无效的胶带面，跳过应用材质"
          return
        end
        
        puts "调试：开始应用胶带材质（平面模式）"
        puts "调试：胶带面有效性: #{tape_face.valid?}"
        puts "调试：胶带面顶点数: #{tape_face.vertices.length}"
        
        # 检查是否已存在胶带材质
        model = Sketchup.active_model
        tape_material = model.materials["Tape"]
        
        # 如果不存在，则创建新材质
        if !tape_material
          puts "调试：创建新的胶带材质"
          tape_material = model.materials.add("Tape")
          
          # 设置材质颜色
          color = Sketchup::Color.new(TapeBuilder::TAPE_COLOR[0], TapeBuilder::TAPE_COLOR[1], TapeBuilder::TAPE_COLOR[2])
          tape_material.color = color
          
          puts "调试：设置材质颜色: RGB(#{TapeBuilder::TAPE_COLOR[0]}, #{TapeBuilder::TAPE_COLOR[1]}, #{TapeBuilder::TAPE_COLOR[2]})"
          puts "调试：材质颜色对象: #{color.inspect}"
          puts "调试：材质颜色值: #{tape_material.color.inspect}"
          
          # 设置材质属性
          tape_material.alpha = 1.0  # 不透明度
          # 确保材质使用颜色而不是纹理
          tape_material.texture = nil
          
          puts "调试：材质创建完成，名称: #{tape_material.name}"
        else
          puts "调试：使用已存在的胶带材质: #{tape_material.name}"
          puts "调试：现有材质颜色: #{tape_material.color.inspect}"
          
          # 强制重新设置颜色，确保颜色正确
          color = Sketchup::Color.new(TapeBuilder::TAPE_COLOR[0], TapeBuilder::TAPE_COLOR[1], TapeBuilder::TAPE_COLOR[2])
          tape_material.color = color
          puts "调试：重新设置材质颜色: RGB(#{TapeBuilder::TAPE_COLOR[0]}, #{TapeBuilder::TAPE_COLOR[1]}, #{TapeBuilder::TAPE_COLOR[2]})"
        end
        
        # 验证材质是否有效
        if !tape_material || !tape_material.valid?
          puts "警告：胶带材质无效，尝试重新创建"
          begin
            # 删除无效材质
            model.materials.remove(tape_material) if tape_material
            # 重新创建
            tape_material = model.materials.add("Tape")
            color = Sketchup::Color.new(TapeBuilder::TAPE_COLOR[0], TapeBuilder::TAPE_COLOR[1], TapeBuilder::TAPE_COLOR[2])
            tape_material.color = color
            tape_material.alpha = 1.0
            # 确保材质使用颜色而不是纹理
            tape_material.texture = nil
            # 设置材质类型为纯色
            tape_material.colorize_type = 0
            puts "调试：重新创建材质成功"
          rescue => e
            puts "重新创建材质失败: #{e.message}"
            return
          end
        end
        
        # 应用胶带材质到面（仅正面，作为平面处理）
        puts "调试：应用材质到胶带面（平面模式）"
        tape_face.material = tape_material
        
        # 根据功能开关决定是否应用背面材质
        if ENABLE_CUBE_MATERIAL_APPLYING
          tape_face.back_material = tape_material
          puts "调试：已应用背面材质（立方体模式）"
        else
          puts "调试：跳过背面材质应用（平面模式）"
        end
        
        # 验证材质是否成功应用
        if tape_face.material == tape_material
          puts "调试：材质应用成功（平面模式）"
          puts "调试：面材质名称: #{tape_face.material.name}"
          puts "调试：面材质颜色: #{tape_face.material.color.inspect}"
        else
          puts "警告：材质应用可能失败"
          puts "调试：期望材质: #{tape_material.name}"
          puts "调试：实际材质: #{tape_face.material ? tape_face.material.name : 'nil'}"
        end
        
        # 强制刷新显示
        model.active_view.invalidate
        
      rescue => e
        puts "应用胶带材质时出错: #{e.message}"
        puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
      end
    end

    # 为整个胶带立方体的所有面应用材质
    def self.apply_tape_material_to_cube(tape_face, parent_group)
      # 检查立方体材质应用功能开关
      unless ENABLE_CUBE_MATERIAL_APPLYING
        puts "调试：立方体材质应用功能已关闭，胶带将作为平面处理"
        return
      end
      
      begin
        puts "调试：开始为胶带立方体应用材质"
        
        # 首先获取或创建胶带材质
        model = Sketchup.active_model
        tape_material = get_or_create_tape_material(model)
        
        if !tape_material
          puts "警告：无法获取胶带材质，跳过应用"
          return
        end
        
        # 找到所有与胶带相关的面
        tape_faces = find_tape_faces(tape_face, parent_group)
        puts "调试：找到 #{tape_faces.length} 个胶带面需要应用材质"
        
        # 为所有面应用材质
        applied_count = 0
        tape_faces.each do |face|
          if face && face.valid?
            begin
              face.material = tape_material
              face.back_material = tape_material
              applied_count += 1
              puts "调试：成功为面 #{face.entityID} 应用材质"
            rescue => e
              puts "警告：为面 #{face.entityID} 应用材质失败: #{e.message}"
            end
          else
            puts "警告：跳过无效面 #{face ? face.entityID : 'nil'}"
          end
        end
        
        puts "调试：成功为 #{applied_count} 个面应用了胶带材质"
        
        # 强制刷新显示
        model.active_view.invalidate
        
      rescue => e
        puts "为胶带立方体应用材质时出错: #{e.message}"
        puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
      end
    end

    private

    # 获取或创建胶带材质
    def self.get_or_create_tape_material(model)
      tape_material = model.materials["Tape"]
      
      if !tape_material
        puts "调试：创建新的胶带材质"
        tape_material = model.materials.add("Tape")
        
        # 设置材质颜色
        color = Sketchup::Color.new(TapeBuilder::TAPE_COLOR[0], TapeBuilder::TAPE_COLOR[1], TapeBuilder::TAPE_COLOR[2])
        tape_material.color = color
        
        # 设置材质属性
        tape_material.alpha = 1.0
        tape_material.texture = nil
        tape_material.colorize_type = 0
        
        puts "调试：胶带材质创建完成"
      else
        puts "调试：使用已存在的胶带材质"
        # 确保颜色正确
        color = Sketchup::Color.new(TapeBuilder::TAPE_COLOR[0], TapeBuilder::TAPE_COLOR[1], TapeBuilder::TAPE_COLOR[2])
        tape_material.color = color
      end
      
      tape_material
    end

    # 找到所有与胶带相关的面
    def self.find_tape_faces(tape_face, parent_group)
      # 如果立方体功能关闭，直接返回空数组
      unless ENABLE_CUBE_MATERIAL_APPLYING
        puts "调试：立方体面查找功能已关闭"
        return []
      end
      
      tape_faces = []
      
      begin
        # 方法1：通过边的连接关系找到相关面
        if tape_face && tape_face.valid?
          # 添加原始面
          tape_faces << tape_face
          
          # 通过边找到连接的面
          tape_face.edges.each do |edge|
            edge.faces.each do |connected_face|
              if connected_face != tape_face && connected_face.valid? && 
                 connected_face.parent == parent_group && 
                 !tape_faces.include?(connected_face)
                tape_faces << connected_face
              end
            end
          end
        end
        
        # 方法2：如果方法1找到的面太少，尝试通过几何位置找到相关面
        if tape_faces.length < 3  # 立方体应该有至少6个面
          puts "调试：通过边连接找到的面太少，尝试通过几何位置查找"
          
          # 获取原始面的边界框
          if tape_face && tape_face.valid?
            bounds = tape_face.bounds
            tolerance = 0.001  # 容差
            
            # 在父组中查找所有面
            parent_group.entities.each do |entity|
              if entity.is_a?(Sketchup::Face) && entity.valid?
                # 检查面是否在胶带的几何范围内
                if is_face_in_tape_bounds(entity, bounds, tolerance)
                  tape_faces << entity unless tape_faces.include?(entity)
                end
              end
            end
          end
        end
        
        puts "调试：通过几何查找找到 #{tape_faces.length} 个面"
        
      rescue => e
        puts "查找胶带面时出错: #{e.message}"
      end
      
      tape_faces.uniq
    end

    # 检查面是否在胶带的边界范围内
    def self.is_face_in_tape_bounds(face, tape_bounds, tolerance)
      # 如果立方体功能关闭，直接返回false
      unless ENABLE_CUBE_MATERIAL_APPLYING
        puts "调试：立方体边界检查功能已关闭"
        return false
      end
      
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