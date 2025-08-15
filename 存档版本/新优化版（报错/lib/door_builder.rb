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
    
    # 提取门的高度 - SketchUp 2024建筑毫米模式，直接使用毫米单位
    height = Utils.parse_number(door_data["height"]) || 2100.0
    height = 2100.0 if height <= 0
    
    # 墙体厚度 - SketchUp 2024建筑毫米模式，直接使用毫米单位
    wall_thickness = Utils.parse_number(wall_data["thickness"]) || 200.0
    
    puts "在墙体上创建门开口: 起点=#{start_point}, 终点=#{end_point}, 高度=#{height}mm, 墙体厚度=#{wall_thickness}mm"
    
    # 计算墙体的方向
    wall_start = Utils.validate_and_create_point(wall_data["start"])
    wall_end = Utils.validate_and_create_point(wall_data["end"])
    
    if !wall_start || !wall_end
      puts "警告: 墙体坐标无效，无法创建门开口"
      return
    end
    
    # 计算墙体方向向量
    wall_vector = wall_end - wall_start
    if wall_vector.length < 1.0
      puts "警告: 墙体向量长度过小，无法创建门开口"
      return
    end
    
    # 根据墙体厚度处理不同情况
    if wall_thickness <= 1.0
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
    if wall_vector.length >= 1.0
      wall_direction = wall_vector.normalize
    else
      # 如果墙体向量无效，尝试从门的起点和终点推断方向
      door_vector = end_point - start_point
      
      # 检查门向量有效性
      if door_vector.length >= 1.0
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
    if door_width < 1.0
      puts "警告: 门的宽度过小，使用默认值900mm"
      door_width = 900.0
      
      # 当宽度无效时，基于墙体方向计算门的起点和终点
      half_width = door_width / 2
      start_point = door_center - wall_direction * half_width
      end_point = door_center + wall_direction * half_width
    end
    
    # 计算墙体法线方向（垂直于墙体方向和向上方向）
    wall_normal = wall_direction.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    
    # 确保法线向量有效
    if wall_normal.length < 1.0
      wall_normal = Geom::Vector3d.new(0, 1, 0)  # 默认垂直于X轴
      puts "警告: 法线向量计算失败，使用默认法线方向"
    end
    
    # 计算门的四个角点
    door_points = [
      start_point,
      end_point,
      end_point + Geom::Vector3d.new(0, 0, height),
      start_point + Geom::Vector3d.new(0, 0, height)
    ]
    
    # 找到墙体的面（单面墙只有一个面）
    wall_face = wall_entities.grep(Sketchup::Face).find { |f| 
      normal = f.normal
              (normal.z.abs < 1.0) && !f.deleted?
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
        puts "在厚度为0的墙体上创建门成功"
      else
        puts "警告: 创建门的面失败，点可能共线或无效"
        puts "  门点: #{door_points.inspect}"
      end
    rescue Exception => e
      puts "警告: 创建门时出错: #{e.message}"
      puts "  门点: #{door_points.inspect}"
    end
  end
  
  # 在正常厚度墙体上创建门
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
  
    wall_vector = wall_end - wall_start
    if wall_vector.length < 1.0
      puts "警告: 墙体向量长度过小，无法创建门"
      model.abort_operation
      return
    end
  
    # 计算墙体厚度方向（法线）
    wall_normal = wall_vector.cross(Geom::Vector3d.new(0, 0, 1)).normalize
    wall_normal = wall_normal.reverse if wall_normal.x < 0
  
    # 墙体厚度 - SketchUp 2024建筑毫米模式，直接使用毫米单位
    wall_thickness = Utils.parse_number(wall_data["thickness"]) || 200.0
    wall_thickness = 200.0 if wall_thickness <= 0

    # 门宽度和方向
    door_vector = end_point - start_point
    door_width = door_vector.length
    if door_width < 1.0
      puts "警告: 门的宽度过小，使用默认值900mm"
      door_width = 900.0
      door_center = Geom::Point3d.new(
        (start_point.x + end_point.x) / 2,
        (start_point.y + end_point.y) / 2,
        (start_point.z + end_point.z) / 2
      )
      door_direction = wall_vector.normalize
      start_point = door_center - door_direction * (door_width / 2)
      end_point = door_center + door_direction * (door_width / 2)
    else
      door_direction = door_vector.normalize
    end
  
    # 计算厚度方向向量
    thickness_vec = wall_normal.clone
    thickness_vec.length = wall_thickness

    # 门洞底部四点
    bottom_points = [
      start_point,
      end_point,
      end_point + thickness_vec,
      start_point + thickness_vec
    ]
    top_points = bottom_points.map { |p| p + Geom::Vector3d.new(0, 0, height) }
  
    # 创建门洞面并拉伸
    puts bottom_points
    wall_entities = wall_group.entities
    door_base_face = wall_entities.add_face(bottom_points)
    if door_base_face
      door_base_face.pushpull(height)
      puts height
      puts "在墙体上成功创建门洞，厚度=#{wall_thickness}mm"
    else
      puts "警告: 创建门洞面失败，点可能共线或无效"
      puts "  门点: #{bottom_points.inspect}"
    end
  
    model.commit_operation
  rescue => e
    model.abort_operation if model
    puts "创建门失败: #{Utils.ensure_utf8(e.message)}"
  end
  
  # 导入独立门（非墙体上的门）
  def self.import_independent_door(door_data, parent_group)
    position = Utils.validate_and_create_point(door_data["position"])
    
    if !position
      puts "警告: 独立门位置无效，跳过 (ID: #{door_data['id'] || '未知'})"
      return
    end
    
    # 提取门的尺寸 - SketchUp 2024建筑毫米模式，直接使用毫米单位
    size = door_data["size"] || []
    width = Utils.parse_number(size[0] || 900.0)
    height = Utils.parse_number(size[1] || 2100.0)
    depth = Utils.parse_number(size[2] || 100.0)
    
    # 确保尺寸有效
    width = 900.0 if width <= 0
    height = 2100.0 if height <= 0
    depth = 100.0 if depth <= 0
    
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