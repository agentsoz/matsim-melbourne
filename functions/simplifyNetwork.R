
# simplifyNetwork <- function(l_df, n_df, shortLinkLength = 10){
l_df=lines_np
n_df=nodes_np
shortLinkLength = 20

n_df_coords <- n_df %>%
  st_drop_geometry() %>%
  cbind(st_coordinates(n_df))
roundabout_osm <- lines_p %>%
  st_drop_geometry() %>%
  filter(other_tags %like% "roundabout") %>%
  pull(osm_id)


l_df <- lines_np %>%
  st_drop_geometry() %>%
  rowwise() %>%
  mutate(from=min(from_id,to_id),
         to=max(from_id,to_id)) %>%
  dplyr::select(osm_id,length,from_id=from,to_id=to,id) %>%
  as.data.frame() %>%
  left_join(n_df_coords,by=c("from_id"="id")) %>%
  rename(fromX=X,fromY=Y) %>%
  left_join(n_df_coords,by=c("to_id"="id")) %>%
  rename(toX=X,toY=Y)

roundabout_n <- l_df %>%
  filter(length<=shortLinkLength) %>%
  filter(osm_id %in% roundabout_osm)

roundabout_n <- base::unique(c(roundabout_n$from_id,roundabout_n$to_id))
  # l_df <- l_df %>%
  #   rowwise() %>%
  #   mutate(from=min(from_id,to_id),
  #          to=max(from_id,to_id)) %>%
  #   # st_drop_geometry() %>%
  #   dplyr::select(osm_id,length,from_id=from,to_id=to,id,GEOMETRY) %>%
  #   st_as_sf()
  # 
  
    
  # finding links with short length (default=10m)
  l_df_short <- l_df %>%
    filter(length<=shortLinkLength) %>%
    dplyr::select(from=from_id,to=to_id) %>%
    distinct()
  # left_join(roundabout_df) %>%
    # group_by(from_id,to_id) %>%
    # summarise(roundabout=max(roundabout)) %>%
  # st_drop_geometry() %>%
  

  # Selecting nodes connected with short links
  # n_df_short <- n_df %>% filter(id %in% l_df_short$from | id %in% l_df_short$to )
  n_df_short <- base::unique(c(l_df_short$from,l_df_short$to))
  # Making the graph for the bridges
  g <- graph_from_data_frame(l_df_short, vertices = n_df_short, directed = FALSE) 
  #plot(g,  vertex.size=0.1, vertex.label=NA, vertex.color="red", edge.arrow.size=0, edge.curved = 0)
  
  # Getting components
  comp <- components(g)
  comp_df <- data.frame(segment_id=as.integer(names(comp$membership)), cluster_id=comp$membership, row.names=NULL) %>%
    left_join(n_df_coords, by=c("segment_id"="id")) %>%
    mutate(roundabout=ifelse(segment_id %in% roundabout_n,1,0))
  
  comp_df_centroid <- comp_df %>%
    group_by(cluster_id) %>%
    summarise(X=round(mean(X)),Y=round(mean(Y)),roundabout=max(roundabout)) %>%
    ungroup() %>%
    mutate(new_id=max(n_df_coords$id)+cluster_id)
  
  comp_df_altered <- comp_df %>%
    left_join(comp_df_centroid,by="cluster_id") %>%
    dplyr::select(id=segment_id,new_id,X=X.y,Y=Y.y)
  
n_df_new <- n_df_coords %>%
  filter(!id %in% comp_df$segment_id) %>%
  mutate(roundabout=0) %>%
  rbind(dplyr::select(comp_df_centroid,id=new_id,X,Y,roundabout)) %>%
  mutate(GEOMETRY=paste0("POINT(",X," ",Y,")")) %>%
  st_as_sf(wkt = "GEOMETRY", crs = 28355)

l_df_new <- l_df %>%
  left_join(comp_df_altered, by=c("from_id"="id")) %>%
  mutate(from_id=ifelse(is.na(new_id),from_id,new_id)) %>%
  mutate(fromX=ifelse(is.na(new_id),fromX,X)) %>%
  mutate(fromY=ifelse(is.na(new_id),fromY,Y)) %>%
  dplyr::select(osm_id,length,from_id,to_id,fromX,fromY,toX,toY) %>%
  left_join(comp_df_altered, by=c("to_id"="id")) %>%
  mutate(to_id=ifelse(is.na(new_id),to_id,new_id)) %>%
  mutate(toX=ifelse(is.na(new_id),toX,X)) %>%
  mutate(toY=ifelse(is.na(new_id),toY,Y)) %>%
  dplyr::select(osm_id,length,from_id,to_id,fromX,fromY,toX,toY) %>%
  mutate(GEOMETRY=paste0("LINESTRING(",fromX," ",fromY,",",toX," ",toY,")")) %>%
  st_as_sf(wkt = "GEOMETRY", crs = 28355)


st_write(l_df_new,"networkSimplified.sqlite",delete_layer=TRUE,layer="edges")
st_write(n_df_new,"networkSimplified.sqlite",delete_layer=TRUE,layer="nodes")
