# 纹理映射模块：将材质精确映射到竖直矩形面
module ImageFiller
  module TextureMapper
    # 将材质完整、等比填充到矩形面
    # 要求: face 为竖直矩形，material 含纹理
    # 之后升级横/斜面时，仅需扩展基准平面的选取与四点定位
    def self.apply_material_to_vertical_rect_face(face, material, up_vector: Z_AXIS, side_policy: :camera_facing)
      return [false, '无效面'] unless face && face.valid?
      return [false, '材质无效'] unless material && material.valid?
      tex = material.texture
      return [false, '材质缺少纹理'] unless tex

      # 调试信息：输出材质和纹理信息
      puts "【调试】材质名称: #{material.name}, 材质有效: #{material.valid?}"
      puts "【调试】纹理有效: #{tex ? '是' : '否'}, 纹理路径: #{tex ? tex.filename : '无'}"
      puts "【调试】纹理原始尺寸: #{tex.width}x#{tex.height}"
      
      # 安全获取纹理属性
      begin
        puts "【调试】纹理类型: #{tex.texture_type}(0=拉伸,1=平铺), 原点显示: #{tex.model_at_origin}"
      rescue NoMethodError => e
        puts "【调试】无法获取纹理类型或原点显示属性: #{e.message}"
      end

      # 获取矩形四个顶点（外环按连线顺序）
      loop = face.outer_loop
      edges = loop.edges
      return [false, '仅支持矩形面'] unless edges.length == 4

      verts = loop.vertices.map(&:position)
      return [false, '矩形点异常'] unless verts.size == 4
      puts "【调试】矩形顶点数量: #{verts.size}, 顶点坐标: #{verts.inspect}"

      # 选择贴图侧：仅"正对相机"的一侧
      model = Sketchup.active_model
      front_visible = true
      if side_policy == :camera_facing
        cam = model.active_view.camera
        view_dir = cam.direction
        dot = face.normal.dot(view_dir)
        front_visible = (dot < 0)
        puts "【调试】面法向量: #{face.normal}, 视线方向: #{view_dir}"
        puts "【调试】点积结果: #{dot}, 正面可见: #{front_visible}"
      end

      # 获取面的法向量
      normal = face.normal.normalize
      
      # 简化版：直接识别XY/YZ/XZ平面
      plane_type = :unknown
      if normal.parallel?(Z_AXIS)
        plane_type = :xy
        puts "【调试】识别为XY平面"
      elsif normal.parallel?(X_AXIS)
        plane_type = :yz
        puts "【调试】识别为YZ平面"
      elsif normal.parallel?(Y_AXIS)
        plane_type = :xz
        puts "【调试】识别为XZ平面"
      else
        puts "【调试】未识别的平面类型，法向量: #{normal}"
        return [false, "仅支持XY/YZ/XZ平面"]
      end
      
      # 确定矩形四角点
      case plane_type
      when :xy
        # XY平面：按X/Y坐标排序
        xs = verts.map { |p| p.x }
        ys = verts.map { |p| p.y }
        z = verts.first.z
        x_min, x_max = xs.min, xs.max
        y_min, y_max = ys.min, ys.max
        
        # 确定四角点
        bl = Geom::Point3d.new(x_min, y_min, z)
        br = Geom::Point3d.new(x_max, y_min, z)
        tr = Geom::Point3d.new(x_max, y_max, z)
        tl = Geom::Point3d.new(x_min, y_max, z)
        
        # 计算宽高
        width = x_max - x_min
        height = y_max - y_min
      when :yz
        # YZ平面：按Y/Z坐标排序
        ys = verts.map { |p| p.y }
        zs = verts.map { |p| p.z }
        x = verts.first.x
        y_min, y_max = ys.min, ys.max
        z_min, z_max = zs.min, zs.max
        
        # 确定四角点
        bl = Geom::Point3d.new(x, y_min, z_min)
        br = Geom::Point3d.new(x, y_max, z_min)
        tr = Geom::Point3d.new(x, y_max, z_max)
        tl = Geom::Point3d.new(x, y_min, z_max)
        
        # 计算宽高
        width = y_max - y_min
        height = z_max - z_min
      when :xz
        # XZ平面：按X/Z坐标排序
        xs = verts.map { |p| p.x }
        zs = verts.map { |p| p.z }
        y = verts.first.y
        x_min, x_max = xs.min, xs.max
        z_min, z_max = zs.min, zs.max
        
        # 确定四角点
        bl = Geom::Point3d.new(x_min, y, z_min)
        br = Geom::Point3d.new(x_max, y, z_min)
        tr = Geom::Point3d.new(x_max, y, z_max)
        tl = Geom::Point3d.new(x_min, y, z_max)
        
        # 计算宽高
        width = x_max - x_min
        height = z_max - z_min
      end
      
      puts "【调试】四角点坐标:"
      puts "【调试】左下(BL): #{bl}"
      puts "【调试】右下(BR): #{br}"
      puts "【调试】右上(TR): #{tr}"
      puts "【调试】左上(TL): #{tl}"
      puts "【调试】宽高: width=#{width}, height=#{height}"
      
      # 使用新方案：以Image实体方式放置图片，不explode
      return apply_image_to_vertical_rect_face(face, material, plane_type, bl, br, tr, tl, width, height)
    end
    
    # 新方法：将图片作为Image实体放置到矩形面
    def self.apply_image_to_vertical_rect_face(face, material, plane_type, bl, br, tr, tl, width, height)
      begin
        # 获取图片路径
        image_path = nil
        begin
          image_path = material.get_attribute(ImageFiller::MaterialManager::MATERIAL_TAG, 'image_path')
        rescue Exception
          image_path = nil
        end
        tex = material.texture
        image_path ||= (tex && tex.filename)
        raise '无法取得图片路径' unless image_path && !image_path.empty?
        
        # 获取实体容器
        ents = face.parent.entities
        
        puts "【调试】开始应用材质..."
        puts "【调试】材质已设置，开始放置图片..."
        
        # 创建图片实体
        case plane_type
        when :xy
          # XY平面：直接放置，简单直观
          puts "【调试】XY面: origin=#{bl}, w=#{width}, h=#{height}"
          img = ents.add_image(image_path, bl, width, height)
        when :yz, :xz
          # 对于非XY平面，先创建图片在左下角（最终尺寸），然后绕左下角旋转
          img = ents.add_image(image_path, bl, width, height)
          
          # 根据平面类型设置图片位置和旋转
          if plane_type == :yz
            # YZ平面
            puts "【调试】YZ面: 使用绕左下角旋转后再调整大小"
            
            # 检查法向量方向，确定旋转方向和角度
            normal = face.normal
            puts "【调试】YZ面: 法向量 = #{normal}"
            
            # 根据法向量确定旋转角度和方向
            if normal.x > 0
              # 面朝向+X方向
              angle = -90.degrees  # 逆时针旋转90度
              puts "【调试】YZ面: 朝向+X，逆时针旋转90度"
            else
              # 面朝向-X方向
              angle = 90.degrees  # 顺时针旋转90度
              puts "【调试】YZ面: 朝向-X，顺时针旋转90度"
            end
            
            # 先绕左下角旋转到YZ平面
            rotation1 = Geom::Transformation.rotation(bl, Y_AXIS, angle)
            img.transform!(rotation1)
            
            # 在YZ平面内，再绕左下角逆时针旋转90度（对于+X方向的面）
            if normal.x > 0
              puts "【调试】YZ面: 朝向+X，在YZ平面内再逆时针旋转90度"
              # 在YZ平面内旋转，需要绕X轴旋转
              rotation2 = Geom::Transformation.rotation(bl, X_AXIS, -90.degrees)
              img.transform!(rotation2)
              # 沿下边线(Y轴)翻转180度
              puts "【调试】YZ面: 沿下边线(Y轴)翻转180度"
              flip = Geom::Transformation.rotation(bl, Y_AXIS, 180.degrees)
              img.transform!(flip)
            end
            
            # 处理朝向-X方向的YZ平面
            if normal.x <= 0
              puts "【调试】YZ面: 朝向-X，需要额外处理"
              # 找到右下角点（Y值最小的点）
              right_bottom = (bl.y <= br.y) ? bl : br
              puts "【调试】YZ面: 朝向-X，右下角点坐标 = #{right_bottom}"
              
              # 在YZ平面内绕右下角点逆时针旋转90度
              # 在YZ平面内旋转需要绕X轴旋转
              rotation_extra = Geom::Transformation.rotation(right_bottom, X_AXIS, 90.degrees)
              puts "【调试】YZ面: 朝向-X，在YZ平面内绕右下角点逆时针旋转90度"
              img.transform!(rotation_extra)
              
              # 计算Z轴中线点（垂直中线）
              mid_y = (right_bottom.y + ((right_bottom == bl) ? br : bl).y) / 2.0
              mid_point = Geom::Point3d.new(right_bottom.x, mid_y, right_bottom.z)
              puts "【调试】YZ面: 朝向-X，Z轴中线点坐标 = #{mid_point}"
              
              # 沿Z轴中线翻转180度
              flip = Geom::Transformation.rotation(mid_point, Z_AXIS, 180.degrees)
              puts "【调试】YZ面: 朝向-X，沿Z轴中线翻转180度"
              img.transform!(flip)
            end

            # 已在创建时设置最终尺寸，仅执行旋转
            puts "【调试】YZ面: 尺寸=#{width}x#{height}"
          else # :xz
            # XZ平面
            puts "【调试】XZ面: 使用绕左下角旋转"
            # 创建变换：绕左下角旋转到XZ平面
            if face.normal.y > 0
              # 朝向+Y方向：需要先逆时针旋转90度，再沿X轴翻转180度
              puts "【调试】XZ面: 朝向+Y，需要额外翻转180度"
              rotation1 = Geom::Transformation.rotation(bl, X_AXIS, -90.degrees)
              # 沿X轴（下边线）翻转180度
              rotation2 = Geom::Transformation.rotation(bl, X_AXIS, 180.degrees)
              img.transform!(rotation1)
              img.transform!(rotation2)
              
              # 计算Z轴中线点（垂直中线）
              mid_x = (bl.x + br.x) / 2.0
              mid_point = Geom::Point3d.new(mid_x, bl.y, bl.z)
              puts "【调试】XZ面: 朝向+Y，Z轴中线点坐标 = #{mid_point}"
              
              # 沿Z轴中线翻转180度
              flip = Geom::Transformation.rotation(mid_point, Z_AXIS, 180.degrees)
              puts "【调试】XZ面: 朝向+Y，沿Z轴中线翻转180度"
              img.transform!(flip)
            else
              # 朝向-Y方向：直接顺时针旋转90度
              puts "【调试】XZ面: 朝向-Y，顺时针旋转90度"
              rotation = Geom::Transformation.rotation(bl, X_AXIS, 90.degrees)
              img.transform!(rotation)
            end
            
            # 已在创建时设置最终尺寸，仅执行旋转
            puts "【调试】XZ面: 尺寸=#{width}x#{height}"
          end
        end
        
        # 删除旧面，保留Image实体
        face.erase! if face && face.valid?
        puts "【调试】已删除旧面，保留Image实体（可通过SketchUp原生工具调整大小）"
        
        # 强制更新视图
        Sketchup.active_model.active_view.invalidate
        puts "【调试】视图已刷新"
        
        return [true, nil]
      rescue Exception => e
        puts "【调试】执行异常: #{e.message}"
        puts "【调试】异常类型: #{e.class}"
        puts "【调试】堆栈: #{e.backtrace.join("\n")}"
        return [false, "执行失败: #{e.message}"]
      end
    end
    
    # 方案B：直接以四角点重建面，再定位材质
    # 删除旧面 → ents.add_face([BL, BR, TR, TL]) → 使用UVHelper精确控制UV映射
    def self.apply_material_by_rebuild(old_face, material, bl, br, tr, tl)
      begin
        puts "【调试】执行方案B改进版：直接以四角点重建面，使用UVHelper精确映射"
        
        # 获取实体容器
        ents = old_face.parent.entities
        
        # 删除旧面
        old_face.erase! if old_face && old_face.valid?
        puts "【调试】已删除旧面"
        
        # 创建新面
        new_face = ents.add_face([bl, br, tr, tl])
        unless new_face && new_face.valid?
          return [false, "重建面失败"]
        end
        puts "【调试】已创建新面"
        
        # 应用材质
        new_face.material = material
        new_face.back_material = material
        
        # 使用UVHelper进行精确UV映射
        model = Sketchup.active_model
        
        # 前面
        tw = Sketchup.create_texture_writer
        uvh = model.active_view.model.get_UVHelper(true, true, tw)
        
        # 获取四个角点的UV坐标（映射到整个0-1区间）
        pts = [bl, br, tr, tl]
        uvs = [
          Geom::Point3d.new(0, 0, 0),  # 左下
          Geom::Point3d.new(1, 0, 0),  # 右下
          Geom::Point3d.new(1, 1, 0),  # 右上
          Geom::Point3d.new(0, 1, 0)   # 左上
        ]
        
        # 获取面的所有顶点
        mesh = new_face.mesh(0) # 0表示不需要平滑
        points = mesh.points
        
        # 对每个顶点设置UV坐标
        front_uvh = uvh.get_front_UVHelper
        back_uvh = uvh.get_back_UVHelper
        
        # 遍历所有顶点，为每个顶点设置UV
        puts "【调试】开始设置UV坐标..."
        
        # 使用position_material先设置初始映射
        new_face.position_material(material, [bl, br, tl], true)
        new_face.position_material(material, [bl, br, tl], false)
        
        # 确保材质不平铺
        if material.texture
          # 设置材质尺寸为面的实际尺寸
          width = (br - bl).length
          height = (tl - bl).length
          material.texture.size = [width, height]
        end
        
        # 修改UV映射以确保拉伸填满
        begin
          # 获取UV坐标
          uvq = new_face.get_UVHelper(true, true, tw)
          
          # 设置四个角点的UV坐标
          vertices = new_face.vertices
          
          # 找到对应的顶点
          vbl = vertices.min_by { |v| (v.position - bl).length }
          vbr = vertices.min_by { |v| (v.position - br).length }
          vtr = vertices.min_by { |v| (v.position - tr).length }
          vtl = vertices.min_by { |v| (v.position - tl).length }
          
          puts "【调试】找到对应顶点: BL=#{vbl.position}, BR=#{vbr.position}, TR=#{vtr.position}, TL=#{vtl.position}"
          
          # 设置前面UV
          new_face.set_texture_coordinates(vbl, [0, 0])
          new_face.set_texture_coordinates(vbr, [1, 0])
          new_face.set_texture_coordinates(vtr, [1, 1])
          new_face.set_texture_coordinates(vtl, [0, 1])
          
          puts "【调试】已设置前面UV坐标"
        rescue Exception => e
          puts "【调试】UV设置异常: #{e.message}"
        end
        
        # 强制更新视图
        Sketchup.active_model.active_view.invalidate
        puts "【调试】视图已刷新"
        
        return [true, nil]
      rescue Exception => e
        puts "【调试】方案B执行异常: #{Utils.ensure_utf8(e.message)}"
        puts "【调试】异常类型: #{e.class}"
        puts "【调试】堆栈: #{e.backtrace.join("\n")}"
        return [false, "重建面失败: #{Utils.ensure_utf8(e.message)}"]
      end
    end
  end
end 