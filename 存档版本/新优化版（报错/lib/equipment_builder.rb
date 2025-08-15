# 设备构建模块：处理设备的导入和放置
module EquipmentBuilder
  # 导入设备
  def self.import_equipments(equipments_data, parent_group)
    return if !equipments_data || equipments_data.empty?
    
    puts "开始导入设备组件..."
    equipment_count = 0
    skp_lib_path = "F:/组件库构建/skp组件"
    
    equipments_data.each do |equipment_data|
      begin
        # 检查必要数据
        equipment_id = equipment_data["id"] || "E#{rand(10000)}"
        equipment_name = equipment_data["name"] || "未命名设备"
        skp_model = equipment_data["skp_model"]
        
        unless skp_model
          puts "警告: 设备 #{equipment_id} (#{equipment_name}) 缺少skp_model属性，无法导入"
          next
        end
        
        # 获取设备参数 - SketchUp 2024建筑毫米模式，直接使用毫米单位
        width = Utils.parse_number(equipment_data["width"] || 1000)
        length = Utils.parse_number(equipment_data["length"] || 1000)
        height = Utils.parse_number(equipment_data["height"] || 1000)
        rotation = Utils.parse_number(equipment_data["rotation"] || 0)  # 角度
        puts "e"
        puts width
        # 获取位置 - 只考虑二维坐标(x,y)，z坐标设为0
        position_data = equipment_data["position"]
        if position_data && position_data.is_a?(Array) && position_data.size >= 2
          # 强制设置z坐标为0，只关注二维平面
          position = Geom::Point3d.new(
            Utils.parse_number(position_data[0]), 
            Utils.parse_number(position_data[1]), 
            0
          )
        else
          puts "警告: 设备 #{equipment_id} (#{equipment_name}) 位置无效，使用默认位置"
          position = Geom::Point3d.new(0, 0, 0)
        end
        
        # 创建设备组
        equipment_group = parent_group.entities.add_group
        equipment_group.name = "#{equipment_name} (#{equipment_id})"
        equipment_group.set_attribute('FactoryImporter', 'equipment_id', equipment_id)
        
        # 导入SKP模型
        if import_skp_component(equipment_group, skp_model, skp_lib_path, position, width, length, height, rotation)
          equipment_count += 1
          puts "成功导入设备: #{equipment_name} (#{equipment_id})"
        else
          # 如果SKP导入失败，创建占位体
          create_placeholder(equipment_group, position, width, length, height, rotation)
          equipment_count += 1
          puts "为设备 #{equipment_id} (#{equipment_name}) 创建了占位体"
        end
        
      rescue => e
        error_msg = "导入设备失败 (ID: #{equipment_data['id'] || '未知'}): #{Utils.ensure_utf8(e.message)}"
        puts Utils.ensure_utf8(error_msg)
      end
    end
    
    puts "设备导入完成，共导入 #{equipment_count} 个设备"
  end
  
  # 导入SKP组件
  def self.import_skp_component(parent_group, skp_filename, skp_lib_path, position, width, length, height, rotation)
    model = Sketchup.active_model
    
    # 构建完整路径
    full_path = File.join(skp_lib_path, skp_filename)
    
    # 检查文件是否存在
    unless File.exist?(full_path)
      puts "警告: SKP文件不存在: #{full_path}"
      return false
    end
    
    begin
      # 使用正确的SketchUp API方法加载SKP文件
      # 1. 创建组件定义
      definitions = model.definitions
      component_definition = definitions.load(full_path)
      
      if component_definition
        # 创建实例并放入设备组
        transform = Geom::Transformation.new
        instance = parent_group.entities.add_instance(component_definition, transform)
        
        if instance
          # 获取原始包围盒
          bounds = component_definition.bounds
          
          # 计算缩放比例 - 只关注XY平面的二维缩放
          scale_x = width / bounds.width
          scale_y = length / bounds.depth
          scale_z = height / bounds.height
          puts "s"
          puts scale_x
          # 创建二维变换矩阵，忽略Z轴
          # 1. 先将模型中心移动到原点(只考虑x,y)
          t1 = Geom::Transformation.translation([-bounds.center.x, -bounds.center.y, 0])
          # 2. 缩放
          t2 = Geom::Transformation.scaling(scale_x, scale_y, scale_z)
          # 3. 二维旋转(只绕Z轴)
          t3 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, rotation * Math::PI / 180)
          # 4. 移动到目标位置(只考虑x,y)
          t4 = Geom::Transformation.translation([position.x, position.y, 0])
          
          # 应用变换
          transformation = t4 * t3 * t2 * t1
          instance.transform!(transformation)
          
          return true
        else
          puts "无法创建组件实例"
          return false
        end
      else
        puts "无法加载SKP文件: #{full_path}"
        return false
      end
    rescue => e
      puts "SKP导入错误: #{Utils.ensure_utf8(e.message)}"
      return false
    end
  end
  
  # 创建占位体 - 只考虑二维平面
  def self.create_placeholder(parent_group, position, width, length, height, rotation)
    # 计算占位体的四个角点 - 在二维平面上(z=0)
    half_width = width / 2
    half_length = length / 2
    
    points = [
      Geom::Point3d.new(position.x - half_width, position.y - half_length, 0),
      Geom::Point3d.new(position.x + half_width, position.y - half_length, 0),
      Geom::Point3d.new(position.x + half_width, position.y + half_length, 0),
      Geom::Point3d.new(position.x - half_width, position.y + half_length, 0)
    ]
    
    # 应用旋转 - 只绕Z轴旋转
    if rotation != 0
      # 创建以position为中心的旋转变换(二维旋转)
      transform = Geom::Transformation.rotation(
        Geom::Point3d.new(position.x, position.y, 0), 
        Z_AXIS, 
        rotation * Math::PI / 180
      )
      points.map! { |p| p.transform(transform) }
    end
    
    # 创建底面
    base_face = parent_group.entities.add_face(points)
    
    # 设置材质
    base_face.material = [200, 200, 100]  # 浅黄色
    
    # 拉伸
    base_face.pushpull(height) if base_face
  end
  
  # 定义常量
  ORIGIN = Geom::Point3d.new(0, 0, 0)
  Z_AXIS = Geom::Vector3d.new(0, 0, 1)
  IDENTITY = Geom::Transformation.new
end 