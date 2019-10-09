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
inputShp <- paste("../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/", extract_name, "/", extract_name,"_filtered_new3.sqlite", sep = "")

outputXml <- paste("../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/", extract_name, "/multi_mode/xml/", extract_name, ".xml", sep = "") 

# melb_filtered <- st_read("../../outputs/melbourne_filtered.shp") 
#shp_filtered <- readOGR(inputShp, layer = "lines") # I am using rdgal instead of sf as shp2graph expects a spatialLinesDataFrame
shp_filtered <- st_read(inputShp, layer = "lines")

shp_filtered <- st_transform(shp_filtered, crs = 7845)

# Converting to spatial df as it is what readshpnw expects
#shp_filtered_spatial <- as(shp_filtered, 'Spatial')
shp_node_edge <-readshpnw(as(shp_filtered, 'Spatial'), Detailed = TRUE, ea.prop = rep(1,8) ) # ea.prop is number of properties you want to keep

shp_nodes <- shp_node_edge[[2]]

id <- 

shp_nodes_df <- data.frame()
shp_nodes_test$x <- shp_nodes[,2][[1]][1]

write.csv(shp_nodes, "./test.csv")

for (i in 1:length(shp_nodes[,1])){
  shp_nodes_df[i, "id"] <- shp_nodes[[i]][1][1]
  shp_nodes_df[i, "geom"] <- st_point(shp_nodes[i,2][[1]][1] , shp_nodes[i,2][[1]][2])
  shp_nodes_df[i, "y"] <- 
}

test <- shp_nodes_df %>%
  mutate(geom = st_point(c(x, y))) %>%
  st_as_sf()

st_point()

shp_edges <- shp_node_edge[[3]]

shp_attribs <- shp_node_edge[[5]]


# Adding elevation --------------------------------------------------------

elevation <- raster("../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/DEMs/DELWPx10.tif")

#elevation_crs <- projectRaster(elevation, crs = as.character(st_crs(shp_filtered))[2])
elevation_small <- aggregate(elevation_crs, fact = 2, fun = mean)
plot(elevation_small)


## generating an igraph 
shp_graph <- igraph_generator(node_list = shp_node_edge[[2]], edge_list = shp_node_edge[[3]],  attribs_df = shp_node_edge[[5]])

plot(shp_graph, vertex.label = NA, vertex.size = 0.5, vertex.size2 = 0.5, mark.col = "green",
     main = "The converted igraph graph")

write_graph(shp_graph, file = outputXml, "graphml")

