# 门构建模块：处理门的创建和优化
module DoorBuilder
  # 统一创建所有门（核心优化：滞后创建门，确保墙体已存在）
  def self.create_all_doors(door_data_list, parent_group)
    puts "开始创建门..."
    door_count = 0
    
    door_data_list.each do |door_item|
      begin
        door_data = door_item[:door_data]
        wall_data = door_item[:wall_data]
        current_parent = door_item[:parent_group]
        
        # 墙体门处理
        if wall_data
          wall_id = wall_data["id"] || wall_data["name"] || "未知墙体"
          puts "处理墙体门 (墙体ID: #{wall_id}, 门ID: #{door_data['id'] || '未知'})"
          
          # 找到对应的墙体组
          wall_group = Utils.find_wall_group(current_parent, wall_id)
          
          if wall_group
            # 创建门开口
            create_door_opening(wall_group, wall_data, door_data, parent_group)
            door_count += 1
          else
            puts "警告: 未找到墙体 '#{wall_id}'，跳过此门"
          end
        else
          # 独立门处理
          puts "处理独立门 (ID: #{door_data['id'] || '未知'})"
          import_independent_door(door_data, parent_group)
          door_count += 1
        end
      rescue => e
        door_id = door_data["id"] || "未知"
        error_msg = "警告: 创建门时出错 (ID: #{door_id}): #{Utils.ensure_utf8(e.message)}"
        puts Utils.ensure_utf8(error_msg)
      end
    end
    
    puts "门创建完成，共创建 #{door_count} 个门"
  end
  
  # 在墙体上创建门开口（支持厚度为0的墙体）
  def self.create_door_opening(wall_group, wall_data, door_data, parent_group)
    dimensions = door_data["size"] || []
    
    # 验证门尺寸数据
    if dimensions.size < 2
      puts "警告: 门尺寸数据不足，跳过 (ID: #{door_data['id'] || '未知'})"
      return
    end
    
    # 提取门的起点和终点
    start_point = Utils.validate_and_create_point(dimensions[0])
    end_point = Utils.validate_and_create_point(dimensions[1])
    
    if !start_point || !end_point
      puts "警告: 门坐标无效，跳过 (ID: #{door_data['id'] || '未知'})"
      return
    end
    
    # 提取门的高度 - 毫米转米
    height = Utils.parse_number(door_data["height"]) * 0.001
    height = 2.0 if height <= 0
    
    # 墙体厚度 - 毫米转米
    wall_thickness = Utils.parse_number(wall_data["thickness"]) * 0.001
    
    puts "在墙体上创建门开口: 起点=#{start_point}, 终点=#{end_point}, 高度=#{height}m, 墙体厚度=#{wall_thickness}m"
    
    # 计算墙体的方向
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法创建门开口"
      return
    end
    
    # 计算墙体方向向量
    wall_vector = wall_end - wall_start
    if wall_vector.length < 0.001
      puts "警告: 墙体向量长度过小，无法创建门开口"
      return
    end
    
    # 根据墙体厚度处理不同情况
    if wall_thickness <= 0.001
      # 厚度为0的墙体处理
      create_door_on_zero_thickness_wall(wall_group, wall_data, door_data, start_point, end_point, height)
    else
      # 正常厚度墙体处理
      create_door_on_normal_wall(wall_group, wall_data, door_data, start_point, end_point, height)
    end
  end
  
  # 在厚度为0的墙体上创建门
  def self.create_door_on_zero_thickness_wall(wall_group, wall_data, door_data, start_point, end_point, height)
    wall_entities = wall_group.entities
    
    # 计算墙体的方向
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法在零厚度墙体上创建门"
      return
    end
    
    # 计算墙体方向向量
    wall_vector = wall_end - wall_start
    
    # 检查墙体向量有效性
    wall_direction = nil
    if wall_vector.length >= 0.001
      wall_direction = wall_vector.normalize
    else
      # 如果墙体向量无效，尝试从门的起点和终点推断方向
      door_vector = end_point - start_point
      
      # 检查门向量有效性
      if door_vector.length >= 0.001
        wall_direction = door_vector.normalize
        puts "警告: 墙体向量无效，使用门的方向代替"
      else
        # 如果门的向量也无效，使用默认方向（水平向右）
        wall_direction = Geom::Vector3d.new(1, 0, 0)
        puts "警告: 墙体向量和门的向量都无效，使用默认方向"
      end
    end
    
    # 计算门的中心点
    door_center = Geom::Point3d.new(
      (start_point.x + end_point.x) / 2,
      (start_point.y + end_point.y) / 2,
      0
    )
    
    # 确保门宽度有效
    door_width = (end_point - start_point).length
    
    # 检查门宽度是否合理（门不应该超过10米宽，允许更大的门）
    max_reasonable_width = 10.0  # 10米，允许更大的门
    if door_width < 0.001
      puts "警告: 门的宽度#{door_width}米过小，使用默认值0.9米"
      door_width = 0.9
      
      # 当宽度无效时，基于墙体方向计算门的起点和终点
      half_width = door_width / 2
      start_point = door_center - wall_direction * half_width
      end_point = door_center + wall_direction * half_width
      
      puts "重新计算门边界: 中心点=#{door_center}, 起点=#{start_point}, 终点=#{end_point}"
    elsif door_width > max_reasonable_width
      puts "警告: 门的宽度#{door_width}米过大，但继续使用原始尺寸"
      puts "门宽度: #{door_width}米，位置: 起点=#{start_point}, 终点=#{end_point}"
    else
      puts "门宽度正常: #{door_width}米"
    end
    
    # 计算墙体法线方向（垂直于墙体方向和向上方向）
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 确保法线向量有效
    if wall_normal.length < 0.001
      wall_normal = Geom::Vector3d.new(0, 1, 0)  # 默认垂直于X轴
      puts "警告: 法线向量计算失败，使用默认法线方向"
    end
    
    # 计算门的四个角点 - 确保门在正确的高度
    door_points = [
      start_point,
      end_point,
      end_point + Geom::Vector3d.new(0, 0, height),
      start_point + Geom::Vector3d.new(0, 0, height)
    ]
    
    # 找到墙体的面（单面墙只有一个面）
    wall_face = wall_entities.grep(Sketchup::Face).find { |f| 
      normal = f.normal
      (normal.z.abs < 0.001) && !f.deleted?
    }
    
    if !wall_face
      puts "警告: 未找到墙体面，无法创建门开口"
      return
    end
    
    # 创建门组
    door_group = wall_group.entities.add_group
    door_group.name = "Door-#{door_data['id'] || 'unknown'}"
    
    # 在门的位置创建一个新面
    begin
      door_face = door_group.entities.add_face(door_points)
      
      if door_face
        # 设置门的材质
        door_face.material = [200, 200, 200]  # 浅灰色
        puts "在厚度为0的墙体上创建门成功，门点: #{door_points.inspect}"
      else
        puts "警告: 创建门的面失败，点可能共线或无效"
        puts "  门点: #{door_points.inspect}"
      end
    rescue Exception => e
      puts "警告: 创建门时出错: #{e.message}"
      puts "  门点: #{door_points.inspect}"
    end
  end
  
  # 在正常厚度墙体上创建门 - 使用智能投影方法
  def self.create_door_on_normal_wall(wall_group, wall_data, door_data, start_point, end_point, height)
    model = Sketchup.active_model
    model.start_operation("创建墙体门", true)
  
    # 获取墙体坐标
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
  
    unless wall_start && wall_end && start_point && end_point
      puts "[DEBUG] wall_start: #{wall_start.inspect}, wall_end: #{wall_end.inspect}, start_point: #{start_point.inspect}, end_point: #{end_point.inspect}"
      puts "警告: 墙体或门的坐标无效，无法创建门"
      model.abort_operation
      return
    end
  
    puts "=== 智能门洞生成 ==="
    puts "墙体起点: #{wall_start.inspect}"
    puts "墙体终点: #{wall_end.inspect}"
    puts "门起点: #{start_point.inspect}"
    puts "门终点: #{end_point.inspect}"
    
    # 计算门宽度
    door_vector = end_point - start_point
    door_width = door_vector.length
    
    # 检查门宽度是否合理
    max_reasonable_width = 10.0  # 10米，允许更大的门
    if door_width < 0.001
      puts "警告: 门的宽度#{door_width}米过小，使用默认值0.9米"
      door_width = 0.9
      
      # 计算门的中心点
      door_center = Geom::Point3d.new(
        (start_point.x + end_point.x) / 2,
        (start_point.y + end_point.y) / 2,
        (start_point.z + end_point.z) / 2
      )
      
      # 基于墙体方向重新计算门的起点和终点
      wall_vector = wall_end - wall_start
      wall_direction = wall_vector.normalize
      half_width = door_width / 2
      start_point = door_center - wall_direction * half_width
      end_point = door_center + wall_direction * half_width
      
      puts "重新计算门边界: 中心点=#{door_center}, 起点=#{start_point}, 终点=#{end_point}"
    elsif door_width > max_reasonable_width
      puts "警告: 门的宽度#{door_width}米过大，但继续使用原始尺寸"
      puts "门宽度: #{door_width}米"
    else
      puts "门宽度正常: #{door_width}米"
    end
    
    # 智能投影：将门坐标投影到墙体上
    puts "\n=== 坐标投影阶段 ==="
    projected_start = project_point_to_wall(start_point, wall_start, wall_end)
    projected_end = project_point_to_wall(end_point, wall_start, wall_end)
    
    puts "投影后门起点: #{projected_start.inspect}"
    puts "投影后门终点: #{projected_end.inspect}"
    
    # 获取墙体厚度（从已生成的墙体几何中提取）
    wall_thickness = extract_wall_thickness(wall_group, wall_data)
    puts "提取的墙体厚度: #{wall_thickness}英寸"
    
    # 计算门洞地面四点坐标
    puts "\n=== 门洞四点计算 ==="
    ground_points = calculate_door_ground_points(projected_start, projected_end, wall_thickness)
    
    puts "门洞地面四点:"
    ground_points.each_with_index do |point, i|
      puts "  点#{i+1}: #{point.inspect}"
    end
    
    # 创建门洞面
    wall_entities = wall_group.entities
    door_base_face = wall_entities.add_face(ground_points)
    
    if door_base_face
      puts "门洞面创建成功"
      
      # 直接沿Z轴正方向挖洞
      puts "开始沿Z轴正方向挖洞，高度: #{height}米"
      door_base_face.pushpull(height / 0.0254)
      
      puts "门洞生成完成！"
      puts "门高度: #{height}米"
      puts "门洞深度: #{wall_thickness * 0.0254}米"
    else
      puts "警告: 门洞面创建失败"
      puts "  地面四点: #{ground_points.inspect}"
    end
  
    model.commit_operation
  rescue => e
    model.abort_operation if model
    puts "创建门失败: #{Utils.ensure_utf8(e.message)}"
    puts "错误详情: #{e.backtrace.join("\n")}"
  end
  
  # 将点投影到墙体上
  def self.project_point_to_wall(point, wall_start, wall_end)
    wall_vector = wall_end - wall_start
    wall_length = wall_vector.length
    
    if wall_length < 0.001
      puts "警告: 墙体长度过小，无法投影"
      return point
    end
    
    # 计算点到墙体的投影
    wall_direction = wall_vector.normalize
    point_to_wall_start = point - wall_start
    
    # 计算投影参数 t (0 <= t <= 1 表示在墙体上)
    t = point_to_wall_start.dot(wall_direction) / wall_length
    
    # 限制投影点在墙体范围内
    t = [0.0, [t, 1.0].min].max
    
    # 计算投影点 - 修复向量乘法问题
    # 使用标量乘法而不是向量乘法
    projection_distance = t * wall_length
    projection_vector = wall_direction.clone
    projection_vector.length = projection_distance
    projected_point = wall_start + projection_vector
    
    puts "  原始点: #{point.inspect}"
    puts "  投影参数 t: #{t}"
    puts "  投影距离: #{projection_distance}"
    puts "  投影点: #{projected_point.inspect}"
    
    projected_point
  end
  
  # 从已生成的墙体几何中提取厚度
  def self.extract_wall_thickness(wall_group, wall_data)
    # 首先尝试从wall_data中获取厚度
    thickness_mm = Utils.parse_number(wall_data["thickness"] || 200)
    thickness_m = thickness_mm * 0.001
    thickness_inches = thickness_m / 0.0254
    
    puts "  从数据获取厚度: #{thickness_mm}mm = #{thickness_m}m = #{thickness_inches}英寸"
    
    # 如果厚度为0或无效，使用默认值
    if thickness_inches <= 0.001
      thickness_inches = 7.874  # 200mm = 7.874英寸
      puts "  使用默认厚度: #{thickness_inches}英寸"
    end
    
    thickness_inches
  end
  
  # 计算门洞地面四点坐标
  def self.calculate_door_ground_points(start_point, end_point, wall_thickness)
    # 计算墙体方向向量
    wall_vector = end_point - start_point
    wall_direction = wall_vector.normalize
    
    # 计算墙体法线（垂直于墙体方向和向上方向）
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 计算厚度向量 - 修复向量乘法问题
    thickness_vec = wall_normal.clone
    thickness_vec.length = wall_thickness
    
    # 计算门洞地面四点（逆时针顺序）
    ground_points = [
      start_point,                                    # 点1：起点
      start_point + thickness_vec,                    # 点2：起点+厚度
      end_point + thickness_vec,                      # 点3：终点+厚度
      end_point                                       # 点4：终点
    ]
    
    puts "  墙体方向: #{wall_direction.inspect}"
    puts "  墙体法线: #{wall_normal.inspect}"
    puts "  厚度向量: #{thickness_vec.inspect}"
    
    ground_points
  end
  
  # 导入独立门（非墙体上的门）
  def self.import_independent_door(door_data, parent_group)
    position = Utils.validate_and_create_point(door_data["position"])
    
    if !position
      puts "警告: 独立门位置无效，跳过 (ID: #{door_data['id'] || '未知'})"
      return
    end
    
    # 提取门的尺寸
    size = door_data["size"] || []
    width = Utils.parse_number(size[0] || 1.0)
    height = Utils.parse_number(size[1] || 2.0)
    depth = Utils.parse_number(size[2] || 0.1)
    
    # 确保尺寸有效
    width = 1.0 if width <= 0
    height = 2.0 if height <= 0
    depth = 0.1 if depth <= 0
    
    # 创建门组
    door_group = parent_group.entities.add_group
    door_group.name = door_data["name"] || "独立门"
    
    # 创建门的四个角点
    points = [
      position,
      position + Geom::Vector3d.new(width, 0, 0),
      position + Geom::Vector3d.new(width, 0, height),
      position + Geom::Vector3d.new(0, 0, height)
    ]
    
    # 应用旋转（如果有）
    orientation = Utils.parse_number(door_data["orientation"] || 0.0)
    if orientation != 0
      rotation = Geom::Transformation.rotation(position, Geom::Vector3d.new(0, 0, 1), orientation * Math::PI / 180)
      points.map! { |p| p.transform(rotation) }
    end
    
    # 创建门的面并拉伸
    door_face = door_group.entities.add_face(points)
    door_face.pushpull(depth) if door_face
    
    puts "创建独立门成功: #{door_group.name}"
  end
end 