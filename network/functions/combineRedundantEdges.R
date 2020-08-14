# nodes_current<-intersectionsSimplified[[1]]
# edges_current<-intersectionsSimplified[[2]]

combineRedundantEdges <- function(nodes_current,edges_current){
  # every edge needs a unique id, so the correct geometry can be selected
  edges_current <- edges_current %>%
    mutate(uid=row_number())

  # one-way edges
  edges_directed <- edges_current %>%
    filter(isOneway==1) %>%
    st_drop_geometry() %>%
    group_by(from_id,to_id) %>%
    mutate(current_group=cur_group_id()) %>%
    ungroup()
  
  # the shortest geometry of each directed edge with the same from and to ids
  edges_directed_shortest_geom <- edges_directed %>%
    group_by(current_group) %>%
    slice(which.min(length)) %>%
    ungroup() %>%
    dplyr::select(uid,current_group,length)
  
  # merging multiple one-way lanes going in the same direction
  edges_directed2 <- edges_directed %>%
    dplyr::select(-uid,-length) %>%
    inner_join(edges_directed_shortest_geom, by="current_group") %>%
    group_by(current_group) %>%
    summarise(uid=min(uid,na.rm=T),length=min(length,na.rm=T),
              from_id=min(from_id,na.rm=T),to_id=min(to_id,na.rm=T),
              freespeed=max(freespeed,na.rm=T),permlanes=sum(permlanes,na.rm=T),
              capacity=sum(capacity,na.rm=T),isOneway=max(isOneway,na.rm=T),
              bikeway=max(bikeway,na.rm=T),
              isCycle=max(isCycle,na.rm=T),isWalk=max(isWalk,na.rm=T),
              isCar=max(isCar,na.rm=T)) %>%
    dplyr::select(-current_group)
  
  # attempting to find pairs of one-way edges going in opposite directions.
  edges_directed3 <- edges_directed2 %>%
    mutate(min_from_id=ifelse(from_id<to_id,from_id,to_id)) %>%
    mutate(min_to_id=ifelse(to_id>from_id,to_id,from_id)) %>%
    group_by(min_from_id,min_to_id) %>%
    mutate(current_group=cur_group_id(),group_count=n()) %>%
    ungroup()
  
  # the shortest geometry of directed edge with the same from and to ids,
  # even if goin in opposite directions
  edges_directed3_shortest_geom <- edges_directed3 %>%
    group_by(current_group) %>%
    slice(which.min(length)) %>%
    ungroup() %>%
    dplyr::select(uid,from_id,to_id,current_group,length)
  
  # merging multiple one-way lanes going in the opposite direction
  # this makes them two-way lanes
  edges_directed4 <- edges_directed3 %>%
    dplyr::select(-uid,-length,-from_id,-to_id) %>%
    inner_join(edges_directed3_shortest_geom, by="current_group") %>%
    group_by(current_group) %>%
    summarise(uid=min(uid,na.rm=T),length=min(length,na.rm=T),
              from_id=min(from_id,na.rm=T),to_id=min(to_id,na.rm=T),
              freespeed=max(freespeed,na.rm=T),permlanes=sum(permlanes,na.rm=T),
              capacity=sum(capacity,na.rm=T),isOneway=max(isOneway,na.rm=T),
              bikeway=max(bikeway,na.rm=T),
              isCycle=max(isCycle,na.rm=T),isWalk=max(isWalk,na.rm=T),
              isCar=max(isCar,na.rm=T),group_count=max(group_count,na.rm=T)) %>%
    dplyr::select(-current_group) %>%
    mutate(isOneway=ifelse(group_count>1,0,1)) %>%
    dplyr::select(-group_count)
  
  # adding the directed edges that have merged into undirected edges to the 
  # original undirected edges:
  edges_undirected <- bind_rows(
    edges_directed4 %>%
      filter(isOneway==0),
    edges_current %>% 
      st_drop_geometry() %>%
      filter(isOneway==0) %>%
      dplyr::select(uid,length,from_id,to_id,freespeed,permlanes,capacity,
                    isOneway,bikeway,isCycle,isWalk,isCar))
  
  
  # attempting to find undirected edges even if going in opposite directions.
  edges_undirected2 <- edges_undirected %>%
    mutate(min_from_id=ifelse(from_id<to_id,from_id,to_id)) %>%
    mutate(min_to_id=ifelse(to_id>from_id,to_id,from_id)) %>%
    group_by(min_from_id,min_to_id) %>%
    mutate(current_group=cur_group_id()) %>%
    ungroup()
  
  edges_undirected2_shortest_geom <- edges_undirected2 %>%
    group_by(current_group) %>%
    slice(which.min(length)) %>%
    ungroup() %>%
    dplyr::select(uid,from_id,to_id,current_group,length)
  
  # merging lanes
  edges_undirected3 <- edges_undirected2 %>%
    dplyr::select(-uid,-length,-from_id,-to_id) %>%
    inner_join(edges_undirected2_shortest_geom, by="current_group") %>%
    group_by(current_group) %>%
    summarise(uid=min(uid,na.rm=T),length=min(length,na.rm=T),
              from_id=min(from_id,na.rm=T),to_id=min(to_id,na.rm=T),
              freespeed=max(freespeed,na.rm=T),permlanes=sum(permlanes,na.rm=T),
              capacity=sum(capacity,na.rm=T),isOneway=max(isOneway,na.rm=T),
              bikeway=max(bikeway,na.rm=T),
              isCycle=max(isCycle,na.rm=T),isWalk=max(isWalk,na.rm=T),
              isCar=max(isCar,na.rm=T)) %>%
    dplyr::select(-current_group)
  
  # adding the undirected and directed edges
  edges_all <-  bind_rows(
    edges_undirected3,
    edges_directed4 %>% 
      filter(isOneway==1))
  
  edges_geom <- edges_current %>%
    dplyr::select(uid) %>%
    filter(uid %in% edges_all$uid)
  
  edges_all_geom <- edges_geom %>%
    inner_join(edges_all, by="uid") %>%
    dplyr::select(-uid) %>%
    st_sf() %>%
    st_set_crs(28355)
  return(list(nodes_current,edges_all_geom))
}


