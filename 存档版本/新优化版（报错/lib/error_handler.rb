# 错误处理模块：提供统一的错误处理和恢复机制
module ErrorHandler
  @error_log = []
  @recovery_strategies = {}
  
  # 错误级别
  ERROR_LEVELS = {
    critical: 0,    # 严重错误，需要停止整个操作
    error: 1,       # 一般错误，影响当前功能
    warning: 2,     # 警告，不影响功能但需要注意
    info: 3         # 信息，仅用于记录
  }
  
  # 注册错误恢复策略
  def self.register_recovery_strategy(error_type, strategy)
    @recovery_strategies[error_type] = strategy
  end
  
  # 安全执行代码块
  def self.safe_execute(operation_name, error_level = :error, &block)
    begin
      result = block.call
      log_message("✅ #{operation_name} 执行成功", :info)
      { success: true, result: result, error: nil }
    rescue => e
      error_info = {
        operation: operation_name,
        error: e,
        message: Utils.ensure_utf8(e.message),
        backtrace: e.backtrace&.first(5),
        level: error_level,
        timestamp: Time.now
      }
      
      log_error(error_info)
      
      # 尝试恢复
      recovery_result = attempt_recovery(error_info)
      
      { 
        success: false, 
        result: nil, 
        error: error_info,
        recovery_success: recovery_result[:success],
        recovery_message: recovery_result[:message]
      }
    end
  end
  
  # 模块安全执行
  def self.module_safe_execute(module_name, method_name, *args, error_level = :error)
    safe_execute("#{module_name}.#{method_name}", error_level) do
      case module_name
      when :wall_builder
        WallBuilder.send(method_name, *args)
      when :door_builder
        DoorBuilder.send(method_name, *args)
      when :window_builder
        WindowBuilder.send(method_name, *args)
      when :zone_builder
        ZoneBuilder.send(method_name, *args)
      when :structure_builder
        StructureBuilder.send(method_name, *args)
      when :flow_builder
        FlowBuilder.send(method_name, *args)
      when :equipment_builder
        EquipmentBuilder.send(method_name, *args)
      when :tape_builder
        TapeBuilder.send(method_name, *args)
      else
        raise "未知模块: #{module_name}"
      end
    end
  end
  
  # 记录错误
  def self.log_error(error_info)
    @error_log << error_info
    
    # 根据错误级别输出不同信息
    case error_info[:level]
    when :critical
      puts "🚨 严重错误: #{error_info[:operation]} - #{error_info[:message]}"
    when :error
      puts "❌ 错误: #{error_info[:operation]} - #{error_info[:message]}"
    when :warning
      puts "⚠️  警告: #{error_info[:operation]} - #{error_info[:message]}"
    when :info
      puts "ℹ️  信息: #{error_info[:operation]} - #{error_info[:message]}"
    end
    
    # 输出堆栈跟踪（仅对错误和严重错误）
    if [:critical, :error].include?(error_info[:level]) && error_info[:backtrace]
      puts "堆栈跟踪:"
      error_info[:backtrace].each { |line| puts "  #{line}" }
    end
  end
  
  # 记录消息
  def self.log_message(message, level = :info)
    log_error({
      operation: "日志记录",
      error: nil,
      message: message,
      backtrace: nil,
      level: level,
      timestamp: Time.now
    })
  end
  
  # 尝试恢复
  def self.attempt_recovery(error_info)
    error_type = classify_error(error_info[:error])
    strategy = @recovery_strategies[error_type]
    
    if strategy
      begin
        result = strategy.call(error_info)
        { success: true, message: "恢复策略执行成功: #{result}" }
      rescue => e
        { success: false, message: "恢复策略执行失败: #{e.message}" }
      end
    else
      { success: false, message: "无可用恢复策略" }
    end
  end
  
  # 错误分类
  def self.classify_error(error)
    case error
    when NoMethodError
      :method_not_found
    when ArgumentError
      :invalid_argument
    when TypeError
      :type_error
    when RuntimeError
      :runtime_error
    when StandardError
      :standard_error
    else
      :unknown_error
    end
  end
  
  # 获取错误日志
  def self.get_error_log
    @error_log.dup
  end
  
  # 清除错误日志
  def self.clear_error_log
    @error_log.clear
  end
  
  # 获取错误统计
  def self.get_error_stats
    stats = { total: @error_log.size }
    ERROR_LEVELS.each do |level, _|
      stats[level] = @error_log.count { |error| error[:level] == level }
    end
    stats
  end
  
  # 检查是否有严重错误
  def self.has_critical_errors?
    @error_log.any? { |error| error[:level] == :critical }
  end
  
  # 检查模块是否可用
  def self.module_available?(module_name)
    case module_name
    when :wall_builder
      defined?(WallBuilder)
    when :door_builder
      defined?(DoorBuilder)
    when :window_builder
      defined?(WindowBuilder)
    when :zone_builder
      defined?(ZoneBuilder)
    when :structure_builder
      defined?(StructureBuilder)
    when :flow_builder
      defined?(FlowBuilder)
    when :equipment_builder
      defined?(EquipmentBuilder)
    when :tape_builder
      defined?(TapeBuilder)
    else
      false
    end
  end
  
  # 预定义的恢复策略
  def self.setup_default_recovery_strategies
    # 方法未找到的恢复策略
    register_recovery_strategy(:method_not_found) do |error_info|
      "跳过 #{error_info[:operation]} 操作，继续处理其他功能"
    end
    
    # 参数错误的恢复策略
    register_recovery_strategy(:invalid_argument) do |error_info|
      "使用默认参数重试 #{error_info[:operation]}"
    end
    
    # 类型错误的恢复策略
    register_recovery_strategy(:type_error) do |error_info|
      "跳过 #{error_info[:operation]} 操作，数据类型不匹配"
    end
  end
  
  # 初始化默认恢复策略
  setup_default_recovery_strategies
end
