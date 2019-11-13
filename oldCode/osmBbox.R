# 1. Cropping the data to desired bbox + transforming to the desired CRS

library(dplyr)
library(sf)

crs_final <- 7845

oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"
osm_extract <- "carltonSingleBlock"
#osm_extract <- "melbourne"

inputSQLite <- paste(oneDriveURL, "/Data/rawSpatial/osmExtracts/", osm_extract,".osm", sep = "")
outputSQLite <- paste(oneDriveURL, "/Data/processedSpatial/", osm_extract,"/",osm_extract,"_croped.sqlite", sep = "")
# Defining feasible tag sets ----------------------------------------------
lines_filtered <- st_read(inputSQLite , layer="lines") 

lines_filtered <- st_transform(lines_filtered, crs_final)


pts = matrix(c(969309.8, 969309.8,  971316.7 , 971316.7, -4294159.6, -4292207.1, -4294159.6, -4292207.1), ,2)
mp1 = st_multipoint(pts)
bbox <- st_convex_hull(st_union(mp1)) 

#c(xmin=969309.8, xmax=971316.7, ymin=-4294159.6, ymax=-4292207.1)

lines_filtered <- st_crop(lines_filtered, bbox)


st_write(lines_filtered, outputSQLite, layer = "lines", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")

