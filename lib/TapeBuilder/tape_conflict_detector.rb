require_relative 'tape_constants'
require_relative 'tape_utils'

module TapeBuilder
  class ConflictDetector
    # 检查边界线段位置是否已有实体
    def self.check_segment_conflict(segment, width, parent_group)
      # 启用冲突检测
       return false # 注释掉这一行以启用冲突检测
      
      puts "调试：开始检查线段冲突"
      start_point, end_point = segment
      
      # 计算线段方向向量
      direction = Utils.create_vector(start_point, end_point)
      
      # 计算方向单位向量，用于延长线段
      direction_unit = direction.clone
      direction_unit.normalize!
      
      # 修改：检测时缩小线段两端各半个胶带宽度（更保守的检测范围）
      # 生成时仍然使用延长半个胶带宽度
      conflict_start_point = [
        start_point[0] + direction_unit.x * (width / 2), # 改为加法，缩小起点
        start_point[1] + direction_unit.y * (width / 2), # 改为加法，缩小起点
        start_point[2] + direction_unit.z * (width / 2)  # 改为加法，缩小起点
      ]
      
      conflict_end_point = [
        end_point[0] - direction_unit.x * (width / 2),   # 改为减法，缩小终点
        end_point[1] - direction_unit.y * (width / 2),   # 改为减法，缩小终点
        end_point[2] - direction_unit.z * (width / 2)    # 改为减法，缩小终点
      ]
      
      puts "调试：检测范围（缩小后）：起点 #{conflict_start_point.inspect}，终点 #{conflict_end_point.inspect}"
      puts "调试：原始线段：起点 #{start_point.inspect}，终点 #{end_point.inspect}"
      
      # 转换为Sketchup点对象
      start_point_3d = Utils.create_point(conflict_start_point)
      end_point_3d = Utils.create_point(conflict_end_point)
      
      # 计算垂直于线段的单位向量
      perpendicular = Geom::Vector3d.new(-direction.y, direction.x, 0)
      perpendicular.normalize!
      
      # 计算胶带四个底部角点（考虑悬浮高度）
      half_width = width / 2.0
      elevation = TapeBuilder::TAPE_ELEVATION
      
      # 底部四个角点（悬浮高度）
      p1_bottom = start_point_3d.offset(perpendicular, half_width)
      p1_bottom.z += elevation
      p2_bottom = start_point_3d.offset(perpendicular, -half_width)
      p2_bottom.z += elevation
      p3_bottom = end_point_3d.offset(perpendicular, -half_width)
      p3_bottom.z += elevation
      p4_bottom = end_point_3d.offset(perpendicular, half_width)
      p4_bottom.z += elevation
      
      puts "调试：胶带底部四角点："
      puts "调试：p1_bottom: #{p1_bottom.inspect}"
      puts "调试：p2_bottom: #{p2_bottom.inspect}"
      puts "调试：p3_bottom: #{p3_bottom.inspect}"
      puts "调试：p4_bottom: #{p4_bottom.inspect}"
      
      # 顶部四个角点（悬浮高度+胶带厚度）
      height = TapeBuilder::TAPE_HEIGHT
      p1_top = p1_bottom.clone
      p1_top.z += height
      p2_top = p2_bottom.clone
      p2_top.z += height
      p3_top = p3_bottom.clone
      p3_top.z += height
      p4_top = p4_bottom.clone
      p4_top.z += height
      
      # 在胶带区域内发射多条射线检测是否有实体
      has_conflict = false
      
      # 在线段上均匀分布检测点
      check_points = [] # 修复：初始化check_points数组
      ray_count = TapeBuilder::CONFLICT_RAY_COUNT || 5 # 默认使用5个检测点
      ray_count.times do |i|
        ratio = i.to_f / (ray_count - 1)
        
        # 底部检测点（从p1_bottom到p4_bottom，从p2_bottom到p3_bottom）
        mid_point_bottom1 = Geom::Point3d.new(
          p1_bottom.x + ratio * (p4_bottom.x - p1_bottom.x),
          p1_bottom.y + ratio * (p4_bottom.y - p1_bottom.y),
          p1_bottom.z + ratio * (p4_bottom.z - p1_bottom.z)
        )
        mid_point_bottom2 = Geom::Point3d.new(
          p2_bottom.x + ratio * (p3_bottom.x - p2_bottom.x),
          p2_bottom.y + ratio * (p3_bottom.y - p2_bottom.y),
          p2_bottom.z + ratio * (p3_bottom.z - p2_bottom.z)
        )
        
        # 顶部检测点（从p1_top到p4_top，从p2_top到p3_top）
        mid_point_top1 = Geom::Point3d.new(
          p1_top.x + ratio * (p4_top.x - p1_top.x),
          p1_top.y + ratio * (p4_top.y - p1_top.y),
          p1_top.z + ratio * (p4_top.z - p1_top.z)
        )
        mid_point_top2 = Geom::Point3d.new(
          p2_top.x + ratio * (p3_top.x - p2_top.x),
          p2_top.y + ratio * (p3_top.y - p2_top.y),
          p2_top.z + ratio * (p3_top.z - p2_top.z)
        )
        
        # 添加垂直方向的检测（从底部到顶部）
        check_points << [mid_point_bottom1, mid_point_top1]
        check_points << [mid_point_bottom2, mid_point_top2]
        
        # 添加水平方向的检测（在底部和顶部平面内）
        check_points << [mid_point_bottom1, mid_point_bottom2]
        check_points << [mid_point_top1, mid_point_top2]
        
        # 验证添加的点对
        puts "调试：添加检测点对 #{i}:"
        puts "调试：  垂直1: #{mid_point_bottom1.inspect} -> #{mid_point_top1.inspect}"
        puts "调试：  垂直2: #{mid_point_bottom2.inspect} -> #{mid_point_top2.inspect}"
        puts "调试：  水平1: #{mid_point_bottom1.inspect} -> #{mid_point_bottom2.inspect}"
        puts "调试：  水平2: #{mid_point_top1.inspect} -> #{mid_point_top2.inspect}"
      end
      
      # 额外添加一条从上表面中点到下表面中点的垂直线段
      # 计算上表面中点
      top_center = Geom::Point3d.new(
        (p1_top.x + p2_top.x + p3_top.x + p4_top.x) / 4.0,
        (p1_top.y + p2_top.y + p3_top.y + p4_top.y) / 4.0,
        (p1_top.z + p2_top.z + p3_top.z + p4_top.z) / 4.0
      )
      
      # 计算下表面中点
      bottom_center = Geom::Point3d.new(
        (p1_bottom.x + p2_bottom.x + p3_bottom.x + p4_bottom.x) / 4.0,
        (p1_bottom.y + p2_bottom.y + p3_bottom.y + p4_bottom.y) / 4.0,
        (p1_bottom.z + p2_bottom.z + p3_bottom.z + p4_bottom.z) / 4.0
      )
      
      # 添加中心垂直线段检测
      check_points << [top_center, bottom_center]
      
      puts "调试：额外添加中心垂直线段检测:"
      puts "调试：  上表面中点: #{top_center.inspect}"
      puts "调试：  下表面中点: #{bottom_center.inspect}"
      puts "调试：  中心垂直线: #{top_center.inspect} -> #{bottom_center.inspect}"
      
      puts "调试：共创建 #{check_points.length} 条检测射线"
      
      # 验证check_points数组的内容
      puts "调试：检查点对数组内容:"
      check_points.each_with_index do |point_pair, index|
        puts "调试：  点对 #{index}: #{point_pair[0].class.name} -> #{point_pair[1].class.name}"
        puts "调试：    起点: #{point_pair[0].inspect}"
        puts "调试：    终点: #{point_pair[1].inspect}"
      end
      
      # 检查每个点对之间是否有实体
      model = Sketchup.active_model
      conflict_count = 0
      
      check_points.each_with_index do |point_pair, index|
        # 验证点对是否有效
        if !point_pair[0] || !point_pair[1] || 
           !point_pair[0].is_a?(Geom::Point3d) || !point_pair[1].is_a?(Geom::Point3d)
          puts "调试：跳过无效的点对 #{index}: #{point_pair.inspect}"
          next
        end
        
        # 创建从point_pair[0]到point_pair[1]的方向向量
        ray_vector = Geom::Vector3d.new(
          point_pair[1].x - point_pair[0].x,
          point_pair[1].y - point_pair[0].y,
          point_pair[1].z - point_pair[0].z
        )
        
        # 计算射线的预期长度（两点之间的距离）
        expected_length = point_pair[0].distance(point_pair[1])
        
        # 执行射线测试
        hit_item = model.raytest(point_pair[0], ray_vector)
        if hit_item && hit_item[0]
          # 获取击中点
          hit_point = hit_item[1]
          
          # 验证击中点是否有效
          if hit_point && hit_point.is_a?(Geom::Point3d)
            # 计算击中点与射线起点的距离
            hit_distance = point_pair[0].distance(hit_point)
            
            # 只有当击中点在射线预期长度内才认为有冲突
            # 添加一个小的容差(0.001)以处理浮点误差
            if hit_distance <= expected_length + 0.001
              conflict_count += 1
              puts "调试：射线 #{index} 检测到冲突，距离: #{hit_distance}"
              
              # 获取被击中的实体信息
              hit_entity = hit_item[0]
              puts "调试：冲突实体类型: #{hit_entity.class.name}"
              
              has_conflict = true
              # 不立即退出，继续检测以获取更多信息
              # break
            end
          else
            puts "调试：射线 #{index} 击中点无效: #{hit_point.inspect}"
          end
        end
      end
      
      if has_conflict
        puts "调试：检测到 #{conflict_count} 条射线有冲突，总共 #{check_points.length} 条射线"
      else
        puts "调试：未检测到冲突"
      end
      
      return has_conflict
    end
  end
end