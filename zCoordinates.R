library(raster)
library(sf)
library(dplyr)


crs_final <- 7845

# Change to/not to save csv 
saveCSV <- TRUE
# Change to/not to save sqlite 
saveSQLITE <- TRUE


osm_extract <- "carltonSingleBlock"

oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
outputDir <- paste(oneDriveURL, "/Data/processedSpatial/", osm_extract,"/", sep= "")
# Adding elevation --------------------------------------------------------

elevation <- raster(paste(oneDriveURL, "/Data/rawSpatial/DEMs/DELWPx10.tif", sep = ""))

#elevation_crs <- projectRaster(elevation, crs = crs_final)
#elevation_small <- aggregate(elevation, fact = 2, fun = mean)


my_nodes <- read.csv(file = paste(oneDriveURL, "/Data/processedSpatial/", osm_extract,"/", "nodes.csv", sep = ""))



my_nodes <- my_nodes %>% 
              select(-X) %>%
              st_as_sf(coords = c("x","y"))


my_nodes$z <- round(raster::extract(elevation ,as(my_nodes, "Spatial"),method='bilinear'))/10

my_nodes <- my_nodes %>%
              mutate(z = ifelse(test = is.na(z)
                                ,yes = 10,
                                no = z))

if(saveSQLITE){
  outputSQLite <- paste(outputDir ,osm_extract,"_points_elevated.sqlite", sep = "")
  st_write(my_nodes, outputSQLite, layer = "lines", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")
  
}

if(saveCSV){
  nodes_coords <- do.call(rbind, st_geometry(my_nodes))
  colnames(nodes_coords) <- c("x", "y")
  st_geometry(my_nodes) <- NULL 
  my_nodes <- cbind(nodes_coords, my_nodes) %>% select(id, x, y, z) # if there is a column for nonplanrity it should be here
  outputCSV <- paste(outputDir ,"nodes_elevated.csv", sep = "")
  write.csv(my_nodes, outputCSV)
}
