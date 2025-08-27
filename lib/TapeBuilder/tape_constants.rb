module TapeBuilder
  # 胶带配置参数
  TAPE_COLOR = [255, 255, 0]  # 黄色
  TAPE_WIDTH = 0.5           # 胶带宽度（米）
  TAPE_HEIGHT = 0.001        # 胶带厚度（米）- 调整为很薄的平面
  TAPE_ELEVATION = 0.02       # 胶带上浮高度（米）- 防止与地面抢面
  
  # 冲突检测参数
  CONFLICT_DETECTION_TOLERANCE = 0.01  # 冲突检测容差（米）
  CONFLICT_RAY_COUNT = 5              # 每段边界发射的射线数量

end 