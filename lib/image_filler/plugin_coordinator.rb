# 主协调模块：入口协调工作流与菜单注册
module ImageFiller
  module PluginCoordinator
    MENU_NAME = '图片填充器'

    def self.start
      image_path = ImageFiller::UserInput.pick_image_path
      return unless image_path

      material, err = ImageFiller::MaterialManager.find_or_create_material(image_path)
      unless material
        UI.messagebox(err || '材质创建失败')
        return
      end

      mode = ImageFiller::UserInput.pick_mode
      return unless mode

      case mode
      when :create
        tool = ImageFiller::PlaneCreationTool.new(material)
        Sketchup.active_model.tools.push_tool(tool)
      when :apply
        face, msg = ImageFiller::UserInput.pick_selected_vertical_rect_face
        if face.nil?
          UI.messagebox(msg)
          return
        end
        model = Sketchup.active_model
        model.start_operation('图片填充器: 应用到已选平面', true)
        ok, emsg = ImageFiller::TextureMapper.apply_material_to_vertical_rect_face(face, material, up_vector: Z_AXIS, side_policy: :camera_facing)
        model.commit_operation
        if ok
          UI.messagebox('应用成功')
        else
          UI.messagebox(emsg || '应用失败')
        end
      end
    end

    def self.register_menu
      begin
        menu = UI.menu('Extensions')
        menu.add_item("#{MENU_NAME} - 开始创建...") do
          ImageFiller::PluginCoordinator.start
        end
      rescue Exception => e
        puts "注册菜单失败: #{Utils.ensure_utf8(e.message)}"
      end
    end
  end
end 