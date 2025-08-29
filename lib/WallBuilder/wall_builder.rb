# 墙体构建模块：处理墙体的创建和优化
module WallBuilder
  # 导入墙体 - 修复垂直墙体生成（解决向量转换错误）
  def self.import_walls(walls_data, parent_group)
    puts "=== 开始导入墙体 ==="
    # puts "墙体数据总数: #{walls_data.length}"
    # puts "父组名称: #{parent_group.name}"

    cover_faces_points = []
    wall_entities = []
    
    walls_data.each_with_index do |wall_data, index|
      # puts "\n--- 处理第 #{index + 1} 个墙体 ---"
      begin
        # puts "墙体ID: #{wall_data["id"] || '未指定'}"
        # puts "墙体名称: #{wall_data["name"] || '未指定'}"
        # puts "起点坐标: #{wall_data["start"]}"
        # puts "终点坐标: #{wall_data["end"]}"
        
        start_point = Utils.validate_and_create_point(wall_data["start"])
        end_point = Utils.validate_and_create_point(wall_data["end"])
        # puts "验证后起点: #{start_point}"
        # puts "验证后终点: #{end_point}"

        unless start_point && end_point
          # puts "跳过无效墙体：起点或终点坐标错误（数据：#{wall_data["start"]} -> #{wall_data["end"]}）"
          next
        end
        
        scale_factor = 25.4
        # puts "缩放因子: #{scale_factor}"
        
        # 加个缩放因子 - thickness是直径，需要转换为半径
        raw_thickness = wall_data["thickness"]
        # puts "原始厚度值: #{raw_thickness}"
        diameter = Utils.parse_number(raw_thickness / scale_factor || 0.2)
        # puts "转换后直径: #{diameter}"
        thickness = diameter / 2.0  # 转换为半径
        # puts "计算后半径: #{thickness}"
        
        raw_height = wall_data["height"]
        # puts "原始高度值: #{raw_height}"
        height = Utils.parse_number(raw_height / scale_factor || 3.0)
        # puts "转换后高度: #{height}"
        
        thickness = 0.1 if thickness < 0 || thickness.nil?  # 最小半径
        height = 3.0 if height <= 0 || height.nil?
        # puts "最终使用半径: #{thickness}"
        # puts "最终使用高度: #{height}"
        
        vector = end_point - start_point
        # puts "墙体向量: #{vector}"
        # puts "向量长度: #{vector.length}"
        
        if vector.length < 0.001
          # puts "警告: 墙的起点和终点相同，无法创建 (ID: #{wall_data['id'] || '未知'})"
          next
        end
        
        begin
          # puts "计算墙体法线向量..."
          normal = vector.cross(Geom::Vector3d.new(0, 0, 1)).normalize
          # puts "原始法线: #{normal}"
          normal = normal.reverse if normal.x < 0
          # puts "调整后法线: #{normal}"
        rescue => e
          # puts "法线计算失败，使用默认值: #{e.message}"
          normal = Geom::Vector3d.new(1, 0, 0)
        end
        
        # puts "开始创建垂直墙体..."
        wall_group = create_vertical_wall(wall_data, start_point, end_point, thickness, height, normal, parent_group)
        # puts "墙体组创建完成: #{wall_group.name}"
        
        # 确保每个墙体都有唯一的ID
        wall_id = wall_data["id"] || "wall_#{wall_entities.length + 1}"
        wall_name = wall_data["name"] || "墙体_#{wall_id}"
        # puts "设置墙体ID: #{wall_id}"
        # puts "设置墙体名称: #{wall_name}"
        
        # 设置墙体的唯一标识
        wall_group.set_attribute('FactoryImporter', 'id', wall_id)
        wall_group.set_attribute('FactoryImporter', 'wall_id', wall_id)
        wall_group.set_attribute('FactoryImporter', 'name', wall_name)
        # puts "墙体属性设置完成"
        
        # 更新组名称，确保唯一性
        wall_group.name = wall_name
        
        # 存储到实体存储器（独立功能，不影响主流程）
        begin
          # puts "开始存储墙体实体..."
          EntityStorage.add_entity("wall", wall_group, {
            wall_id: wall_id,
            wall_name: wall_data["name"],
            start_point: wall_data["start"],
            end_point: wall_data["end"],
            thickness: thickness,
            height: height
          })
          # puts "墙体实体存储成功"
        rescue => e
          # puts "警告: 存储墙体实体失败: #{e.message}"
        end
        
        wall_entities << wall_group
        # puts "墙体已添加到实体列表，当前总数: #{wall_entities.length}"
        
        # 收集顶面四点（使用半径偏移）
        if thickness > 0
          # puts "计算顶面覆盖点..."
          begin
            offset_vec = normal.clone
            offset_vec.length = thickness  # 使用半径偏移
            # puts "偏移向量: #{offset_vec}"
          rescue => e
            # puts "偏移向量计算失败: #{e.message}"
            offset_vec = Geom::Vector3d.new(thickness, 0, 0)
          end
          
          # 重新计算顶面四点，确保正确的几何关系
          # 起点和终点是墙体中线的起点和终点，需要向两侧偏移形成完整覆盖面
          # P1: 起点 + 法线偏移 + 向上偏移高度（左边界）
          p1 = start_point + offset_vec + Geom::Vector3d.new(0, 0, height)
          # P2: 终点 + 法线偏移 + 向上偏移高度（左边界）
          p2 = end_point + offset_vec + Geom::Vector3d.new(0, 0, height)
          # P3: 终点 - 法线偏移 + 向上偏移高度（右边界）
          p3 = end_point - offset_vec + Geom::Vector3d.new(0, 0, height)
          # P4: 起点 - 法线偏移 + 向上偏移高度（右边界）
          p4 = start_point - offset_vec + Geom::Vector3d.new(0, 0, height)
          
          # puts "顶面四点计算详情:"
          # puts "  起点（中线）: #{start_point}"
          # puts "  终点（中线）: #{end_point}"
          # puts "  高度偏移: #{height}"
          # puts "  法线偏移: #{offset_vec}"
          # puts "  P1 = 起点 + #{offset_vec} + (0,0,#{height}) = #{p1} （左边界）"
          # puts "  P2 = 终点 + #{offset_vec} + (0,0,#{height}) = #{p2} （左边界）"
          # puts "  P3 = 终点 - #{offset_vec} + (0,0,#{height}) = #{p3} （右边界）"
          # puts "  P4 = 起点 - #{offset_vec} + (0,0,#{height}) = #{p4} （右边界）"
          
          # puts "顶面四点:"
          # puts "  P1: #{p1}"
          # puts "  P2: #{p2}"
          # puts "  P3: #{p3}"
          # puts "  P4: #{p4}"
          
          cover_faces_points << [p1, p2, p3, p4]
          # puts "顶面点已添加到覆盖列表"
        else
          # puts "厚度为0，跳过顶面计算"
        end
        
        # puts "第 #{index + 1} 个墙体处理完成"
        
      rescue => e
        wall_id = wall_data['id'] || '未知'
        error_msg = "警告: 创建墙体时出错 (ID: #{wall_id}): #{Utils.ensure_utf8(e.message)}"
        # puts Utils.ensure_utf8(error_msg)
        # puts "错误堆栈: #{e.backtrace.first(3).join("\n")}"
      end
    end
    
    # puts "\n=== 开始生成顶面覆盖面 ==="
    # puts "顶面点组数量: #{cover_faces_points.length}"
    
    # 统一在parent_group下生成所有顶面覆盖面
    cover_faces_points.each_with_index do |pts, index|
      # puts "创建第 #{index + 1} 个顶面..."
      face = parent_group.entities.add_face(pts)
      if face
        face.material = [255,255,255]
        face.back_material = [255,255,255]
        # puts "顶面创建成功，面积: #{face.area}"
      else
        # puts "顶面创建失败"
      end
    end
    
    # puts "\n=== 开始优化墙体边缘 ==="
    # puts "待优化墙体数量: #{wall_entities.length}"
    
    # 3. 优化墙体边（吸附/软化）
    WallOptimizer.optimize_wall_edges(wall_entities)
    
    # puts "\n=== 墙体导入完成 ==="
    # puts "成功创建墙体: #{wall_entities.length} 个"
    # puts "成功创建顶面: #{cover_faces_points.length} 个"
  end
  
  # 创建垂直墙体 - 修复法线方向问题（支持厚度为0的情况）
  # thickness参数实际上是半径（从直径转换而来）
  def self.create_vertical_wall(wall_data, start_point, end_point, thickness, height, wall_normal, parent_group)
    # puts "  --- 创建垂直墙体 ---"
    # puts "  起点: #{start_point}"
    # puts "  终点: #{end_point}"
    # puts "  半径: #{thickness}"
    # puts "  高度: #{height}"
    # puts "  法线: #{wall_normal}"
    
    # 创建墙体组
    wall_group = parent_group.entities.add_group
    wall_group.name = wall_data["name"] || wall_data["id"] || "墙"
    # puts "  墙体组创建: #{wall_group.name}"
    
    if thickness <= 0
      # 半径为0时：
      # puts "  半径为0，跳过墙体面创建"
      
    else
      # puts "  开始创建墙体六个面..."
      
      # 【关键优化：确保偏移向量有效】
      begin
        offset_vec = wall_normal.clone
        offset_vec.length = thickness  # 使用半径作为偏移距离
        # puts "  偏移向量: #{offset_vec}"
      rescue => e
        # puts "  偏移向量计算失败: #{e.message}"
        offset_vec = Geom::Vector3d.new(thickness, 0, 0)  # 默认偏移方向
      end
      
      # 墙体底部四个点
      # puts "  计算底部四点..."
      # puts "    起点（中线）: #{start_point}"
      # puts "    终点（中线）: #{end_point}"
      # puts "    偏移向量: #{offset_vec}"
      
      # 起点和终点是墙体中线的起点和终点，需要向两侧偏移形成完整墙体
      points_bottom = [
        start_point - offset_vec,                       # P1: 起点 - 偏移（左边界）
        end_point - offset_vec,                         # P2: 终点 - 偏移（左边界）
        end_point + offset_vec,                         # P3: 终点 + 偏移（右边界）
        start_point + offset_vec                         # P4: 起点 + 偏移（右边界）
      ]
      # puts "  底部四点计算详情:"
      # puts "    P1 = 起点 - #{offset_vec} = #{points_bottom[0]} （左边界）"
      # puts "    P2 = 终点 - #{offset_vec} = #{points_bottom[1]} （左边界）"
      # puts "    P3 = 终点 + #{offset_vec} = #{points_bottom[2]} （右边界）"
      # puts "    P4 = 起点 + #{offset_vec} = #{points_bottom[3]} （右边界）"
      
      # 墙体顶部四个点（底部点向上偏移height）
      # puts "  计算顶部四点（底部点向上偏移#{height}）..."
      points_top = points_bottom.map { |p| p + Geom::Vector3d.new(0, 0, height) }
      # puts "  顶部四点计算详情:"
      # puts "    P1 = #{points_bottom[0]} + (0,0,#{height}) = #{points_top[0]} （左边界顶部）"
      # puts "    P2 = #{points_bottom[1]} + (0,0,#{height}) = #{points_top[1]} （左边界顶部）"
      # puts "    P3 = #{points_bottom[2]} + (0,0,#{height}) = #{points_top[2]} （右边界顶部）"
      # puts "    P4 = #{points_bottom[3]} + (0,0,#{height}) = #{points_top[3]} （右边界顶部）"
      
      # 创建墙体六个面
      faces = []
      
      # 前面
      # puts "  创建前面..."
      front_points = [points_bottom[0], points_bottom[1], points_top[1], points_top[0]]
      front_face = wall_group.entities.add_face(front_points)
      faces << front_face
      # puts "    前面创建: #{front_face ? '成功' : '失败'}"
      
      # 后面
      # puts "  创建后面..."
      back_points = [points_bottom[2], points_bottom[3], points_top[3], points_top[2]]
      back_face = wall_group.entities.add_face(back_points)
      faces << back_face
      # puts "    后面创建: #{back_face ? '成功' : '失败'}"
      
      # 左面
      # puts "  创建左面..."
      left_points = [points_bottom[0], points_bottom[3], points_top[3], points_top[0]]
      left_face = wall_group.entities.add_face(left_points)
      faces << left_face
      # puts "    左面创建: #{left_face ? '成功' : '失败'}"
      
      # 右面
      # puts "  创建右面..."
      right_points = [points_bottom[1], points_bottom[2], points_top[2], points_top[1]]
      right_face = wall_group.entities.add_face(right_points)
      faces << right_face
      # puts "    右面创建: #{right_face ? '成功' : '失败'}"
      
      # 顶面
      # puts "  创建顶面..."
      top_points = [points_top[0], points_top[1], points_top[2], points_top[3]]
      top_face = wall_group.entities.add_face(top_points)
      faces << top_face
      # puts "    顶面创建: #{top_face ? '成功' : '失败'}"
      
      # 底面
      # puts "  创建底面..."
      bottom_points = [points_bottom[0], points_bottom[1], points_bottom[2], points_bottom[3]]
      bottom_face = wall_group.entities.add_face(bottom_points)
      faces << bottom_face
      # puts "    底面创建: #{bottom_face ? '成功' : '失败'}"
      
      # puts "  成功创建面数: #{faces.compact.count}"
      
      # 设置墙体材质
      # puts "  开始设置材质和属性..."
      faces.each_with_index do |face, index|
        unless face.deleted?
          # 使用默认颜色
          face.material = [128, 128, 128]
          face.back_material = [128, 128, 128]
          
          # 设置面的属性
          face.set_attribute('FactoryImporter', 'face_type', 'wall_face')
          face.set_attribute('FactoryImporter', 'wall_id', wall_data['id'])
          # puts "    面 #{index + 1} 属性设置完成"
        else
          # puts "    面 #{index + 1} 已被删除，跳过"
        end
      end
    end
    
    puts "  墙体创建完成: #{wall_group.name}"
    wall_group
  end
end 