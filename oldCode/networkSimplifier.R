# 5. Simplifying the network

library(dplyr)
library(sf)
library(igraph)

extract_name <- "carltonSingleBlock"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"

my_nodes <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/nodes_elevated.csv", sep = ""))

my_links <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/links.csv", sep = ""))

# Later I can incoporate this into zCoordinates.R
#my_nodes_sf <- my_nodes %>% 
#  select(-X) %>%
#  st_as_sf(coords = c("x","y"))


#my_nodes_sf_croped <- st_crop(my_nodes_sf, c(xmin=969309.8, xmax=971316.7, ymin=-4294159.6, ymax=-4292207.1))

# my_links_cropped <- my_links %>% filter(from %in% my_nodes_sf_croped$id | to %in% my_nodes_sf_croped$id)

# my_nodes_cropped <- my_nodes %>% filter(id %in% my_links_cropped$from | id %in% my_links_cropped$to ) 

my_short_links <- my_links %>%
                    filter(length<=15)

my_nodes_filtered <- my_nodes %>% filter(id %in% my_short_links$from | id %in% my_short_links$to )

g <- graph_from_data_frame(my_short_links[,c("from", "to")], directed = TRUE, vertices = my_nodes_filtered) # Making the graph for the bridges

plot(g,  vertex.size=0.1, vertex.label=NA,
      vertex.color="red", edge.arrow.size=0, edge.curved = 0)

comp <- components(g)

comp_df <- data.frame(segment_id=as.integer(names(comp$membership)), cluster_id=comp$membership, row.names=NULL)

lookup_df <-  data.frame(new_id = unique(comp_df$cluster_id), old_ids = NA, x = NA, y = NA, z = NA)

# Finding centroids
for (i in 1:nrow(lookup_df)){
  lookup_df$old_ids[i] <- comp_df %>% filter(cluster_id == lookup_df$new_id[i]) %>% dplyr::select(segment_id) %>% as.list()
  this_old_ids <- which(my_nodes$id %in% unlist(lookup_df$old_ids[i]))
  if(length(this_old_ids) > 2){
    xcors <- my_nodes$x[this_old_ids]
    ycors <- my_nodes$y[this_old_ids]
    zcors <- my_nodes$z[this_old_ids]
    lookup_df$x[i] <- mean(xcors)
    lookup_df$y[i] <- mean(ycors)
    lookup_df$z[i] <- mean(zcors)
    newID <- paste("S_", i, sep = "")
    for (oldID in unlist(lookup_df$old_ids[i])){
      j <- which(my_nodes$id  == oldID)
      my_nodes$id[j] <- newID
      my_nodes$x[j] <- lookup_df$x[i]
      my_nodes$y[j] <- lookup_df$y[i]
      my_nodes$z[j] <- lookup_df$z[i]
      my_links[which(my_links$from  == oldID), "from"] <- newID
      my_links[which(my_links$to  == oldID), "to"] <- newID
    }
  }
}

new_my_nodes <- my_nodes %>% dplyr::select(-X) %>% distinct(id, x, y, z)

g2 <- graph_from_data_frame(my_links[,c("from", "to")], directed = TRUE, vertices = new_my_nodes) # Making the graph for the bridges

plot(g2,  vertex.size=0.1, vertex.label=NA,
     vertex.color="red", edge.arrow.size=0, edge.curved = 0)

write.csv(new_my_nodes, paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/nodes_simplified.csv", sep = ""))
write.csv(my_links, paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/links_simplified.csv", sep = ""))

#nodes_sf <- st_as_sf(new_my_nodes, coords = c("x", "y"), crs = 7845)

st_write(nodes_sf, "./my_new_nodes.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")

st_write(my_nodes_filtered, "./my_nodes_filtered_org.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")
