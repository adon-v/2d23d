# 为插件创建命名空间
module ExamplePlugins
  module StaircaseGenerator
    
    # 常量定义
    PLUGIN_TITLE = "楼梯生成器"
    MENU_ITEM_NAME = "楼梯管理器"
    
    # 存储工具栏实例和管理器的类变量
    @@toolbar = nil
    @@manager = nil
    
    # 注册文档打开/关闭回调
    def self.register_callbacks
      # 文档打开时初始化管理器
      Sketchup.active_model.add_observer(DocumentObserver.new)
      
      # 注册回调，确保文档切换时更新状态
      UI.add_context_menu_handler do |menu|
        init_manager_if_needed
      end
    end
    
    # 文档观察者类
    class DocumentObserver < Sketchup::ModelObserver
      def onNewModel(model)
        StaircaseGenerator.reset_manager
      end
      
      def onOpenModel(model)
        StaircaseGenerator.reset_manager
      end
      
      def onCloseModel(model)
        StaircaseGenerator.reset_manager
      end
    end
    
    # 初始化管理器（如果需要）
    def self.init_manager_if_needed
      # 检查当前文档是否已更改
      if @@manager && Sketchup.active_model != @@manager.model
        reset_manager
      end
      
      @@manager ||= StaircaseManager.new(Sketchup.active_model)
    end
    
    # 重置管理器
    def self.reset_manager
      @@manager = nil
    end
    
    # 楼梯参数类
    class StairParameters
      attr_accessor :name, :total_steps, :step_width, :step_height, :step_depth
      
      def initialize(name = "楼梯")
        @name = name
        @total_steps = 10    # 总台阶数
        @step_width = 100    # 台阶宽度(cm)
        @step_height = 15    # 台阶高度(cm)
        @step_depth = 30     # 台阶深度(cm)
      end
      
      # 转换为输入框数组
      def to_input_array
        [
          @name,
          @total_steps.to_s,
          @step_width.to_s,
          @step_height.to_s,
          @step_depth.to_s
        ]
      end
      
      # 从输入框数组更新参数
      def update_from_input(inputs)
        @name = inputs[0]
        @total_steps = inputs[1].to_i
        @step_width = inputs[2].to_f
        @step_height = inputs[3].to_f
        @step_depth = inputs[4].to_f
      end
      
      # 验证参数是否有效
      def valid?
        !@name.empty? &&
        @total_steps > 0 &&
        @step_width > 0 &&
        @step_height > 0 &&
        @step_depth > 0
      end
      
      # 转换为英寸（SketchUp内部单位）
      def to_inches
        {
          total_steps: @total_steps,
          step_width: @step_width / 2.54,
          step_height: @step_height / 2.54,
          step_depth: @step_depth / 2.54
        }
      end
      
      # 转换为哈希
      def to_hash
        {
          name: @name,
          total_steps: @total_steps,
          step_width: @step_width,
          step_height: @step_height,
          step_depth: @step_depth
        }
      end
      
      # 从哈希创建参数
      def self.from_hash(hash)
        params = new(hash[:name])
        params.total_steps = hash[:total_steps]
        params.step_width = hash[:step_width]
        params.step_height = hash[:step_height]
        params.step_depth = hash[:step_depth]
        params
      end
    end
    
    # 楼梯实例类
    class StairInstance
      attr_reader :id, :params
      attr_accessor :entity_id, :component_guid, :transform
      
      def initialize(params)
        @id = Time.now.to_i.to_s + rand(1000).to_s # 生成唯一ID
        @params = params
        @entity_id = nil # 存储SketchUp实体ID
        @component_guid = nil # 存储组件GUID
        @transform = nil # 存储变换信息
      end
      
      # 获取SketchUp实体
      def get_entity(model)
        if @entity_id
          entity = model.entities[@entity_id]
          return entity if entity && valid_entity?(entity)
        end
        
        # 如果实体ID失效，尝试通过组件GUID查找
        if @component_guid
          entity = find_entity_by_guid(model)
          return entity if entity && valid_entity?(entity)
        end
        
        nil
      end
      
      # 检查实体是否存在
      def exists?(model)
        !!get_entity(model)
      end
      
      # 高亮显示实体
      def highlight(model)
        entity = get_entity(model)
        if entity
          model.selection.clear
          model.selection.add(entity)
          model.active_view.zoom_extents
        else
          UI.messagebox("无法找到楼梯 '#{@params.name}' 的实体")
          puts "找不到实体: ID=#{@id}, 名称=#{@params.name}, 实体ID=#{@entity_id}, GUID=#{@component_guid}"
        end
      end
      
      # 更新实体引用
      def update_entity_reference(entity)
        @entity_id = entity.entityID
        @component_guid = entity.definition.guid
        @transform = entity.transformation # 保存变换信息
      end
      
      # 转换为哈希，用于持久化
      def to_hash
        transform_hash = @transform ? {
          origin: [@transform.origin.x, @transform.origin.y, @transform.origin.z],
          xaxis: [@transform.xaxis.x, @transform.xaxis.y, @transform.xaxis.z],
          yaxis: [@transform.yaxis.x, @transform.yaxis.y, @transform.yaxis.z],
          zaxis: [@transform.zaxis.x, @transform.zaxis.y, @transform.zaxis.z]
        } : nil
        
        {
          id: @id,
          params: @params.to_hash,
          entity_id: @entity_id,
          component_guid: @component_guid,
          transform: transform_hash
        }
      end
      
      # 从哈希创建实例
      def self.from_hash(hash)
        params = StairParameters.from_hash(hash[:params])
        instance = new(params)
        instance.instance_variable_set(:@id, hash[:id])
        instance.entity_id = hash[:entity_id]
        instance.component_guid = hash[:component_guid]
        
        # 恢复变换信息
        if hash[:transform]
          t = hash[:transform]
          origin = Geom::Point3d.new(t[:origin])
          xaxis = Geom::Vector3d.new(t[:xaxis])
          yaxis = Geom::Vector3d.new(t[:yaxis])
          zaxis = Geom::Vector3d.new(t[:zaxis])
          instance.transform = Geom::Transformation.new(origin, xaxis, yaxis)
        end
        
        instance
      end
      
      private
      
      # 验证实体是否为有效的楼梯组件
      def valid_entity?(entity)
        entity.is_a?(Sketchup::ComponentInstance) && 
        entity.definition.name.start_with?("楼梯_")
      end
      
      # 通过组件GUID查找实体
      def find_entity_by_guid(model)
        model.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance)
          return entity if entity.definition.guid == @component_guid && 
                          entity.definition.name.start_with?("楼梯_")
        end
        nil
      end
    end
    
    # 楼梯管理器 - 处理增删改查操作
    class StaircaseManager
      attr_reader :model
      
      def initialize(model)
        @model = model
        @instances = []
        load_from_model
      end
      
      # 创建新楼梯实例
      def create_instance(params, entity)
        instance = StairInstance.new(params)
        instance.update_entity_reference(entity)
        @instances << instance
        
        # 保存到模型
        save_to_model
        instance
      end
      
      # 更新楼梯实例
      def update_instance(instance)
        index = @instances.index { |inst| inst.id == instance.id }
        if index
          @instances[index] = instance
          save_to_model
        end
      end
      
      # 获取所有楼梯实例
      def all_instances
        cleanup_deleted_entities
        @instances
      end
      
      # 按ID查找楼梯实例
      def find_instance_by_id(id)
        @instances.find { |instance| instance.id == id }
      end
      
      # 按名称查找楼梯实例
      def find_instances_by_name(name)
        @instances.select { |instance| instance.params.name == name }
      end
      
      # 删除楼梯实例
      def delete_instance(id)
        @instances.reject! { |instance| instance.id == id }
        save_to_model
      end
      
      # 清理已删除的实体引用
      def cleanup_deleted_entities
        @instances.reject! { |instance| !instance.exists?(@model) }
      end
      
      # 保存数据到模型的属性字典
      def save_to_model
        return unless @model
        
        begin
          dict = @model.attribute_dictionary("StaircaseGenerator", true)
          instances_hash = @instances.map(&:to_hash)
          dict["instances"] = instances_hash.to_json
          
          puts "楼梯数据已保存: #{instances_hash.size} 个实例"
        rescue StandardError => e
          puts "保存楼梯数据时出错: #{e.message}"
          UI.messagebox("保存楼梯数据时出错: #{e.message}")
        end
      end
      
      # 从模型的属性字典加载数据
      def load_from_model
        return unless @model
        
        begin
          dict = @model.attribute_dictionary("StaircaseGenerator", false)
          return unless dict && dict["instances"]
          
          instances_hash = JSON.parse(dict["instances"], symbolize_names: true)
          @instances = instances_hash.map { |hash| StairInstance.from_hash(hash) }
          
          cleanup_deleted_entities
          
          puts "楼梯数据已加载: #{@instances.size} 个实例"
        rescue StandardError => e
          puts "加载楼梯数据时出错: #{e.message}"
          @instances = []
          UI.messagebox("加载楼梯数据时出错: #{e.message}")
        end
      end
    end
    
    # 创建命令
    def self.create_commands
      manager = init_manager_if_needed
      commands = {}
      
      # 创建楼梯命令
      commands[:create] = UI::Command.new("创建楼梯") {
        create_staircase(manager)
      }
      commands[:create].tooltip = "创建新楼梯"
      
      # 编辑楼梯命令
      commands[:edit] = UI::Command.new("编辑楼梯") {
        edit_staircase(manager)
      }
      commands[:edit].tooltip = "编辑现有楼梯"
      
      # 删除楼梯命令
      commands[:delete] = UI::Command.new("删除楼梯") {
        delete_staircase(manager)
      }
      commands[:delete].tooltip = "删除现有楼梯"
      
      # 查找楼梯命令
      commands[:search] = UI::Command.new("查找楼梯") {
        search_staircase(manager)
      }
      commands[:search].tooltip = "按名称查找楼梯"
      
      # 列出所有楼梯命令
      commands[:list] = UI::Command.new("列出所有楼梯") {
        list_staircases(manager)
      }
      commands[:list].tooltip = "显示所有已创建的楼梯"
      
      commands
    end
    
    # 显示主菜单（工具栏）
    def self.show_main_menu
      if @@toolbar.nil?
        commands = create_commands
        
        # 创建工具栏
        @@toolbar = UI::Toolbar.new(PLUGIN_TITLE)
        
        # 添加命令到工具栏
        commands.each do |key, command|
          @@toolbar.add_item(command)
        end
      end
      
      # 显示工具栏
      @@toolbar.show
    end
    
    # 创建楼梯
    def self.create_staircase(manager)
      params = StairParameters.new
      
      input_labels = [
        "楼梯名称:",
        "总台阶数 (级):",
        "台阶宽度 (厘米):",
        "台阶高度 (厘米):",
        "台阶深度 (厘米):"
      ]
      
      inputs = UI.inputbox(
        input_labels,
        params.to_input_array,
        "创建楼梯"
      )
      
      if inputs
        params.update_from_input(inputs)
        
        if params.valid?
          model = Sketchup.active_model
          staircase = Staircase.new(params)
          
          model.start_operation("创建楼梯", true)
          entity = staircase.generate(model)
          model.commit_operation
          
          if entity
            instance = manager.create_instance(params, entity)
            puts "创建新楼梯: ID=#{instance.id}, 名称=#{params.name}, 实体ID=#{instance.entity_id}, GUID=#{instance.component_guid}"
            UI.messagebox("楼梯 '#{params.name}' 生成成功！")
          else
            UI.messagebox("生成楼梯失败")
          end
        else
          UI.messagebox("请输入有效的楼梯参数")
        end
      else
        puts "用户取消了操作"
      end
    end
    
    # 楼梯生成器主类
    class Staircase
      def initialize(params)
        @params = params
      end
      
      # 生成楼梯并返回创建的实体
      def generate(model)
        entities = model.active_entities
        
        begin
          # 为每个楼梯创建唯一的组件定义
          definition_name = "楼梯_#{Time.now.to_i}_#{rand(1000)}"
          definition = model.definitions.add(definition_name)
          
          stair_entities = definition.entities
          
          params_in = @params.to_inches
          current_x = 0.0
          current_z = 0.0
          
          # 生成每个台阶
          params_in[:total_steps].times do |i|
            # 创建台阶的四个点
            point1 = Geom::Point3d.new(current_x, 0, current_z)
            point2 = Geom::Point3d.new(current_x + params_in[:step_depth], 0, current_z)
            point3 = Geom::Point3d.new(current_x + params_in[:step_depth], params_in[:step_width], current_z)
            point4 = Geom::Point3d.new(current_x, params_in[:step_width], current_z)
            
            # 创建台阶面
            face = stair_entities.add_face(point1, point2, point3, point4)
            face.material = "White"
            
            # 创建立板(除了第一个台阶)
            unless i == 0
              point5 = Geom::Point3d.new(current_x, 0, current_z - params_in[:step_height])
              point6 = Geom::Point3d.new(current_x, params_in[:step_width], current_z - params_in[:step_height])
              riser_face = stair_entities.add_face(point1, point4, point6, point5)
              riser_face.material = "Gray"
            end
            
            # 更新下一个台阶的位置
            current_x += params_in[:step_depth]
            current_z += params_in[:step_height]
          end
          
          # 在原点插入楼梯组件
          transform = Geom::Transformation.new
          instance = entities.add_instance(definition, transform)
          
          # 选择新创建的楼梯
          model.selection.clear
          model.selection.add(instance)
          
          # 缩放视图以显示楼梯
          model.active_view.zoom_extents
          
          return instance
        rescue StandardError => e
          UI.messagebox("生成楼梯时出错: #{e.message}")
          puts "Error in generate: #{e.message}"
          puts e.backtrace.join("\n")
          return nil
        end
      end
    end
    
    # 编辑楼梯
    def self.edit_staircase(manager)
      model = Sketchup.active_model
      manager.cleanup_deleted_entities
      
      instances = manager.all_instances
      
      if instances.empty?
        UI.messagebox("没有可编辑的楼梯")
        return
      end
      
      names = instances.map { |inst| inst.params.name }
      
      list_str = "选择要编辑的楼梯:\n\n"
      names.each_with_index do |name, index|
        list_str += "#{index+1}. #{name}\n"
      end
      list_str += "\n请输入序号 (1-#{names.size}):"
      
      input = UI.inputbox(
        [list_str],
        ["1"],
        "编辑楼梯"
      )
      
      if input
        choice = input[0].to_i - 1
        
        if choice >= 0 && choice < instances.size
          instance = instances[choice]
          entity = instance.get_entity(model)
          
          if entity
            # 保存当前实体的变换
            current_transform = entity.transformation
            
            # 高亮显示
            model.selection.clear
            model.selection.add(entity)
            model.active_view.zoom_extents
            
            params = instance.params
            
            input_labels = [
              "楼梯名称:",
              "总台阶数 (级):",
              "台阶宽度 (厘米):",
              "台阶高度 (厘米):",
              "台阶深度 (厘米):"
            ]
            
            inputs = UI.inputbox(
              input_labels,
              params.to_input_array,
              "编辑楼梯 - #{params.name}"
            )
            
            if inputs
              old_name = params.name
              params.update_from_input(inputs)
              
              if params.valid?
                model.start_operation("更新楼梯", true)
                
                # 创建一个新的组件定义
                new_definition_name = "楼梯_#{Time.now.to_i}_#{rand(1000)}"
                new_definition = model.definitions.add(new_definition_name)
                
                # 在新定义中生成楼梯
                stair_entities = new_definition.entities
                params_in = params.to_inches
                current_x = 0.0
                current_z = 0.0
                
                params_in[:total_steps].times do |i|
                  # 创建台阶的四个点
                  point1 = Geom::Point3d.new(current_x, 0, current_z)
                  point2 = Geom::Point3d.new(current_x + params_in[:step_depth], 0, current_z)
                  point3 = Geom::Point3d.new(current_x + params_in[:step_depth], params_in[:step_width], current_z)
                  point4 = Geom::Point3d.new(current_x, params_in[:step_width], current_z)
                  
                  # 创建台阶面
                  face = stair_entities.add_face(point1, point2, point3, point4)
                  face.material = "White"
                  
                  # 创建立板(除了第一个台阶)
                  unless i == 0
                    point5 = Geom::Point3d.new(current_x, 0, current_z - params_in[:step_height])
                    point6 = Geom::Point3d.new(current_x, params_in[:step_width], current_z - params_in[:step_height])
                    riser_face = stair_entities.add_face(point1, point4, point6, point5)
                    riser_face.material = "Gray"
                  end
                  
                  # 更新下一个台阶的位置
                  current_x += params_in[:step_depth]
                  current_z += params_in[:step_height]
                end
                
                # 从父实体中删除旧的实例
                parent = entity.parent
                parent.entities.erase_entities(entity)
                
                # 插入新的组件实例，并应用保存的变换
                new_instance = parent.entities.add_instance(new_definition, current_transform)
                
                # 更新实例的引用
                instance.update_entity_reference(new_instance)
                manager.update_instance(instance)
                
                # 选择新实例
                model.selection.clear
                model.selection.add(new_instance)
                
                model.commit_operation
                
                puts "更新楼梯: ID=#{instance.id}, 名称=#{params.name}, 新实体ID=#{instance.entity_id}, 新GUID=#{instance.component_guid}"
                UI.messagebox("楼梯 '#{old_name}' 已更新为 '#{params.name}'！")
              else
                UI.messagebox("请输入有效的楼梯参数")
              end
            else
              puts "用户取消了操作"
            end
          else
            UI.messagebox("无法找到所选楼梯的实体")
          end
        else
          UI.messagebox("无效的选择")
        end
      end
    end
    
    # 删除楼梯
    def self.delete_staircase(manager)
      model = Sketchup.active_model
      manager.cleanup_deleted_entities
      
      instances = manager.all_instances
      
      if instances.empty?
        UI.messagebox("没有可删除的楼梯")
        return
      end
      
      names = instances.map { |inst| inst.params.name }
      
      list_str = "选择要删除的楼梯:\n\n"
      names.each_with_index do |name, index|
        list_str += "#{index+1}. #{name}\n"
      end
      list_str += "\n请输入序号 (1-#{names.size}):"
      
      input = UI.inputbox(
        [list_str],
        ["1"],
        "删除楼梯"
      )
      
      if input
        choice = input[0].to_i - 1
        
        if choice >= 0 && choice < instances.size
          instance = instances[choice]
          instance.highlight(model)
          
          confirm = UI.messagebox("确定要删除楼梯 '#{instance.params.name}' 吗？", MB_YESNO)
          
          if confirm == 6
            model.start_operation("删除楼梯", true)
            
            entity = instance.get_entity(model)
            if entity
              model.entities.erase_entities(entity)
              puts "删除楼梯实体: ID=#{instance.id}, 名称=#{instance.params.name}, 实体ID=#{instance.entity_id}"
            end
            
            manager.delete_instance(instance.id)
            UI.messagebox("楼梯 '#{instance.params.name}' 已成功删除！")
            
            model.commit_operation
          end
        else
          UI.messagebox("无效的选择")
        end
      end
    end
    
    # 查找楼梯
    def self.search_staircase(manager)
      model = Sketchup.active_model
      manager.cleanup_deleted_entities
      
      search_name = UI.inputbox(
        ["楼梯名称:"],
        [""],
        "查找楼梯"
      )
      
      if search_name && !search_name[0].empty?
        matches = manager.find_instances_by_name(search_name[0])
        
        if matches.empty?
          UI.messagebox("未找到名为 '#{search_name[0]}' 的楼梯")
        else
          message = "找到 #{matches.size} 个匹配的楼梯:\n\n"
          matches.each_with_index do |match, index|
            params = match.params
            message += "#{index+1}. #{params.name}\n"
            message += "   台阶数: #{params.total_steps} 级\n"
            message += "   宽度: #{params.step_width} 厘米\n"
            message += "   高度: #{params.step_height} 厘米\n"
            message += "   深度: #{params.step_depth} 厘米\n\n"
          end
          
          if matches.size > 1
            message += "请输入序号 (1-#{matches.size}) 选择要查看的楼梯，或点击取消:"
            choice = UI.inputbox(
              [message],
              ["1"],
              "选择楼梯"
            )
            
            if choice
              index = choice[0].to_i - 1
              if index >= 0 && index < matches.size
                matches[index].highlight(model)
                UI.messagebox("已选择楼梯 '#{matches[index].params.name}'")
              end
            end
          else
            matches[0].highlight(model)
            UI.messagebox("已选择楼梯 '#{matches[0].params.name}'")
          end
        end
      end
    end
    
    # 列出所有楼梯
    def self.list_staircases(manager)
      model = Sketchup.active_model
      manager.cleanup_deleted_entities
      
      instances = manager.all_instances
      
      if instances.empty?
        UI.messagebox("没有已创建的楼梯")
        return
      end
      
      message = "已创建的楼梯列表:\n\n"
      instances.each_with_index do |instance, index|
        params = instance.params
        message += "#{index+1}. #{params.name}\n"
        message += "   台阶数: #{params.total_steps} 级\n"
        message += "   宽度: #{params.step_width} 厘米\n"
        message += "   高度: #{params.step_height} 厘米\n"
        message += "   深度: #{params.step_depth} 厘米\n\n"
      end
      
      message += "请输入序号 (1-#{instances.size}) 选择要查看的楼梯，或点击取消:"
      choice = UI.inputbox(
        [message],
        ["1"],
        "选择楼梯"
      )
      
      if choice
        index = choice[0].to_i - 1
        if index >= 0 && index < instances.size
          instances[index].highlight(model)
          UI.messagebox("已选择楼梯 '#{instances[index].params.name}'")
        end
      end
    end
    
    # 初始化插件
    def self.initialize_plugin
      register_callbacks
      
      unless file_loaded?(__FILE__)
        menu = UI.menu("Plugins")
        menu.add_item(MENU_ITEM_NAME) { self.show_main_menu }
        file_loaded(__FILE__)
      end
    end
    
    # 初始化插件
    initialize_plugin
    
  end # module StaircaseGenerator
end # module ExamplePlugins