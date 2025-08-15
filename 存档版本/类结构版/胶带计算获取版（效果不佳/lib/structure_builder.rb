# 结构构建模块：处理柱子、通道和对象的创建
module StructureBuilder
  # 导入柱子
  
  def self.import_columns(columns_data, parent_group)
    inch_scale_factor = 25.4
    columns_data.each do |column_data|
      begin
        points = column_data["points"].map { |point| Utils.validate_and_create_point(point) }
        next if points.size < 3
        puts points
        height = Utils.parse_number("10000" || 3.0)
        height = 3.0 if height <= 0
        height = height / inch_scale_factor
        column_face = parent_group.entities.add_face(points)
        column_face.pushpull(-height) if column_face
      rescue => e
        puts "创建柱子失败: #{Utils.ensure_utf8(e.message)}"
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
        width = Utils.parse_number(size[0] || 1.0)
        length = Utils.parse_number(size[1] || 1.0)
        height = Utils.parse_number(size[2] || 1.0)
        
        width = 1.0 if width <= 0
        length = 1.0 if length <= 0
        height = 1.0 if height <= 0
        
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