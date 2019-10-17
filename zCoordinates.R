library(raster)
library(sf)
library(dplyr)


crs_final <- 7845

oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"


# Adding elevation --------------------------------------------------------

elevation <- raster(paste(oneDriveURL, "/Data/rawSpatial/DEMs/DELWPx10.tif", sep = ""))

#elevation_crs <- projectRaster(elevation, crs = crs_final)
#elevation_small <- aggregate(elevation, fact = 2, fun = mean)


my_nodes <- read.csv(file = paste(oneDriveURL, "/Data/processedSpatial/CBD_dockland/nodes_new.csv", sep = ""))

my_points <- my_nodes %>%
  mutate(points_h = st_point(c(my_points$x,my_points$y)))

raster::extract(elevation_small ,as(my_point, "Spatial"),method='bilinear')
