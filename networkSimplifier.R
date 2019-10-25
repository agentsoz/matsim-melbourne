library(dplyr)
library(sf)

extract_name <- "carltonSingleBlock"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"


my_nodes <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/nodes_elevated.csv", sep = ""))

my_links <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name,"/links.csv", sep = ""))



# Later I can incoporate this into zCoordinates.R
my_nodes_sf <- my_nodes %>% 
  select(-X) %>%
  st_as_sf(coords = c("x","y"))


my_nodes_sf_croped<- st_crop(my_nodes_sf, c(xmin=969309.8, xmax=971316.7, ymin=-4294159.6, ymax=-4292207.1))


my_short_links <- my_links %>% filter(length < 15)


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
