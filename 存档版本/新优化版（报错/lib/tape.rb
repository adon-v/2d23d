# 胶带对象类，封装胶带的属性和生成逻辑
class Tape
  attr_reader :points, :zone_name, :is_shared, :tape_type, :tape_width, :tape_height_offset, :tape_thickness

  # 胶带配置参数
  TAPE_COLOR = [255, 255, 0, 255]  # 黄色，完全不透明
  SHARED_TAPE_COLOR = [255, 165, 0, 255]  # 橙色，共享边界
  TAPE_WIDTH = 50.0  # 胶带宽度（毫米）
  TAPE_HEIGHT_OFFSET = 150.0  # 胶带上浮高度（毫米）
  TAPE_THICKNESS = 10.0  # 胶带厚度（毫米）

  def initialize(points, zone_name, parent_group, is_shared: false, tape_type: 'zone_boundary', additional_attrs: {})
    @points = points
    @zone_name = zone_name
    @parent_group = parent_group
    @is_shared = is_shared
    @tape_type = tape_type
    @additional_attrs = additional_attrs
    @color = nil  # 用于自定义颜色
  end

  # 统一生成胶带面并设置所有属性
  def create_face
    return if points.size < 3
    
    # 上浮避免与区域重叠
    elevated_points = points.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + TAPE_HEIGHT_OFFSET) }
    
    # 生成胶带面
    tape_face = @parent_group.entities.add_face(elevated_points)
    return unless tape_face
    
    # 设置材质颜色
    tape_color = @color || (@is_shared ? SHARED_TAPE_COLOR : TAPE_COLOR)
    tape_face.material = tape_color
    tape_face.back_material = tape_color
    
    # 设置胶带属性
    set_tape_attributes(tape_face)
    
    # 确保胶带面在胶带层上
    tape_layer = create_tape_layer
    tape_face.layer = tape_layer if tape_layer
    
    # 为胶带添加厚度
    tape_face.pushpull(TAPE_THICKNESS)
    
    # 输出调试信息
    log_tape_creation(tape_face)
    
    tape_face
  end

  private

  def set_tape_attributes(tape_face)
    # 基础属性
    tape_face.set_attribute('FactoryImporter', 'tape_type', @tape_type)
    tape_face.set_attribute('FactoryImporter', 'zone_name', @zone_name)
    tape_face.set_attribute('FactoryImporter', 'tape_width', TAPE_WIDTH)
    tape_face.set_attribute('FactoryImporter', 'is_shared', @is_shared)
    
    # 额外属性
    @additional_attrs.each do |key, value|
      tape_face.set_attribute('FactoryImporter', key, value)
    end
  end

  def create_tape_layer
    model = Sketchup.active_model
    return unless model
    
    # 查找或创建胶带层
    tape_layer = model.layers.find { |layer| layer.name == "胶带层" }
    unless tape_layer
      tape_layer = model.layers.add("胶带层")
      puts "【胶带生成】创建胶带层: #{tape_layer.name}"
    end
    
    return tape_layer
  end

  def log_tape_creation(tape_face)
    tape_color = @color || (@is_shared ? SHARED_TAPE_COLOR : TAPE_COLOR)
    puts "【胶带生成】#{@zone_name}: 胶带生成成功"
    puts "  - 胶带宽度: #{TAPE_WIDTH}毫米"
    puts "  - 胶带高度: #{TAPE_HEIGHT_OFFSET}毫米"
    puts "  - 胶带厚度: #{TAPE_THICKNESS}毫米"
    puts "  - 胶带颜色: #{tape_color}"
    puts "  - 胶带点数: #{@points.size}"
    puts "  - 胶带类型: #{@tape_type}"
    puts "  - 是否共享: #{@is_shared}"
  end
end