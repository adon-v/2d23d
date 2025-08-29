# 墙体优化模块：处理墙体的吸附、软化和边优化
module WallOptimizer
  # 吸附/软化所有墙体公共边
  def self.optimize_wall_edges(wall_entities)
    puts "暂时关闭"
    return
    
    begin
      all_edges = wall_entities.flat_map { |g| g.entities.grep(Sketchup::Edge) }
      processed = {}
      
      all_edges.combination(2).each do |e1, e2|
        next if e1.deleted? || e2.deleted?
        
        pts1 = [e1.start.position, e1.end.position]
        pts2 = [e2.start.position, e2.end.position]
        
        if (pts1[0].distance(pts2[0]) < 0.001 && pts1[1].distance(pts2[1]) < 0.001) ||
           (pts1[0].distance(pts2[1]) < 0.001 && pts1[1].distance(pts2[0]) < 0.001)
          
          v1 = pts1[1] - pts1[0]; v2 = pts2[1] - pts2[0]
          
          if v1.length > 0.001 && v2.length > 0.001 && (v1.normalize.dot(v2.normalize).abs > 0.999)
            [e1, e2].each do |e|
              next if processed[e]
              e.soft = true if e.respond_to?(:soft=)
              e.smooth = true if e.respond_to?(:smooth=)
              processed[e] = true
            end
          end
        end
      end
    rescue => e
      puts "墙体吸附/软化失败: #{e.message}"
    end
  end
end 