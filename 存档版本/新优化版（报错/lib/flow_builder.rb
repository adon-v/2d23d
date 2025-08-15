# 流构建模块：处理流和通道的创建
module FlowBuilder
  # 流的颜色定义
  FLOW_COLORS = [
    [255,0,0], [0,128,0], [0,0,255], [255,128,0], [128,0,255], [0,200,200], [200,200,0], [255,0,128], [128,128,0]
  ]
  
  # 导入流
  def self.import_flows(flows_data, parent_group)
    flows_data.each_with_index do |flow, idx|
      color = FLOW_COLORS[idx % FLOW_COLORS.size]
      arrow_color = [0,255,0]
      segments = flow["child_flows"] || []
      puts "【通道测试】flow[#{idx}] child_flows 数量: #{segments.size}"
      
      if !segments.is_a?(Array) || segments.empty?
        puts "【通道测试】警告: 当前flow没有有效的child_flows，无法生成通道"
        next
      end

      # 收集中心线点和宽度
      center_points = []
      widths = []
      
      segments.each_with_index do |seg, i|
        sp = Utils.validate_and_create_point(seg["start"])
        ep = Utils.validate_and_create_point(seg["end"])
        width = Utils.parse_number(seg["width"] || 3000.0)
        puts "t"
        puts width
        width = 500.0 if width.nil? || width <= 0
        
        unless sp && ep
          puts "【通道测试】警告: flow段无效，start=#{seg['start'].inspect}, end=#{seg['end'].inspect}"
          next
        end
        
        sp.z = 0; ep.z = 0
        
        if i == 0
          center_points << sp
          widths << width
        end
        
        if center_points.empty? || (ep.distance(center_points[-1]) > 1e-6)
          center_points << ep
          widths << width
        end
      end
      
      center_points = center_points.compact
      widths = widths[0, center_points.size]
      
      if center_points.size < 2
        puts "【通道测试】警告: 通道中心线点数不足，无法生成通道"
        next
      end

      # 计算每个点的"左/右边界线"
      left_lines = []
      right_lines = []
      n = center_points.size
      
      (0...n-1).each do |i|
        p1 = center_points[i]
        p2 = center_points[i+1]
        w = widths[i] || widths[0]
        dir = p2 - p1
        
        begin
          dir = dir.normalize
        rescue
          dir = Geom::Vector3d.new(1,0,0)
        end
        
        normal = Geom::Vector3d.new(-dir.y, dir.x, 0)
        
        begin
          normal = normal.normalize
        rescue
          normal = Geom::Vector3d.new(1,0,0)
        end
        
        left_lines << [p1.offset(normal, w/2.0), p2.offset(normal, w/2.0)]
        right_lines << [p1.offset(normal.reverse, w/2.0), p2.offset(normal.reverse, w/2.0)]
      end

      # 计算多边形顶点（交点法）
      left_pts = []
      right_pts = []
      
      # 左边界
      left_pts << left_lines[0][0]
      (1...left_lines.size).each do |i|
        pt = Utils.line_intersection_2d(left_lines[i-1][0], left_lines[i-1][1], left_lines[i][0], left_lines[i][1])
        left_pts << (pt || left_lines[i][0])
      end
      left_pts << left_lines[-1][1]
      
      # 右边界
      right_pts << right_lines[0][0]
      (1...right_lines.size).each do |i|
        pt = Utils.line_intersection_2d(right_lines[i-1][0], right_lines[i-1][1], right_lines[i][0], right_lines[i][1])
        right_pts << (pt || right_lines[i][0])
      end
      right_pts << right_lines[-1][1]

      polygon = left_pts + right_pts.reverse
      polygon = polygon.each_with_object([]) { |p, arr| arr << p if arr.empty? || (p.distance(arr[-1]) > 1e-6) }
      
      puts "【通道测试】最终多边形点数: #{polygon.size}"
      polygon.each_with_index { |pt, i| puts "【通道测试】多边形点#{i}: #{pt}" }
      
      if polygon.size >= 3
        # 通道面上浮200毫米，避免与地面和区域发生Z冲突
                  polygon = polygon.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 100.0) }
        face = parent_group.entities.add_face(polygon)
        if face
          face.material = color
          face.back_material = color
          puts "【通道测试】已生成横平竖直无重叠通道面，高度: z+200毫米"
        else
          puts "【通道测试】警告: 多段通道面生成失败"
        end
      else
        puts "【通道测试】警告: 通道多边形点数不足，无法生成面"
      end

      # 箭头
      puts "【箭头测试】准备生成箭头"
      segments.each_with_index do |seg, i|
        sp = Utils.validate_and_create_point(seg["start"])
        ep = Utils.validate_and_create_point(seg["end"])
        puts "【箭头测试】段#{i} sp: #{sp.inspect} (#{sp.class}), ep: #{ep.inspect} (#{ep.class})"
        
        next unless sp && ep
        
        dir = (ep - sp)
        puts "【箭头测试】段#{i} dir: #{dir.inspect} (#{dir.class})"
        
        next if dir.length < 1e-6
        
        width = Utils.parse_number(seg["width"] || 3000.0)
        width = 500.0 if width.nil? || width <= 0
        draw_arrow_flat(parent_group, sp, ep, width, arrow_color)
        puts "【通道测试】已绘制箭头于段#{i}"
      end
      puts "【箭头测试】箭头生成完成"
    end
  end
  
  # 创建直线箭头
  def self.draw_arrow_flat(group, start_pt, end_pt, width, color, z_offset=0.01)
    dir = end_pt - start_pt
    return if dir.length < 1e-6
    
    dir = dir.normalize
    seg_length = (end_pt - start_pt).length
    
    # 箭头中心点在通道段中点
    center = start_pt.offset(Geom::Vector3d.new(dir.x, dir.y, dir.z), seg_length/2)
    
    # 箭头长度和宽度参数
    shaft_length = [width * 2.0, seg_length * 0.8].min
    wing_length = width * 0.5
    wing_angle = 25.0  # 箭头翼与主轴夹角(度)
    
    # 计算箭头主轴两端点
    shaft_start = center.offset(Geom::Vector3d.new(-dir.x, -dir.y, -dir.z), shaft_length/2)
    shaft_end = center.offset(Geom::Vector3d.new(dir.x, dir.y, dir.z), shaft_length/2)
    
    # 悬浮
    shaft_start.z = shaft_end.z = z_offset
    
    # 绘制箭头主轴
    shaft_line = group.entities.add_line(shaft_start, shaft_end)
    shaft_line.material = color
    
    # 计算箭头翼角度
    wing_vec1 = Geom::Vector3d.new(dir.x, dir.y, 0).normalize
    angle_rad = wing_angle * Math::PI / 180
    
    # 箭头翼旋转
    wing_vec1.x, wing_vec1.y = 
      wing_vec1.x * Math.cos(-angle_rad) - wing_vec1.y * Math.sin(-angle_rad),
      wing_vec1.x * Math.sin(-angle_rad) + wing_vec1.y * Math.cos(-angle_rad)
      
    wing_vec2 = Geom::Vector3d.new(dir.x, dir.y, 0).normalize
    wing_vec2.x, wing_vec2.y = 
      wing_vec2.x * Math.cos(angle_rad) - wing_vec2.y * Math.sin(angle_rad),
      wing_vec2.x * Math.sin(angle_rad) + wing_vec2.y * Math.cos(angle_rad)
    
    # 绘制箭头两翼
    wing_end1 = shaft_end.offset(wing_vec1.reverse, wing_length)
    wing_end2 = shaft_end.offset(wing_vec2.reverse, wing_length)
    wing_end1.z = wing_end2.z = z_offset
    
    wing_line1 = group.entities.add_line(shaft_end, wing_end1)
    wing_line2 = group.entities.add_line(shaft_end, wing_end2)
    wing_line1.material = wing_line2.material = color
    
    puts "【箭头测试】直线箭头创建成功"
  end
  
  # 创建3D箭头（备用方法）
  def self.draw_arrow_3d(group, start_pt, end_pt, width, color, height=0.05)
    puts "【箭头测试】进入 draw_arrow_3d"
    
    dir = end_pt - start_pt
    if dir.length < 1e-6
      puts "【箭头测试】警告: 起点和终点重合，无法生成箭头"
      return
    end
    
    dir = dir.normalize
    center = start_pt.offset(Geom::Vector3d.new(dir.x, dir.y, dir.z), dir.length/2)
    arrow_length = [width * 1.5, dir.length * 0.6].min
    arrow_width = width * 0.7
    arrow_thickness = height

    base_center = center.offset(Geom::Vector3d.new(-dir.x, -dir.y, -dir.z), arrow_length/2)
    tip = center.offset(Geom::Vector3d.new(dir.x, dir.y, dir.z), arrow_length/2)
    normal = Geom::Vector3d.new(-dir.y, dir.x, 0).normalize
    left = base_center.offset(Geom::Vector3d.new(normal.x, normal.y, normal.z), arrow_width/2)
    right = base_center.offset(Geom::Vector3d.new(-normal.x, -normal.y, -normal.z), arrow_width/2)

    base_pts = [
      left,
      right,
      right.offset(Geom::Vector3d.new(0,0,arrow_thickness), 1),
      left.offset(Geom::Vector3d.new(0,0,arrow_thickness), 1)
    ]
    tip3d = tip.offset(Geom::Vector3d.new(0,0,arrow_thickness/2), 1)

    puts "【箭头测试】start_pt: #{start_pt}, end_pt: #{end_pt}"
    puts "【箭头测试】center: #{center}, arrow_length: #{arrow_length}, arrow_width: #{arrow_width}, arrow_thickness: #{arrow_thickness}"
    puts "【箭头测试】base_center: #{base_center}, tip: #{tip}, normal: #{normal}"
    base_pts.each_with_index { |pt, i| puts "【箭头测试】base_pts[#{i}]: #{pt}" }
    puts "【箭头测试】tip3d: #{tip3d}"

    arrow_group = group.entities.add_group
    # 底面
    face = arrow_group.entities.add_face(base_pts)
    if face
      face.material = color
      face.back_material = color
      puts "【箭头测试】底面创建成功"
    else
      puts "【箭头测试】底面创建失败"
    end
    
    # 两侧三角面
    face1 = arrow_group.entities.add_face(base_pts[0], base_pts[1], tip3d)
    face2 = arrow_group.entities.add_face(base_pts[2], base_pts[3], tip3d)
    puts "【箭头测试】侧面1: #{face1 ? '成功' : '失败'}，侧面2: #{face2 ? '成功' : '失败'}"
    
    # 前后三角面
    face3 = arrow_group.entities.add_face(base_pts[0], base_pts[3], tip3d)
    face4 = arrow_group.entities.add_face(base_pts[1], base_pts[2], tip3d)
    puts "【箭头测试】前面: #{face3 ? '成功' : '失败'}，后面: #{face4 ? '成功' : '失败'}"
    
    # 顶面
    top_face = arrow_group.entities.add_face(base_pts[3], base_pts[2], tip3d)
    if top_face
      top_face.material = color
      puts "【箭头测试】顶面创建成功"
    else
      puts "【箭头测试】顶面创建失败"
    end
  end
end 