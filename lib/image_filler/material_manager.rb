# 材质管理模块：封装基于图片的材质创建与复用
module ImageFiller
  module MaterialManager
    MATERIAL_TAG = 'ImageFiller::Material'

    # 基于图片路径创建或复用材质
    # 返回 [material, error_message]
    def self.find_or_create_material(image_path)
      begin
        model = Sketchup.active_model
        mats = model.materials
        base_name = File.basename(image_path)
        # 先尝试通过自定义属性匹配
        mats.each do |m|
          next unless m.respond_to?(:get_attribute)
          if m.get_attribute(MATERIAL_TAG, 'image_path') == image_path
            return [m, nil]
          end
        end
        # 未命中，则新建
        name = mats.unique_name("IMG_#{base_name}")
        material = mats.add(name)
        material.texture = image_path
        # 记录路径方便复用
        material.set_attribute(MATERIAL_TAG, 'image_path', image_path)
        [material, nil]
      rescue Exception => e
        [nil, "创建材质失败: #{Utils.ensure_utf8(e.message)}"]
      end
    end
  end
end 