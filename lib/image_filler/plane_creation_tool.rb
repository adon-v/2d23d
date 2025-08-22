# 平面创建工具：两点交互创建竖直矩形面
module ImageFiller
  class PlaneCreationTool
    def initialize(material)
      @material = material
      @state = :waiting_first
      @ip1 = Sketchup::InputPoint.new
      @ip2 = Sketchup::InputPoint.new
      @mouse_ip = Sketchup::InputPoint.new
    end

    def activate
      Sketchup.vcb_label = '宽,高'
      Sketchup.set_status_text('选择第一个角点', SB_PROMPT)
      @drawn = false
    end

    def deactivate(view)
      view.invalidate if @drawn
    end

    def onCancel(reason, view)
      view.invalidate
      Sketchup.set_status_text('已取消', SB_PROMPT)
    end

    def onMouseMove(flags, x, y, view)
      if @state == :waiting_first
        @mouse_ip.pick(view, x, y)
      else
        @ip2.pick(view, x, y, @ip1)
        update_vcb(view)
      end
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      if @state == :waiting_first
        if @mouse_ip.valid?
          @ip1.copy!(@mouse_ip)
          @state = :waiting_second
          Sketchup.set_status_text('选择对角点（竖直矩形）', SB_PROMPT)
        end
      else
        if @ip2.valid? && @ip1.valid?
          create_face(view)
          Sketchup.active_model.tools.pop_tool
        end
      end
      view.invalidate
    end

    def draw(view)
      return unless @ip1.valid?
      @ip1.draw(view)
      if @state == :waiting_second && @ip2.valid?
        pts = preview_rect_points
        if pts
          view.set_color_from_line('blue')
          view.line_width = 2
          view.draw(GL_LINE_LOOP, pts)
          @drawn = true
        end
      end
    end

    private

    # 竖直矩形预览点：以ip1为基点，法向水平，面法向取相机右向
    def preview_rect_points
      return nil unless @ip1.valid? && @ip2.valid?
      p1 = @ip1.position
      p2 = @ip2.position
      # 将p2投影到与Z轴平行的竖直平面，保留y/z差异，禁止x轴高度（或相反）
      # 简化：在世界坐标系，竖直矩形平面取X常数平面（与相机无关）
      # 用p1.x 作为平面的X，p2在同一X平面内：
      plane_x = p1.x
      p2_proj = Geom::Point3d.new(plane_x, p2.y, p2.z)
      # 生成四角：以p1为一个角，与p2_proj对角
      Geom::BoundingBox.new.tap { |bb| bb.add(p1); bb.add(p2_proj) }
      y_min, y_max = [p1.y, p2_proj.y].minmax
      z_min, z_max = [p1.z, p2_proj.z].minmax
      bl = Geom::Point3d.new(plane_x, y_min, z_min)
      br = Geom::Point3d.new(plane_x, y_max, z_min)
      tr = Geom::Point3d.new(plane_x, y_max, z_max)
      tl = Geom::Point3d.new(plane_x, y_min, z_max)
      [bl, br, tr, tl]
    end

    def update_vcb(view)
      return unless @ip1.valid? && @ip2.valid?
      p1 = @ip1.position
      p2 = @ip2.position
      width = (p2.y - p1.y).abs
      height = (p2.z - p1.z).abs
      Sketchup.vcb_value = sprintf('%.3f, %.3f', width, height)
    end

    def create_face(view)
      pts = preview_rect_points
      return unless pts
      model = Sketchup.active_model
      model.start_operation('图片填充器: 创建竖直平面', true)
      face = model.active_entities.add_face(pts)
      if face && face.valid?
        # 应用材质与纹理映射
        ok, msg = ImageFiller::TextureMapper.apply_material_to_vertical_rect_face(face, @material, up_vector: Z_AXIS, side_policy: :camera_facing)
        UI.messagebox(msg) if !ok && msg
      else
        UI.messagebox('创建面失败')
      end
      model.commit_operation
    end
  end
end 