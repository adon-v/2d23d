module TapeBuilder
  module Utils
    # 检查点是否有效
    def self.valid_point?(point)
      point && point.is_a?(Array) && point.size >= 3
    end
    
    # 计算两点之间的距离
    def self.distance_between_points(point1, point2)
      Math.sqrt((point2[0] - point1[0])**2 + (point2[1] - point1[1])**2 + (point2[2] - point1[2])**2)
    end
    
    # 创建Sketchup点对象
    def self.create_point(coordinates)
      Geom::Point3d.new(coordinates[0], coordinates[1], coordinates[2])
    end
    
    # 创建向量对象
    def self.create_vector(start_point, end_point)
      Geom::Vector3d.new(
        end_point[0] - start_point[0],
        end_point[1] - start_point[1],
        end_point[2] - start_point[2]
      )
    end
  end
end 