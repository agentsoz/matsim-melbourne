 # I needed to change the function a bit to also read the attributes as characters
library(igraph)
library(raster)
library(sf)
library(shp2graph)
source("./shp2graph/readshpnw.r")
source("./shp2graph/igraph_generator.R")

crs_final <- 28355

# plot(lines_filtered["modes"])
#inputShp <- "../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/shapeFiles/carlton/carlton.shp"

extract_name <- "CBD_dockland"

#inputShp <- paste("../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/", extract_name, "/multi_mode/sqlite/", extract_name,"_filtered.sqlite", sep = "")
#outputXml <- paste("../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/", extract_name, "/multi_mode/xml/", extract_name, ".xml", sep = "") 

#inputShp <- paste("../../../OneDrive/Data/processedSpatial/", extract_name, "/multi_mode/sqlite/", extract_name,"_filtered.sqlite", sep = "")
inputShp <- paste("../../../OneDrive/Data/processedSpatial/", extract_name, "/", extract_name,"_filtered.sqlite", sep = "")

outputXml <- paste("../../../OneDrive/Data/processedSpatial/", extract_name, "/multi_mode/xml/", extract_name, ".xml", sep = "") 

# melb_filtered <- st_read("../../outputs/melbourne_filtered.shp") 
#shp_filtered <- readOGR(inputShp, layer = "lines") # I am using rdgal instead of sf as shp2graph expects a spatialLinesDataFrame
shp_filtered <- st_read(inputShp, layer = "lines")

shp_filtered <- st_transform(shp_filtered, crs = crs_final)

# Converting to spatial df as it is what readshpnw expects
shp_filtered_spatial <- as(shp_filtered, 'Spatial')
shp_node_edge <-readshpnw(shp_filtered_spatial, Detailed = TRUE, ea.prop = rep(1,11) ) # ea.prop is number of properties you want to keep

# Adding elevation --------------------------------------------------------

elevation <- raster("../../../OneDrive/Data/rawSpatial/DEMs/DELWPx10.tif")
elevation_crs <- projectRaster(elevation, crs = as.character(st_crs(shp_filtered))[2])
elevation_small <- aggregate(elevation_crs, fact = 2, fun = mean)
plot(elevation_small)


## generating an igraph 
shp_graph <- igraph_generator(node_list = shp_node_edge[[2]], edge_list = shp_node_edge[[3]],  attribs_df = shp_node_edge[[5]])

plot(shp_graph, vertex.label = NA, vertex.size = 0.5, vertex.size2 = 0.5, mark.col = "green",
     main = "The converted igraph graph")

write_graph(shp_graph, file = outputXml, "graphml")

