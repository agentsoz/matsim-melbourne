 # I needed to change the function a bit to also read the attributes as characters
library(rgdal)
library(igraph)
library(shp2graph)
source("./shp2graph/readshpnw.r")

# plot(lines_filtered["modes"])

# melb_filtered <- st_read("../../outputs/melbourne_filtered.shp") 
melb_filtered <- readOGR("../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/shapeFiles/carlton/carlton.shp") # I am using rdgal instead of sf as shp2graph expects a spatialLinesDataFrame

rtNEL1 <-readshpnw(melb_filtered, Detailed = TRUE, ea.prop = rep(1,9) ) # ea.prop is number of properties you want to keep
igr1 <-nel2igraph(rtNEL1[[2]], rtNEL1[[3]]) # transforming to igraph
plot(igr1, vertex.label = NA, vertex.size = 0.5, vertex.size2 = 0.5, mark.col = "green",
     main = "The converted igraph graph")


write_graph(igr1, file = "../../../../OneDrive/OneDrive - RMIT University/Data/matsim-melbourne-AT/outputs/carlton2/carlton1.txt", "graphml")


