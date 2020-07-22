addElevation2Nodes <- function(nodes, rasterFile){
  elevation <- raster(rasterFile) 
  nodes$z <- round(raster::extract(elevation ,as(nodes, "Spatial"),method='bilinear'))/10
  
  return(nodes)
}