require_relative 'tape_constants'
require_relative 'tape_utils'
require_relative 'tape_conflict_detector'
require_relative 'tape_face_creator'
require_relative 'tape_elevator'
require_relative 'tape_material_applier'
require_relative 'tape_connection_handler'

module TapeBuilder
  class Builder
    # 为区域生成胶带
    def self.generate_zone_tape(zone_points, parent_group)
      begin
        return if !zone_points || zone_points.size < 3
        
        puts "调试：开始为区域生成胶带，点数: #{zone_points.size}"
        
        # 提取边界线段
        segments = extract_boundary_segments(zone_points)
        
        # 创建一个哈希表来记录已处理的边界点对
        processed_segments = {}
        
        # 为每个边界线段创建胶带
        segments.each do |segment|
          begin
            # 检查是否已处理过该线段（或其反向线段）
            segment_key = "#{segment[0].inspect}-#{segment[1].inspect}"
            reverse_segment_key = "#{segment[1].inspect}-#{segment[0].inspect}"
            
            if processed_segments[segment_key] || processed_segments[reverse_segment_key]
              puts "调试：跳过重复的线段: #{segment_key}"
              next
            end
            
            # 标记该线段为已处理
            processed_segments[segment_key] = true
            
            # 创建胶带平面
            tape_face = TapeFaceCreator.create_tape_for_segment(segment, TapeBuilder::TAPE_WIDTH, parent_group)
            
            # 如果成功创建了胶带面（无冲突）
            if tape_face && tape_face.valid?
              # 拉高胶带
              elevated_result = TapeElevator.elevate_tape(tape_face, TapeBuilder::TAPE_HEIGHT, TapeBuilder::TAPE_ELEVATION, parent_group)
              
              # 检查拉高结果
              if elevated_result
                if elevated_result.is_a?(Array)
                  # 如果返回的是面数组，使用第一个面作为主要面，但为所有面应用材质
                  puts "调试：拉高后返回 #{elevated_result.length} 个面"
                  elevated_face = elevated_result.first
                  
                  # 为整个胶带立方体应用材质（包括侧面和顶面）
                  TapeMaterialApplier.apply_tape_material_to_cube(elevated_face, parent_group)
                  
                  # 处理胶带连接
                  TapeConnectionHandler.handle_tape_connections(elevated_face, parent_group)
                else
                  # 如果返回的是单个面
                  elevated_face = elevated_result
                  
                  if elevated_face && elevated_face.valid?
                    # 为整个胶带立方体应用材质（包括侧面和顶面）
                    TapeMaterialApplier.apply_tape_material_to_cube(elevated_face, parent_group)
                    
                    # 处理胶带连接
                    TapeConnectionHandler.handle_tape_connections(elevated_face, parent_group)
                  else
                    puts "警告：拉高后胶带面无效，跳过应用材质"
                  end
                end
              else
                puts "警告：拉高操作失败，跳过应用材质"
              end
            end
          rescue => e
            puts "处理边界线段时出错: #{e.message}"
            puts e.backtrace.join("\n")
          end
        end
      rescue => e
        puts "生成胶带时出错: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
    
    # 直接接受点集生成胶带（与generate_zone_tape逻辑完全一致）
    def self.generate_tape_from_points(points, parent_group)
      begin
        return if !points || points.size < 3
        
        puts "调试：开始为点集生成胶带，点数: #{points.size}"
        
        # 提取边界线段
        segments = extract_boundary_segments(points)
        
        # 创建一个哈希表来记录已处理的边界点对
        processed_segments = {}
        
        # 为每个边界线段创建胶带
        segments.each do |segment|
          begin
            # 检查是否已处理过该线段（或其反向线段）
            segment_key = "#{segment[0].inspect}-#{segment[1].inspect}"
            reverse_segment_key = "#{segment[1].inspect}-#{segment[0].inspect}"
            
            if processed_segments[segment_key] || processed_segments[reverse_segment_key]
              puts "调试：跳过重复的线段: #{segment_key}"
              next
            end
            
            # 标记该线段为已处理
            processed_segments[segment_key] = true
            
            # 创建胶带平面
            tape_face = TapeFaceCreator.create_tape_for_segment(segment, TapeBuilder::TAPE_WIDTH, parent_group)
            
            # 如果成功创建了胶带面（无冲突）
            if tape_face && tape_face.valid?
              # 拉高胶带
              elevated_result = TapeElevator.elevate_tape(tape_face, TapeBuilder::TAPE_HEIGHT, TapeBuilder::TAPE_ELEVATION, parent_group)
              
              # 检查拉高结果
              if elevated_result
                if elevated_result.is_a?(Array)
                  # 如果返回的是面数组，使用第一个面作为主要面，但为所有面应用材质
                  puts "调试：拉高后返回 #{elevated_result.length} 个面"
                  elevated_face = elevated_result.first
                  
                  # 为整个胶带立方体应用材质（包括侧面和顶面）
                  TapeMaterialApplier.apply_tape_material_to_cube(elevated_face, parent_group)
                  
                  # 处理胶带连接
                  TapeConnectionHandler.handle_tape_connections(elevated_face, parent_group)
                else
                  # 如果返回的是单个面
                  elevated_face = elevated_result
                  
                  if elevated_face && elevated_face.valid?
                    # 为整个胶带立方体应用材质（包括侧面和顶面）
                    TapeMaterialApplier.apply_tape_material_to_cube(elevated_face, parent_group)
                    
                    # 处理胶带连接
                    TapeConnectionHandler.handle_tape_connections(elevated_face, parent_group)
                  else
                    puts "警告：拉高后胶带面无效，跳过应用材质"
                  end
                end
              else
                puts "警告：拉高操作失败，跳过应用材质"
              end
            end
          rescue => e
            puts "处理边界线段时出错: #{e.message}"
            puts e.backtrace.join("\n")
          end
        end
      rescue => e
        puts "生成胶带时出错: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
    
    # 提取边界线段
    def self.extract_boundary_segments(points)
      segments = []
      
      puts "调试：开始提取边界线段"
      puts "调试：输入点集数量: #{points.size}"
      puts "调试：输入点集详情:"
      points.each_with_index do |point, i|
        puts "  点#{i}: #{point.inspect}"
      end
      
      # 清理重复点和无效点
      cleaned_points = clean_point_set(points)
      puts "调试：清理后点集数量: #{cleaned_points.size}"
      puts "调试：清理后点集详情:"
      cleaned_points.each_with_index do |point, i|
        puts "  点#{i}: #{point.inspect}"
      end
      
      # 验证点集有效性
      if cleaned_points.size < 3
        puts "警告：清理后点集数量不足3个，无法形成有效多边形"
        return []
      end
      
      # 检查是否有重复的相邻点
      if has_duplicate_adjacent_points(cleaned_points)
        puts "警告：检测到相邻重复点，可能存在边界问题"
      end
      
      cleaned_points.each_with_index do |point, i|
        next_point = cleaned_points[(i + 1) % cleaned_points.size]
        
        # 检查线段长度
        segment_length = point.distance(next_point)
        puts "调试：创建线段 #{i}: #{point.inspect} -> #{next_point.inspect} (长度: #{segment_length.round(6)})"
        
        # 跳过零长度线段
        if segment_length < 0.001
          puts "警告：跳过零长度线段 #{i}"
          next
        end
        
        segments << [point, next_point]
      end
      
      puts "调试：提取完成，共生成 #{segments.size} 个有效边界线段"
      puts "调试：边界线段详情:"
      segments.each_with_index do |segment, i|
        puts "  线段#{i}: #{segment[0].inspect} -> #{segment[1].inspect}"
      end
      
      segments
    end
    
    # 清理点集，移除重复点和无效点
    def self.clean_point_set(points)
      return [] if points.nil? || points.empty?
      
      cleaned = []
      tolerance = 0.001  # 1毫米的容差
      
      points.each do |point|
        # 检查点是否有效
        next unless point && point.is_a?(Array) && point.size >= 2
        
        # 检查是否与已有点重复
        is_duplicate = cleaned.any? do |existing_point|
          existing_point.distance(point) < tolerance
        end
        
        unless is_duplicate
          cleaned << point
        else
          puts "调试：移除重复点 #{point.inspect}"
        end
      end
      
      cleaned
    end
    
    # 检查是否有重复的相邻点
    def self.has_duplicate_adjacent_points(points)
      return false if points.size < 2
      
      tolerance = 0.001
      points.each_with_index do |point, i|
        next_point = points[(i + 1) % points.size]
        if point.distance(next_point) < tolerance
          puts "警告：检测到相邻重复点 #{i} 和 #{(i + 1) % points.size}"
          return true
        end
      end
      
      false
    end
  end
end 