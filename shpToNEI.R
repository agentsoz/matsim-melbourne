# I needed to change the function a bit to also read the attributes as characters
#library(igraph)
library(sf)
library(dplyr)

simplifyFirst <- T

# plot(lines_filtered["modes"])
#inputShp <- "../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/shapeFiles/carlton/carlton.shp"

extract_name <- "carltonSingleBlock"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"

inputShp <- paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/", extract_name,"_filtered.sqlite", sep = "")

shp_filtered <- st_read(inputShp, layer = "lines")

if(simplifyFirst){
  tolerance <- 10
  shp_filtered <- st_simplify(shp_filtered,preserveTopology = T, dTolerance = tolerance)
}

#testList <- st_cast(shp_filtered$GEOMETRY[1], "POINT")


#testList_simple <- st_cast(st_simplify(shp_filtered$GEOMETRY[1],preserveTopology = T, dTolerance = 10), "POINT")


nodes_df <- data.frame(id = integer(0), x = numeric(0), y = numeric(0))

links_df <- data.frame(id = integer(0), from = integer(0), to = integer(0), length = numeric(0), capacity = numeric(0), 
                       freespeed = numeric(0), permlanes = integer(0), modes = character(0), highway = character(0), bikeway = character(0), 
                       stringsAsFactors=FALSE)


links_row <- 1
link_dist <- 0

for (j in 1:length(shp_filtered$GEOMETRY)){
  testList <- st_cast(shp_filtered$GEOMETRY[j], "POINT")
  
  # Adding the first node manually
  point_s <- testList[1]
  
  nodes_row <- nrow(nodes_df) + 1
  
  nodes_df[nodes_row, "id"] <- nodes_row
  nodes_df[nodes_row, "x"] <- point_s[[1]][1]
  nodes_df[nodes_row, "y"] <- point_s[[1]][2]
  nodes_df[nodes_row, "nonplanarity"] <- shp_filtered[j, "nonplanarity"]
  
  for (i in 2:length(testList)){
    temp_point_o <- testList[i-1]
    temp_point_d <- testList[i]
    link_dist <- link_dist + as.numeric(st_distance(temp_point_o, temp_point_d)) # distance is in meters
    if(link_dist > 0 | i == length(testList)){ # 30 meter minimum lenght of a link is considered
      point_s <- temp_point_d
      # Adding node to nodes_df
      nodes_row <- nodes_row + 1
      nodes_df[nodes_row, "id"] <- nodes_row
      nodes_df[nodes_row, "x"] <- point_s[[1]][1]
      nodes_df[nodes_row, "y"] <- point_s[[1]][2]
      nodes_df[nodes_row, "nonplanarity"] <- shp_filtered[j, "nonplanarity"]
      # Adding link
      links_df[links_row, "id"] <- links_row
      links_df[links_row, "from"] <- nodes_row-1
      links_df[links_row, "to"] <- nodes_row
      links_df[links_row, "length"] <- link_dist
      links_df[links_row, c("capacity", "freespeed", "permlanes")] <- shp_filtered[j, c("capacity", "freespeed", "permlanes")]
        
      links_df[links_row, "modes"] <- as.character(shp_filtered$modes[j]) 
      links_df[links_row, "highway"] <- as.character(shp_filtered$highway[j]) 
      links_df[links_row, "bikeway"] <- as.character(shp_filtered$bikeway[j]) 
      
      # Updating values
      link_dist <- 0
      links_row <- links_row + 1
    }
  }
}



# Juts for visualisations
#shp_graph <- graph_from_edgelist(as.matrix(links_df[,c(2,3)]), directed=FALSE)

#shp_graph<- set_vertex_attr(shp_graph,"x", V(shp_graph), as.matrix(nodes_df[,2]))
#shp_graph<- set_vertex_attr(shp_graph,"y", V(shp_graph), as.matrix(nodes_df[,3]))

#plot(shp_graph, vertex.label = NA, vertex.size = 0.005, vertex.size2 = 0.005, mark.col = "green",
#     main = "The converted igraph graph")

# Writing outputs
if(simplifyFirst){
  write.csv(nodes_df, paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/nodes_Simplified_" , tolerance, ".csv", sep = ""))
  write.csv(links_df, paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/links_Simplified_" , tolerance, ".csv", sep = ""))
}else{
  write.csv(nodes_df, paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/nodes.csv", sep = ""))
  write.csv(links_df, paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/links.csv", sep = "")) 
}

