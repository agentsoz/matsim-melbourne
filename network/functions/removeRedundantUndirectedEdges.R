# nodes_current<-networkSimplified[[1]]
# edges_current<-networkSimplified[[2]]

removeRedundantUndirectedEdges <- function(nodes_current,edges_current,road_types){
  isOneWay <- road_types %>%
    dplyr::select(road_type,oneway)
  
  edges2 <- edges_current %>%
    inner_join(isOneWay,by="road_type")
  
  edgesUndirected <- edges2 %>%
    filter(oneway==1) %>%
    rowwise() %>%
    mutate(from=min(from_id,to_id),
           to=max(from_id,to_id)) %>%
    mutate(from_id=from,
           to_id=to) %>%
    dplyr::select(-from,-to,-oneway) %>%
    data.frame() %>%
    st_sf()
  
  edgesDirected <- edges2 %>%
    filter(oneway==2) %>%
    dplyr::select(-oneway)
  
  edgesNoRedundancies <- bind_rows(edgesUndirected,edgesDirected) %>%
    group_by(from_id,to_id,road_type) %>%
    slice(which.min(length)) %>%
    ungroup() %>%
    data.frame() %>%
    st_sf() %>%
    st_set_crs(28355)
  return(list(nodes_current,edgesNoRedundancies))
}


