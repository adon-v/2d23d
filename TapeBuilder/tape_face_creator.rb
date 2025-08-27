require_relative 'tape_constants'
require_relative 'tape_utils'
require_relative 'tape_conflict_detector'

module TapeBuilder
  class TapeFaceCreator
    # 为单个边界线段创建胶带平面
    def self.create_tape_for_segment(segment, width, parent_group)
      begin
        start_point, end_point = segment
        
        puts "调试：创建胶带，起点: #{start_point.inspect}, 终点: #{end_point.inspect}"
        
        # 检查线段长度是否为零
        direction = Utils.create_vector(start_point, end_point)
        length = direction.length
        puts "调试：线段长度: #{length}"
        
        if length < 0.001
          puts "警告：线段长度接近零，跳过胶带创建"
          return nil
        end
        
        # 检查是否有冲突
        if ConflictDetector.check_segment_conflict(segment, width, parent_group)
          puts "检测到边界线段存在冲突，跳过胶带创建"
          return nil
        end
        
        # 计算方向单位向量，用于调整线段端点
        direction_unit = direction.clone
        direction_unit.normalize!
        puts "调试：方向单位向量: #{direction_unit.inspect}"
        
        # 修改：左端点和右端点都延长半个胶带宽度
        adjusted_start_point = [
          start_point[0] - direction_unit.x * (width / 2), # 改为减法，延长起点
          start_point[1] - direction_unit.y * (width / 2), # 改为减法，延长起点
          start_point[2] - direction_unit.z * (width / 2)  # 改为减法，延长起点
        ]
        
        adjusted_end_point = [
          end_point[0] + direction_unit.x * (width / 2),
          end_point[1] + direction_unit.y * (width / 2),
          end_point[2] + direction_unit.z * (width / 2)
        ]
        
        puts "调试：调整后起点: #{adjusted_start_point.inspect}"
        puts "调试：调整后终点: #{adjusted_end_point.inspect}"
        
        # 转换为Sketchup点对象
        start_point_3d = Utils.create_point(adjusted_start_point)
        end_point_3d = Utils.create_point(adjusted_end_point)
        
        # 计算垂直于线段的单位向量
        perpendicular = Geom::Vector3d.new(-direction.y, direction.x, 0)
        perpendicular.normalize!
        puts "调试：垂直向量: #{perpendicular.inspect}"
        
        # 计算胶带四个角点
        half_width = width / 2.0
        p1 = start_point_3d.offset(perpendicular, half_width)
        p2 = start_point_3d.offset(perpendicular, -half_width)
        p3 = end_point_3d.offset(perpendicular, -half_width)
        p4 = end_point_3d.offset(perpendicular, half_width)
        
        puts "调试：胶带四个角点:"
        puts "调试：p1: #{p1.inspect}"
        puts "调试：p2: #{p2.inspect}"
        puts "调试：p3: #{p3.inspect}"
        puts "调试：p4: #{p4.inspect}"
        
        # 检查四个点是否共面
        is_planar = true
        normal = Geom::Vector3d.new
        begin
          # 修正：使用正确的vector_product方法
          v1 = Geom::Vector3d.new(p2.x - p1.x, p2.y - p1.y, p2.z - p1.z)
          v2 = Geom::Vector3d.new(p3.x - p1.x, p3.y - p1.y, p3.z - p1.z)
          normal = v1.cross(v2)
          normal.normalize!
          
          # 检查第四个点是否在同一平面上
          vector_to_p4 = Geom::Vector3d.new(p4.x - p1.x, p4.y - p1.y, p4.z - p1.z)
          if (vector_to_p4.dot(normal)).abs > 0.001
            is_planar = false
            puts "调试：警告 - 四个点不共面，可能导致pushpull问题"
          end
        rescue => e
          puts "调试：计算平面时出错: #{e.message}"
          is_planar = false
        end
        puts "调试：四点共面检查: #{is_planar ? '共面' : '不共面'}"
        
        # 创建胶带面
        face = parent_group.entities.add_face([p1, p2, p3, p4])
        
        # 检查面是否创建成功且有效
        if !face || !face.valid?
          puts "警告：创建的胶带面无效，跳过该段胶带"
          return nil
        end
        
        puts "调试：成功创建面，有效性: #{face.valid?}"
        puts "调试：面的顶点数: #{face.vertices.length}"
        puts "调试：面的边数: #{face.edges.length}"
        
        # 确保面的法线朝上
        if face.normal.z < 0
          face.reverse!
          puts "调试：面被反转，使法线朝上"
        end
        puts "调试：面的法线: #{face.normal.inspect}"
        
        face
      rescue => e
        puts "创建胶带平面时出错: #{e.message}"
        puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
        return nil
      end
    end
  end
end 