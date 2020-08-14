# nodes_current<-intersectionsSimplified[[1]]
# edges_current<-intersectionsSimplifiedEdges

combineUndirectedAndDirectedEdges <- function(nodes_current,edges_current){
  
  edges_current <- edges_current %>%
    mutate(uid=row_number())
  
  # attempting to groups of one-way and two-way edges
  edges_grouped <- edges_current %>%
    st_drop_geometry() %>%
    mutate(min_from_id=ifelse(from_id<to_id,from_id,to_id)) %>%
    mutate(min_to_id=ifelse(to_id>from_id,to_id,from_id)) %>%
    group_by(min_from_id,min_to_id) %>%
    mutate(current_group=cur_group_id()) %>%
    ungroup()
  
  edges_grouped_shortest_geom <- edges_grouped %>%
    group_by(current_group) %>%
    slice(which.min(length)) %>%
    ungroup() %>%
    dplyr::select(uid,from_id,to_id,current_group,length)
  
  # merging one-way and two-way lanes
  # we take the min of isOneway to ensure that merging one-way and two-way lanes
  # results in a two-way edge
  edges_grouped2 <- edges_grouped %>%
    dplyr::select(-uid,-length,-from_id,-to_id) %>%
    inner_join(edges_grouped_shortest_geom, by="current_group") %>%
    group_by(current_group) %>%
    summarise(uid=min(uid,na.rm=T),length=min(length,na.rm=T),
              from_id=min(from_id,na.rm=T),to_id=min(to_id,na.rm=T),
              freespeed=max(freespeed,na.rm=T),permlanes=sum(permlanes,na.rm=T),
              capacity=sum(capacity,na.rm=T),isOneway=min(isOneway,na.rm=T),
              bikeway=max(bikeway,na.rm=T),
              isCycle=max(isCycle,na.rm=T),isWalk=max(isWalk,na.rm=T),
              isCar=max(isCar,na.rm=T)) %>%
    dplyr::select(-current_group)
  
  # geometry of shortest edges
  edges_geom <- edges_current %>%
    dplyr::select(uid) %>%
    filter(uid %in% edges_grouped2$uid)
  
  # adding geometry to groups
  edges_all_geom <- edges_geom %>%
    inner_join(edges_grouped2, by="uid") %>%
    dplyr::select(-uid) %>%
    st_sf() %>%
    st_set_crs(28355)
  return(list(nodes_current,edges_all_geom))
}


