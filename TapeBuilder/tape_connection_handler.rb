require_relative 'tape_constants'

module TapeBuilder
  class TapeConnectionHandler
    # 处理胶带连接
    def self.handle_tape_connections(tape_face, parent_group)
      begin
        # 检查面是否有效
        if !tape_face || !tape_face.valid?
          puts "警告：无效的胶带面，跳过连接处理"
          return
        end
        
        puts "调试：处理胶带连接"
        
        # 获取胶带的边
        edges = tape_face.edges
        
        # 检查每条边是否与其他胶带相交
        edges.each do |edge|
          # 如果边连接了多于2个面，可能是与其他胶带相交的地方
          if edge.faces.length > 2
            puts "调试：发现多面连接边，尝试修复"
            
            # 获取边的端点
            start_point = edge.start.position
            end_point = edge.end.position
            
            # 获取所有连接到这条边的面
            connected_faces = edge.faces
            
            # 如果有多于2个面，尝试修复连接
            if connected_faces.length > 2
              puts "调试：边连接了#{connected_faces.length}个面，尝试清理"
              
              # 找出哪些面是胶带面（通过材质或其他特征）
              tape_faces = connected_faces.select { |f| 
                f.material && f.material.name == "Tape" 
              }
              
              puts "调试：识别出#{tape_faces.length}个胶带面"
              
              # 如果有多个胶带面，尝试合并它们
              if tape_faces.length > 1
                begin
                  puts "调试：尝试调整胶带连接处"
                  
                  # 这里可以根据需要实现更复杂的连接处理逻辑
                  # 例如，可以尝试将两个胶带面的顶点对齐，或者创建一个平滑的过渡
                  
                  # 简单处理：确保所有胶带面的材质一致
                  tape_material = Sketchup.active_model.materials["Tape"]
                  if tape_material
                    puts "调试：为#{tape_faces.length}个胶带面应用统一材质"
                    tape_faces.each do |face|
                      if face && face.valid?
                        face.material = tape_material
                        face.back_material = tape_material
                        puts "调试：面#{face.entityID}材质应用完成"
                      else
                        puts "警告：跳过无效面 #{face ? face.entityID : 'nil'}"
                      end
                    end
                    
                    # 强制刷新显示
                    Sketchup.active_model.active_view.invalidate
                  else
                    puts "警告：未找到胶带材质，尝试重新创建"
                    # 尝试重新创建材质
                    begin
                      tape_material = Sketchup.active_model.materials.add("Tape")
                      color = Sketchup::Color.new(TapeBuilder::TAPE_COLOR[0], TapeBuilder::TAPE_COLOR[1], TapeBuilder::TAPE_COLOR[2])
                      tape_material.color = color
                      tape_material.alpha = 1.0
                      tape_material.use_color = true
                      
                      # 重新应用材质
                      tape_faces.each do |face|
                        if face && face.valid?
                          face.material = tape_material
                          face.back_material = tape_material
                        end
                      end
                      
                      puts "调试：重新创建并应用材质成功"
                      Sketchup.active_model.active_view.invalidate
                    rescue => e
                      puts "重新创建材质失败: #{e.message}"
                    end
                  end
                rescue => e
                  puts "调整胶带连接处时出错: #{e.message}"
                end
              end
            end
          end
        end
      rescue => e
        puts "处理胶带连接时出错: #{e.message}"
        puts "调试：错误堆栈: #{e.backtrace.join("\n")}"
      end
    end
  end
end 