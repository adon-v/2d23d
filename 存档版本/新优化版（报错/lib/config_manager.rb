# 配置管理模块：管理各个功能的开关和参数
module ConfigManager
  @config = {
    # 功能模块开关
    features: {
      wall_builder: true,
      door_builder: true,
      window_builder: true,
      zone_builder: true,
      structure_builder: true,
      flow_builder: true,
      equipment_builder: true,
      tape_builder: true
    },
    
    # 错误处理配置
    error_handling: {
      enabled: true,
      continue_on_error: true,
      log_errors: true
    }
  }
  
  # 检查功能是否启用
  def self.feature_enabled?(feature_name)
    @config[:features][feature_name.to_sym] == true
  end
  
  # 启用功能
  def self.enable_feature(feature_name)
    @config[:features][feature_name.to_sym] = true
  end
  
  # 禁用功能
  def self.disable_feature(feature_name)
    @config[:features][feature_name.to_sym] = false
  end
  
  # 获取所有启用的功能
  def self.get_enabled_features
    @config[:features].select { |name, enabled| enabled }.keys
  end
  
  # 获取配置
  def self.get(key)
    @config[key.to_sym]
  end
  
  # 设置配置
  def self.set(key, value)
    @config[key.to_sym] = value
  end
end
