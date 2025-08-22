# 用户输入模块：处理图片选择、模式选择与选择集验证
module ImageFiller
  module UserInput
    SUPPORTED_IMAGE_EXTS = %w[.jpg .jpeg .png .bmp .tif .tiff .webp]

    # 选择图片路径，取消返回nil
    def self.pick_image_path
      filters = "图像文件|*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.webp||"
      path = UI.openpanel("选择要填充的图片", nil, filters)
      return nil if path.nil? || path.empty?
      ext = File.extname(path).downcase
      unless SUPPORTED_IMAGE_EXTS.include?(ext)
        UI.messagebox("不支持的图片格式: #{ext}\n支持: #{SUPPORTED_IMAGE_EXTS.join(', ')}")
        return nil
      end
      path
    end

    # 模式选择：返回 :create, :apply 或 nil(取消)
    def self.pick_mode
      # 使用Yes/No/Cancel实现两选一 + 取消
      # 是=创建新平面，否=应用于已选平面
      result = UI.messagebox(
        "请选择操作模式:\n是: 创建新平面\n否: 应用于已选平面\n取消: 终止",
        MB_YESNOCANCEL
      )
      case result
      when IDYES
        :create
      when IDNO
        :apply
      else
        nil
      end
    end

    # 在“应用”模式下获取并验证单个矩形竖直平面
    # 成功返回 [face, message=nil]；失败返回 [nil, 错误信息]
    def self.pick_selected_vertical_rect_face
      model = Sketchup.active_model
      sel = model.selection
      if sel.length != 1 || !sel.first.is_a?(Sketchup::Face)
        return [nil, "请先选择一个单独的面，然后再执行此操作"]
      end
      face = sel.first
      unless face.valid?
        return [nil, "所选面无效"]
      end
      # 检查是否为矩形：边界外环4边
      outer_edges = face.outer_loop.edges
      if outer_edges.length != 4
        return [nil, "当前仅支持矩形面（4条外边）"]
      end
      # 允许选择任意矩形面（含XY平面），去除竖直性检查
      # normal = face.normal
      # if normal.z.abs > 1e-6
      #   return [nil, "请先选择一个竖直的矩形面（法向量水平）"]
      # end
      [face, nil]
    end
  end
end 