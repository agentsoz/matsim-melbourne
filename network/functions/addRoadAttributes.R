# nodes_current<-noRedundancies2[[1]]
# edges_current<-noRedundancies2[[2]]

addRoadAttributes <- function(nodes_current,edges_current,road_types){
  isOneWay <- road_types %>%
    dplyr::select(road_type,oneway)
  
  edgesAttributed <- edges_current %>%
    inner_join(road_types,by="road_type") %>%
    dplyr::select(length,from_id,to_id,freespeed,permlanes,capacity,oneway,
                  bikeway,isCycle,isWalk,isCar,modes) %>%
    st_sf %>%
    st_set_crs(28355)
  return(list(nodes_current,edgesAttributed))
}