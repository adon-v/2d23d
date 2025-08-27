# 测试2D到3D点坐标转换
module TapeBuilder2DTest
  def self.test_point_conversion
    puts "=== 测试2D到3D点坐标转换 ==="
    
    # 模拟你的实际数据格式
    test_points_2d = [
      [2766.9388854828667, 1334.6262438347812],
      [3408.2163496597022, 1334.6262438347812],
      [3408.2163496597022, 1747.2830581269764],
      [2766.9388854828667, 1747.2830581269764]
    ]
    
    puts "原始2D点坐标:"
    test_points_2d.each_with_index do |point, i|
      puts "  点#{i+1}: [#{point[0]}, #{point[1]}]"
    end
    
    # 模拟转换过程（与zone_builder中的逻辑一致）
    puts "\n转换为3D点坐标:"
    converted_points = test_points_2d.map do |point|
      if point.is_a?(Array) && point.size == 2
        # 如果是2D点 [x, y]，自动添加Z=0
        [point[0], point[1], 0]
      else
        point
      end
    end
    
    converted_points.each_with_index do |point, i|
      puts "  点#{i+1}: [#{point[0]}, #{point[1]}, #{point[2]}]"
    end
    
    # 验证转换结果
    puts "\n验证结果:"
    puts "  原始点数: #{test_points_2d.size}"
    puts "  转换后点数: #{converted_points.size}"
    puts "  所有点都有3个坐标: #{converted_points.all? { |p| p.size == 3 }}"
    puts "  Z坐标都为0: #{converted_points.all? { |p| p[2] == 0 }}"
    
    puts "\n=== 测试完成 ==="
  end
  
  def self.run_test
    test_point_conversion
  end
end

# 如果直接运行此文件，执行测试
if __FILE__ == $0
  TapeBuilder2DTest.run_test
end 