# 坐标预处理模块：将工厂模型平移到第一象限
module CoordinateProcessor
  # 处理整个工厂布局的坐标，平移到第一象限
  def self.process_factory_coordinates(layout_data)
    puts "=== 开始坐标预处理 ==="
    
    # 分析所有坐标，找到最小和最大坐标值
    coord_bounds = analyze_coordinates(layout_data)
    min_coords = coord_bounds[:min]
    max_coords = coord_bounds[:max]
    
    puts "发现的最小坐标: X=#{min_coords[:x]}, Y=#{min_coords[:y]}, Z=#{min_coords[:z]}"
    puts "发现的最大坐标: X=#{max_coords[:x]}, Y=#{max_coords[:y]}, Z=#{max_coords[:z]}"
    
    # 如果所有坐标已经在第一象限，不需要处理
    if min_coords[:x] >= 0 && min_coords[:y] >= 0 && min_coords[:z] >= 0
      puts "所有坐标已在第一象限，无需平移"
      return layout_data
    end
    
    # 计算需要平移的距离
    offset_x = min_coords[:x] < 0 ? -min_coords[:x] : 0
    offset_y = min_coords[:y] < 0 ? -min_coords[:y] : 0
    offset_z = min_coords[:z] < 0 ? -min_coords[:z] : 0
    
    puts "计算平移距离: X=#{offset_x}, Y=#{offset_y}, Z=#{offset_z}"
    
    # 应用坐标平移
    translated_data = translate_coordinates(layout_data, offset_x, offset_y, offset_z)
    
    puts "坐标预处理完成，模型已平移到第一象限"
    puts "新的坐标范围: X=[#{offset_x}, #{offset_x + (max_coords[:x] - min_coords[:x])}], Y=[#{offset_y}, #{offset_y + (max_coords[:y] - min_coords[:y])}], Z=[#{offset_z}, #{offset_z + (max_coords[:z] - min_coords[:z])}]"
    
    translated_data
  end
  
  private
  
  # 分析所有坐标，找到最小和最大坐标值
  def self.analyze_coordinates(layout_data)
    min_coords = { x: Float::INFINITY, y: Float::INFINITY, z: Float::INFINITY }
    max_coords = { x: -Float::INFINITY, y: -Float::INFINITY, z: -Float::INFINITY }
    
    # 递归遍历所有坐标属性
    traverse_coordinates(layout_data, min_coords, max_coords)
    
    { min: min_coords, max: max_coords }
  end
  
  # 递归遍历数据结构，查找所有坐标
  def self.traverse_coordinates(data, min_coords, max_coords)
    case data
    when Hash
      data.each do |key, value|
        if coordinate_key?(key)
          process_coordinate_value(value, min_coords, max_coords)
        else
          traverse_coordinates(value, min_coords, max_coords)
        end
      end
    when Array
      data.each do |item|
        traverse_coordinates(item, min_coords, max_coords)
      end
    end
  end
  
  # 判断是否为坐标相关的键
  def self.coordinate_key?(key)
    coordinate_keys = %w[start end points position size]
    coordinate_keys.any? { |k| key.to_s.include?(k) }
  end
  
  # 处理坐标值
  def self.process_coordinate_value(value, min_coords, max_coords)
    case value
    when Array
      if value.all? { |v| v.is_a?(Numeric) }
        # 这是一个坐标点
        if value.size >= 2
          x, y = value[0], value[1]
          z = value.size >= 3 ? value[2] : 0
          
          min_coords[:x] = [min_coords[:x], x].min
          min_coords[:y] = [min_coords[:y], y].min
          min_coords[:z] = [min_coords[:z], z].min
          
          max_coords[:x] = [max_coords[:x], x].max
          max_coords[:y] = [max_coords[:y], y].max
          max_coords[:z] = [max_coords[:z], z].max
        end
      else
        # 递归处理数组中的元素
        value.each { |item| process_coordinate_value(item, min_coords, max_coords) }
      end
    when Hash
      # 递归处理哈希
      traverse_coordinates(value, min_coords, max_coords)
    end
  end
  
  # 应用坐标平移
  def self.translate_coordinates(layout_data, offset_x, offset_y, offset_z)
    # 深拷贝数据，避免修改原始数据
    translated_data = deep_clone(layout_data)
    
    # 递归应用平移
    apply_translation(translated_data, offset_x, offset_y, offset_z)
    
    translated_data
  end
  
  # 递归应用坐标平移
  def self.apply_translation(data, offset_x, offset_y, offset_z)
    case data
    when Hash
      data.each do |key, value|
        if coordinate_key?(key)
          data[key] = translate_coordinate_value(value, offset_x, offset_y, offset_z)
        else
          apply_translation(value, offset_x, offset_y, offset_z)
        end
      end
    when Array
      data.each_with_index do |item, index|
        if item.is_a?(Numeric) && coordinate_array?(data)
          # 这是一个坐标数组，应用平移
          if index == 0
            data[index] = item + offset_x
          elsif index == 1
            data[index] = item + offset_y
          elsif index == 2
            data[index] = item + offset_z
          end
        else
          # 递归处理
          apply_translation(item, offset_x, offset_y, offset_z)
        end
      end
    end
  end
  
  # 判断数组是否为坐标数组
  def self.coordinate_array?(array)
    array.size >= 2 && array.size <= 3 && array.all? { |v| v.is_a?(Numeric) }
  end
  
  # 平移单个坐标值
  def self.translate_coordinate_value(value, offset_x, offset_y, offset_z)
    case value
    when Array
      if coordinate_array?(value)
        # 这是一个坐标点，应用平移
        translated = value.dup
        translated[0] += offset_x if translated[0]
        translated[1] += offset_y if translated[1]
        translated[2] += offset_z if translated[2] && translated.size >= 3
        translated
      else
        # 递归处理
        value.map { |item| translate_coordinate_value(item, offset_x, offset_y, offset_z) }
      end
    when Hash
      # 递归处理哈希
      translated_hash = {}
      value.each do |k, v|
        translated_hash[k] = translate_coordinate_value(v, offset_x, offset_y, offset_z)
      end
      translated_hash
    else
      value
    end
  end
  
  # 深拷贝数据
  def self.deep_clone(data)
    case data
    when Hash
      data.transform_values { |v| deep_clone(v) }
    when Array
      data.map { |item| deep_clone(item) }
    else
      data
    end
  end
end 