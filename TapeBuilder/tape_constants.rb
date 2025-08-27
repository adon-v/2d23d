module TapeBuilder
  # 胶带配置参数
  TAPE_COLOR = [255, 255, 0]  # 黄色
  TAPE_WIDTH = 0.05           # 胶带宽度（米）
  TAPE_HEIGHT = 0.10          # 胶带高度（米）
  TAPE_ELEVATION = 0.005      # 胶带上浮高度（米）
  
  # 冲突检测参数
  CONFLICT_DETECTION_TOLERANCE = 0.01  # 冲突检测容差（米）
  CONFLICT_RAY_COUNT = 5              # 每段边界发射的射线数量
end 