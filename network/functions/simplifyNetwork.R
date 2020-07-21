simplifyNetwork <- function(n_df,l_df,osm_metadata, shortLinkLength = 20){
  # l_df=lines_np
  # n_df=nodes_np
  # shortLinkLength = 20
  # l_df=linesSimplifiedNoDangles[[2]]
  # n_df=linesSimplifiedNoDangles[[1]]
  # shortLinkLength = 20
  
  n_df <- n_df %>%
    st_drop_geometry() %>%
    cbind(st_coordinates(n_df))
  
  # simplify the lines so they go straight between their from and to nodes
  l_df <- l_df %>%
    filter(!is.na(from_id)) %>%
    st_drop_geometry() %>%
    left_join(n_df,by=c("from_id"="id")) %>%
    rename(fromX=X,fromY=Y) %>%
    left_join(n_df,by=c("to_id"="id")) %>%
    rename(toX=X,toY=Y) %>%
    dplyr::select(road_type,length,from_id,to_id,fromX,fromY,toX,toY)
  
  # finding links with short length (default=10m)
  l_df_short <- l_df %>%
    filter(length<=shortLinkLength) %>%
    dplyr::select(from=from_id,to=to_id)
  
  # Selecting nodes connected with short links
  n_df_short <- base::unique(c(l_df_short$from,l_df_short$to))
  
  # Making the graph for the intersections
  g <- graph_from_data_frame(l_df_short, vertices = n_df_short, directed = FALSE) 
  #plot(g,  vertex.size=0.1, vertex.label=NA, vertex.color="red", edge.arrow.size=0, edge.curved = 0)
  
  # Getting components
  comp <- components(g)
  comp_df <- data.frame(node_id=as.integer(names(comp$membership)),
                        # cluster_id will be the new node id, so mustn't clash with used ids
                        cluster_id=comp$membership+max(n_df$id,na.rm=TRUE), row.names=NULL) %>%
    left_join(n_df, by=c("node_id"="id"))
  
  comp_df_centroid <- comp_df %>%
    group_by(cluster_id) %>%
    summarise(X=round(mean(X)),Y=round(mean(Y)),is_roundabout=max(is_roundabout),
              is_signal=max(is_signal)) %>%
    ungroup()
  
  # changing the original coordinates to the cluster id
  comp_df_altered <- comp_df %>%
    left_join(comp_df_centroid,by="cluster_id") %>%
    dplyr::select(node_id,cluster_id,X=X.y,Y=Y.y)
  
  # adding the unaltered nodes to the cluster nodes
  n_df_new <- n_df %>%
    filter(!id %in% comp_df$node_id) %>%
    rbind(dplyr::select(comp_df_centroid,id=cluster_id,is_roundabout,is_signal,X,Y)) %>%
    mutate(geom=paste0("POINT(",X," ",Y,")")) %>%
    st_as_sf(wkt = "geom", crs = 28355)
  
  # keeping only the long edges, we alter any endpoints that are part of a
  # cluster, replacing them with the cluster id and the centroid coordinates
  l_df_new <- l_df %>%
    filter(length>shortLinkLength) %>%
    left_join(comp_df_altered, by=c("from_id"="node_id")) %>%
    mutate(from_id=ifelse(is.na(cluster_id),from_id,cluster_id)) %>%
    mutate(fromX=ifelse(is.na(cluster_id),fromX,X)) %>%
    mutate(fromY=ifelse(is.na(cluster_id),fromY,Y)) %>%
    dplyr::select(road_type,length,from_id,to_id,fromX,fromY,toX,toY) %>%
    left_join(comp_df_altered, by=c("to_id"="node_id")) %>%
    mutate(to_id=ifelse(is.na(cluster_id),to_id,cluster_id)) %>%
    mutate(toX=ifelse(is.na(cluster_id),toX,X)) %>%
    mutate(toY=ifelse(is.na(cluster_id),toY,Y)) %>%
    dplyr::select(road_type,length,from_id,to_id,fromX,fromY,toX,toY) %>%
    mutate(geom=paste0("LINESTRING(",fromX," ",fromY,",",toX," ",toY,")")) %>%
    st_as_sf(wkt = "geom", crs = 28355)
  
  
  # remove the disconnected bits
  
  # Making the graph for the intersections
  g <- graph_from_data_frame(dplyr::select(l_df_new, from=from_id,to=to_id), directed = FALSE) 
  #plot(g,  vertex.size=0.1, vertex.label=NA, vertex.color="red", edge.arrow.size=0, edge.curved = 0)
  
  # Getting components
  comp2 <- components(g)
  nodes_in_largest_component <- data.frame(node_id=as.integer(names(comp2$membership)),
                                           cluster_id=comp2$membership, row.names=NULL) %>%
    filter(cluster_id==which.max(comp2$csize)) %>%
    pull(node_id) %>%
    base::unique()
  
  n_df_filtered <- n_df_new %>%
    filter(id%in%nodes_in_largest_component) %>%
    dplyr::select(id,is_roundabout,is_signal)
  
  
  l_df_filtered <- l_df_new %>%
    filter(from_id%in%nodes_in_largest_component & to_id%in%nodes_in_largest_component) %>%
    dplyr::select(road_type,length,from_id,to_id)
  
  return(list(n_df_filtered,l_df_filtered))
}

# st_write(l_df_filtered,"data/networkSimplified.sqlite",delete_layer=TRUE,layer="edges")
# st_write(n_df_filtered,"data/networkSimplified.sqlite",delete_layer=TRUE,layer="nodes")
