# 集成测试：测试新的胶带系统与zone_builder的集成
module TapeBuilderIntegrationTest
  def self.test_zone_builder_integration
    puts "=== 开始测试新胶带系统与zone_builder的集成 ==="
    
    # 模拟zones_data（使用实际的2D点格式）
    test_zones_data = [
      {
        "id" => "a812ce55-20e7-4118-9866-df72ffc378be",
        "name" => "测试区域1",
        "shape" => {
          "type" => "polygon",
          "points" => [
            [2766.9388854828667, 1334.6262438347812],
            [3408.2163496597022, 1334.6262438347812],
            [3408.2163496597022, 1747.2830581269764],
            [2766.9388854828667, 1747.2830581269764]
          ]
        },
        "description" => "测试区域1描述",
        "constraints" => "无约束",
        "zone_entrances" => [],
        "objects" => [],
        "zones" => []
      },
      {
        "id" => "b923df66-31f8-5229-0977-eg83ggd48987",
        "name" => "测试区域2",
        "shape" => {
          "type" => "polygon",
          "points" => [
            [1000, 1000],
            [1500, 1000],
            [1500, 1500],
            [1000, 1500]
          ]
        },
        "description" => "测试区域2描述",
        "constraints" => "无约束",
        "zone_entrances" => [],
        "objects" => [],
        "zones" => []
      }
    ]
    
    # 获取当前模型
    model = Sketchup.active_model
    parent_group = model.active_entities.add_group
    parent_group.name = "胶带集成测试组"
    
    puts "测试数据准备完成，区域数量: #{test_zones_data.size}"
    
    # 测试内部区域胶带生成
    begin
      puts "测试内部区域胶带生成..."
      ZoneBuilder.generate_zone_tapes_new(test_zones_data, parent_group)
      puts "内部区域胶带生成测试完成"
    rescue => e
      puts "内部区域胶带生成测试失败: #{e.message}"
      puts e.backtrace.join("\n")
    end
    
    # 测试外部区域胶带生成
    begin
      puts "测试外部区域胶带生成..."
      ZoneBuilder.generate_outdoor_zone_tapes_new(test_zones_data, parent_group)
      puts "外部区域胶带生成测试完成"
    rescue => e
      puts "外部区域胶带生成测试失败: #{e.message}"
      puts e.backtrace.join("\n")
    end
    
    puts "=== 集成测试完成 ==="
  end
  
  def self.run_test
    test_zone_builder_integration
  end
end

# 如果直接运行此文件，执行测试
if __FILE__ == $0
  TapeBuilderIntegrationTest.run_test
end 