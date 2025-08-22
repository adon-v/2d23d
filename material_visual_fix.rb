#!/usr/bin/env ruby
# 材质视觉效果修复工具

# 检查并修复材质视觉效果问题
def check_and_fix_material_visual
  model = Sketchup.active_model
  selection = model.selection
  
  if selection.empty?
    UI.messagebox("请先选择要检查的对象")
    return
  end
  
  analysis_result = "=== 材质视觉效果检查 ===\n\n"
  fix_count = 0
  
  selection.each_with_index do |entity, index|
    analysis_result += "对象 #{index + 1}:\n"
    analysis_result += "  类型: #{entity.class.name}\n"
    analysis_result += "  名称: #{entity.name rescue '无名称'}\n"
    
    if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      # 检查组内面的材质状态
      faces = get_all_faces_recursive(entity)
      analysis_result += "  组内面数量: #{faces.length}\n"
      
      faces.each_with_index do |face, face_index|
        if face_index < 5  # 只显示前5个面
          face_material = face.material
          analysis_result += "    面 #{face_index + 1}: #{face_material ? face_material.name : '无材质'}\n"
          
          # 如果面没有材质，尝试应用默认材质
          if !face_material
            begin
              default_material = model.materials.add("默认材质_#{Time.now.to_i}")
              default_material.color = Sketchup::Color.new(200, 200, 200)
              face.material = default_material
              face.back_material = default_material
              fix_count += 1
              analysis_result += "      ✓ 已应用默认材质\n"
            rescue => e
              analysis_result += "      ✗ 应用材质失败: #{e.message}\n"
            end
          end
        end
      end
      
      if faces.length > 5
        analysis_result += "    ... 还有 #{faces.length - 5} 个面\n"
      end
    else
      # 检查单个实体的材质
      if entity.respond_to?(:material)
        material = entity.material
        analysis_result += "  材质: #{material ? material.name : '无材质'}\n"
        
        if !material
          begin
            default_material = model.materials.add("默认材质_#{Time.now.to_i}")
            default_material.color = Sketchup::Color.new(200, 200, 200)
            entity.material = default_material
            fix_count += 1
            analysis_result += "  ✓ 已应用默认材质\n"
          rescue => e
            analysis_result += "  ✗ 应用材质失败: #{e.message}\n"
          end
        end
      end
    end
    
    analysis_result += "\n"
  end
  
  # 强制刷新视图
  model.active_view.invalidate
  
  analysis_result += "=== 修复结果 ===\n"
  analysis_result += "修复了 #{fix_count} 个无材质的实体\n"
  
  if fix_count > 0
    analysis_result += "✅ 已应用默认材质，请检查视觉效果\n"
  else
    analysis_result += "ℹ️ 所有实体都有材质，问题可能在其他地方\n"
  end
  
  UI.messagebox(analysis_result)
end

# 递归获取所有面
def get_all_faces_recursive(group)
  faces = []
  
  group.entities.each do |entity|
    if entity.is_a?(Sketchup::Face)
      faces << entity
    elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      faces.concat(get_all_faces_recursive(entity))
    end
  end
  
  faces
end

# 强制应用材质到所有面
def force_apply_to_all_faces
  model = Sketchup.active_model
  selection = model.selection
  
  if selection.empty?
    UI.messagebox("请先选择对象")
    return
  end
  
  # 创建明显的测试材质
  test_material = model.materials.add("强制测试材质_#{Time.now.to_i}")
  test_material.color = Sketchup::Color.new(0, 255, 0)  # 鲜艳的绿色
  
  total_faces = 0
  success_faces = 0
  
  selection.each do |entity|
    if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      faces = get_all_faces_recursive(entity)
      total_faces += faces.length
      
      faces.each do |face|
        begin
          face.material = test_material
          face.back_material = test_material
          success_faces += 1
        rescue => e
          puts "应用材质到面失败: #{e.message}"
        end
      end
    elsif entity.is_a?(Sketchup::Face)
      total_faces += 1
      begin
        entity.material = test_material
        entity.back_material = test_material
        success_faces += 1
      rescue => e
        puts "应用材质到面失败: #{e.message}"
      end
    end
  end
  
  # 强制刷新视图
  model.active_view.invalidate
  
  result = "强制应用材质结果:\n\n"
  result += "总面数: #{total_faces}\n"
  result += "成功应用: #{success_faces}\n"
  result += "材质: #{test_material.name} (鲜艳绿色)\n\n"
  
  if success_faces > 0
    result += "✅ 如果看到绿色，说明材质应用成功！"
  else
    result += "❌ 没有成功应用材质"
  end
  
  UI.messagebox(result)
end

# 检查视图设置
def check_view_settings
  model = Sketchup.active_model
  view = model.active_view
  
  result = "视图设置检查:\n\n"
  result += "渲染模式: #{view.rendering_options['DisplayMode']}\n"
  result += "显示材质: #{view.rendering_options['DisplayMaterials']}\n"
  result += "显示纹理: #{view.rendering_options['DisplayTextures']}\n"
  result += "显示边线: #{view.rendering_options['DisplayEdges']}\n"
  result += "显示面: #{view.rendering_options['DisplayFaces']}\n"
  
  # 检查是否有问题
  issues = []
  if !view.rendering_options['DisplayMaterials']
    issues << "材质显示被关闭"
  end
  if !view.rendering_options['DisplayFaces']
    issues << "面显示被关闭"
  end
  
  if issues.empty?
    result += "\n✅ 视图设置正常"
  else
    result += "\n❌ 发现以下问题:\n"
    issues.each { |issue| result += "  - #{issue}\n" }
    result += "\n建议启用材质和面显示"
  end
  
  UI.messagebox(result)
end

# 创建菜单
def create_material_fix_menu
  menu = UI.menu("Extensions").add_submenu("材质视觉效果修复")
  
  menu.add_item(UI::Command.new("检查并修复材质") { check_and_fix_material_visual })
  menu.add_item(UI::Command.new("强制应用绿色测试") { force_apply_to_all_faces })
  menu.add_item(UI::Command.new("检查视图设置") { check_view_settings })
  
  puts "材质视觉效果修复菜单创建成功"
end

# 初始化
create_material_fix_menu
puts "材质视觉效果修复工具加载完成" 