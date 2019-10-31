library(dplyr)
library(sf)
library(igraph)

extract_name <- "carltonSingleBlock"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"


my_nodes <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/nodes_elevated.csv", sep = ""))

my_links <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/links.csv", sep = ""))



# Later I can incoporate this into zCoordinates.R
my_nodes_sf <- my_nodes %>% 
  select(-X) %>%
  st_as_sf(coords = c("x","y"))


my_nodes_sf_croped <- st_crop(my_nodes_sf, c(xmin=969309.8, xmax=971316.7, ymin=-4294159.6, ymax=-4292207.1))

my_links_cropped <- my_links %>% filter(from %in% my_nodes_sf_croped$id | to %in% my_nodes_sf_croped$id)

my_nodes_cropped <- my_nodes %>% filter(id %in% my_links_cropped$from | id %in% my_links_cropped$to ) 

my_short_links <- my_links_cropped %>%
                    filter(length<=15)

#my_nodes_filtered <- my_nodes %>% filter(id %in% my_short_links$from | id %in% my_short_links$to )

g <- graph_from_data_frame(my_short_links[,c("from", "to")], directed = TRUE, vertices = my_nodes_cropped) # Making the graph for the bridges

plot(g,  vertex.size=0.1, vertex.label=NA,
      vertex.color="red", edge.arrow.size=0, edge.curved = 0)

comp <- components(g)

comp_df <- data.frame(segment_id=as.integer(names(comp$membership)), cluster_id=comp$membership, row.names=NULL)

lookup_df <-  data.frame(new_id = unique(comp_df$cluster_id), old_ids = NA)

for (i in 1:nrow(lookup_df)){
  lookup_df$old_ids[i] <- comp_df %>% filter(cluster_id == lookup_df$new_id[i]) %>% select(segment_id) %>% as.list()
  newID <- paste("S_", i, sep = "")
  for (oldID in unlist(lookup_df$old_ids[i])){
    my_nodes_cropped[which(my_nodes_cropped$id  == oldID), "id"] <- newID
    my_short_links[which(my_short_links$from  == oldID), "from"] <- newID
    my_short_links[which(my_short_links$to  == oldID), "to"] <- newID
  }
}

g2 <- graph_from_data_frame(my_short_links[,c("from", "to")], directed = TRUE, vertices = my_nodes_cropped) # Making the graph for the bridges

plot(g2,  vertex.size=0.1, vertex.label=NA,
     vertex.color="red", edge.arrow.size=0, edge.curved = 0)


# Iterating over nodes



 55 %in% unlist(lookup_df$old_ids[1])


my_nodes_sf_croped$id[1]

my_nodes_filtered <- my_nodes_sf_croped %>% filter(id %in% my_short_links$from | id %in% my_short_links$to )

my_nodes_buffered <- st_buffer(st_geometry(my_nodes_filtered), dist = 7)

buffered_union <- st_union(my_nodes_buffered) %>% st_cast("POLYGON") %>% as.data.frame()

#plot(buffered_union)
#plot(buffered_union$geometry[1], col = "red", add = T)
#plot(my_nodes_filtered, add = T)


cetroids <- st_sf(geometry = st_sfc(lapply(1:length(buffered_union$geometry), function(x) st_geometrycollection())))


for (i in 1:length(buffered_union$geometry)) {
  plg <- buffered_union$geometry[i]
  intersections <- st_intersection(my_nodes_filtered$geometry, plg)
  cetroids$geometry[i]<- st_centroid(st_union(intersections))
}


#plot(buffered_union)
#plot(my_nodes_filtered$geometry, add = T)
#plot(plg, col = "green", add = T)
#plot(intersections, col = "red", add = T)
#plot(cetroids, col = "blue", add = T)

st_write(my_nodes_sf_croped, "./my_nodes_sf_croped_org.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")

st_write(my_nodes_filtered, "./my_nodes_filtered_org.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")

st_write(buffered_union, "./buffered_union_org.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")
st_write(cetroids, "./cetroids2_org.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")

#st_write(shp_filtered, "./simpleShp.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")

#st_write(my_nodes_sf, "./simpleNodesAll.sqlite", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")
