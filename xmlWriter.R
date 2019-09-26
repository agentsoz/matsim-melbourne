 # I needed to change the function a bit to also read the attributes as characters
library(rgdal)
library(igraph)
library(shp2graph)
source("./shp2graph/readshpnw.R")
source("./shp2graph/igraph_generator.R")

# plot(lines_filtered["modes"])
#inputShp <- "../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/shapeFiles/carlton/carlton.shp"

extract_name <- "CBD_dockland"

inputShp <- paste("../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/", extract_name, "/multi_mode/sqlite/", extract_name,"_filtered.sqlite", sep = "")
outputXml <- paste("../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/", extract_name, "/multi_mode/xml/", extract_name, ".xml", sep = "") 

# melb_filtered <- st_read("../../outputs/melbourne_filtered.shp") 
shp_filtered <- readOGR(inputShp, layer = "lines") # I am using rdgal instead of sf as shp2graph expects a spatialLinesDataFrame

shp_node_edge <-readshpnw(shp_filtered, Detailed = TRUE, ea.prop = rep(1,11) ) # ea.prop is number of properties you want to keep

shp_graph <- igraph_generator(node_list = shp_node_edge[[2]], edge_list = shp_node_edge[[3]],  attribs_df = shp_node_edge[[5]])

plot(shp_graph, vertex.label = NA, vertex.size = 0.5, vertex.size2 = 0.5, mark.col = "green",
     main = "The converted igraph graph")

write_graph(shp_graph, file = outputXml, "graphml")

