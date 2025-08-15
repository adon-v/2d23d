# 核心模块：处理版本检查、编码设置和环境信息记录
module Core
  # 检查SketchUp版本兼容性
  def self.check_sketchup_version
    min_version = "24.0.0"
    current_version = Sketchup.version
    
    if Gem::Version.new(current_version) < Gem::Version.new(min_version)
      UI.messagebox("警告: 此插件设计用于SketchUp 25.0及以上版本。\n当前版本: #{current_version}")
    end
  end
  
  # 设置编码
  def self.setup_encoding
    if RUBY_VERSION >= "2.0"
      Encoding.default_external = Encoding::UTF_8
      Encoding.default_internal = Encoding::UTF_8
    end
    
    $KCODE = 'UTF-8' if defined?($KCODE)
  end
  
  # 记录环境信息用于调试
  def self.log_environment_info
    puts "=== FactoryImporter 插件环境信息 ==="
    puts "SketchUp版本: #{Sketchup.version}"
    puts "操作系统: #{RUBY_PLATFORM}"
    puts "Ruby版本: #{RUBY_VERSION}"
    puts "当前编码: #{Encoding.default_external}"
    puts "==================================="
  end
end 