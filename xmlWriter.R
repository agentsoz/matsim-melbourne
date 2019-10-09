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
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"

inputShp <- paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/", extract_name,"_filtered_new3.sqlite", sep = "")

outputXml <- paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/multi_mode/xml/", extract_name, ".xml", sep = "") 

shp_filtered <- st_read(inputShp, layer = "lines")

shp_filtered <- st_transform(shp_filtered, crs = 7845)

# Converting to spatial df as it is what readshpnw expects
shp_node_edge <-readshpnw(as(shp_filtered, 'Spatial'), Detailed = TRUE, ea.prop = rep(1,8) ) # ea.prop is number of properties you want to keep

shp_nodes <- shp_node_edge[[2]]

shp_nodes_df <- st_sf(id = 1:length(shp_nodes[,1]), geometry = st_sfc(lapply(1:length(shp_nodes[,1]), function(x) st_geometrycollection())))

for (i in 1:length(shp_nodes[,1])){
  shp_nodes_df$geometry[i] <- st_point(c(shp_nodes[i,2][[1]][1] , shp_nodes[i,2][[1]][2]))
}

test <- shp_nodes_df %>%
  mutate(geom = st_point(c(x, y))) %>%
  st_as_sf()

st_write(shp_nodes_df, )

shp_edges <- shp_node_edge[[3]]
write.csv()

shp_attribs <- shp_node_edge[[5]]
write.csv(shp_attribs, )






# Adding elevation --------------------------------------------------------

elevation <- raster(paste(oneDriveURL, "/Data/rawSpatial/DEMs/DELWPx10.tif", sep = ""))

#elevation_crs <- projectRaster(elevation, crs = as.character(st_crs(shp_filtered))[2])
elevation_small <- aggregate(elevation_crs, fact = 2, fun = mean)
plot(elevation_small)


## generating an igraph 
shp_graph <- igraph_generator(node_list = shp_node_edge[[2]], edge_list = shp_node_edge[[3]],  attribs_df = shp_node_edge[[5]])

plot(shp_graph, vertex.label = NA, vertex.size = 0.5, vertex.size2 = 0.5, mark.col = "green",
     main = "The converted igraph graph")

write_graph(shp_graph, file = outputXml, "graphml")

