# 结构构建模块：处理柱子、通道和对象的创建
module StructureBuilder
  # 导入柱子
  
  def self.import_columns(columns_data, parent_group)
    # SketchUp 2024建筑毫米模式，直接使用毫米单位
    columns_data.each do |column_data|
      begin
        # 验证输入数据
        unless column_data && column_data["points"]
          puts "警告: 立柱数据不完整，跳过"
          next
        end
        
        points = column_data["points"].map { |point| Utils.validate_and_create_point(point) }.compact
        next if points.size < 3
        
        puts "创建立柱: #{column_data['name'] || column_data['id']}"
        puts "立柱点数: #{points.size}"
        
        # 验证点的有效性
        valid_points = points.select { |pt| pt && pt.valid? }
        if valid_points.size < 3
          puts "警告: 立柱有效点数不足，跳过"
          next
        end
        
        # 创建立柱面
        column_face = parent_group.entities.add_face(valid_points)
        unless column_face && column_face.valid?
          puts "警告: 无法创建立柱面，跳过"
          next
        end
        
        # 设置立柱高度
        height = Utils.parse_number("10000" || 3000.0)
        height = 3000.0 if height <= 0
        # SketchUp 2024建筑毫米模式，直接使用毫米单位
        
        # 拉伸立柱
        begin
          column_face.pushpull(-height)
          puts "立柱拉伸成功，高度: #{height}米"
        rescue => e
          puts "立柱拉伸失败: #{e.message}"
          # 即使拉伸失败，也保留立柱面
        end
        
        # 设置立柱材质和颜色
        begin
          column_face.material = [128, 128, 128]  # 灰色
          column_face.back_material = [128, 128, 128]
          puts "立柱材质设置成功"
        rescue => e
          puts "立柱材质设置失败: #{e.message}"
        end
        
        # 设置立柱属性
        begin
          column_face.set_attribute('FactoryImporter', 'element_type', 'column')
          column_face.set_attribute('FactoryImporter', 'column_name', column_data['name'] || '立柱')
          column_face.set_attribute('FactoryImporter', 'column_id', column_data['id'])
        rescue => e
          puts "立柱属性设置失败: #{e.message}"
        end
        
        puts "立柱创建成功: #{column_data['name'] || column_data['id']}"
        
      rescue => e
        puts "创建立柱失败: #{Utils.ensure_utf8(e.message)}"
        puts "立柱数据: #{column_data.inspect}"
      end
    end
  end
  

  # 导入对象
  def self.import_objects(objects_data, parent_group)
    objects_data.each do |object_data|
      begin
        position = Utils.validate_and_create_point(object_data["position"])
        next if !position
        
        size = object_data["size"] || []
        width = Utils.parse_number(size[0] || 1000.0)
        length = Utils.parse_number(size[1] || 1000.0)
        height = Utils.parse_number(size[2] || 1000.0)
        
        width = 1000.0 if width <= 0
        length = 1000.0 if length <= 0
        height = 1000.0 if height <= 0
        
        orientation = Utils.parse_number(object_data["orientation"] || 0.0)
        
        object_group = parent_group.entities.add_group
        object_group.name = object_data["type"] || "对象"
        
        points = [
          position,
          position + Geom::Vector3d.new(width, 0, 0),
          position + Geom::Vector3d.new(width, length, 0),
          position + Geom::Vector3d.new(0, length, 0)
        ]
        
        if orientation != 0
          rotation = Geom::Transformation.rotation(position, Geom::Vector3d.new(0, 0, 1), orientation * Math::PI / 180)
          points.map! { |p| p.transform(rotation) }
        end
        
        object_face = object_group.entities.add_face(points)
        object_face.pushpull(-height) if object_face
      rescue => e
        puts "创建对象失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
  end
end 