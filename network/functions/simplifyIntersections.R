simplifyIntersections <- function(n_df,l_df, shortLinkLength = 10){
  # shortLinkLength = 20
  # l_df=largestComponent[[2]]
  # n_df=largestComponent[[1]]

  n_df_no_geom <- n_df %>%
    st_drop_geometry() %>%
    cbind(st_coordinates(n_df))
  
  # simplify the lines so they go straight between their from and to nodes
  l_df_no_geom <- l_df %>%
    filter(!is.na(from_id)) %>%
    st_drop_geometry() %>%
    dplyr::select(length,from_id,to_id)
  
  # finding links with short length (default=10m)
  l_df_short <- l_df_no_geom %>%
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
    left_join(n_df_no_geom, by=c("node_id"="id"))
  
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
  n_df_new <- n_df_no_geom %>%
    filter(!id %in% comp_df$node_id) %>%
    rbind(dplyr::select(comp_df_centroid,id=cluster_id,is_roundabout,is_signal,X,Y)) %>%
    mutate(geom=paste0("POINT(",X," ",Y,")")) %>%
    st_as_sf(wkt = "geom", crs = 28355)
  
  # this function adds endpoints to the geometries
  addEndpoints <- function(fromX,fromY,toX,toY,geom) {
    geomMatrix <- st_coordinates(geom)[,1:2]
    if(!is.na(fromX) ) {
      geomMatrix <- rbind(c(fromX,fromY),geomMatrix)
    }
    if(!is.na(toX) ) {
      geomMatrix <- rbind(geomMatrix,c(toX,toY))
    }
    geomFinal <- st_linestring(geomMatrix)
    return(geomFinal)
  }
  # addEndpoints(346185,5814175,346185,5814175,startpoint_to_alter$geom[1])

  # keeping only the long edges, we alter any endpoints that are part of a
  # cluster, replacing them with the cluster id and the centroid coordinates
  l_df_new <- l_df %>%
    filter(length>shortLinkLength) %>%
    left_join(comp_df_altered, by=c("from_id"="node_id")) %>%
    mutate(from_id=ifelse(is.na(cluster_id),from_id,cluster_id)) %>%
    rename(fromX=X,fromY=Y) %>%
    dplyr::select(-cluster_id) %>%
    left_join(comp_df_altered, by=c("to_id"="node_id")) %>%
    mutate(to_id=ifelse(is.na(cluster_id),to_id,cluster_id)) %>%
      rename(toX=X,toY=Y) %>%
      dplyr::select(-cluster_id)

  # adding endpoints to the geometries where intersections have been simplified
  geomExtended <- mapply(addEndpoints,l_df_new$fromX,l_df_new$fromY,l_df_new$toX,l_df_new$toY,l_df_new$geom)
  
  l_df_altered <- l_df_new %>%
    st_drop_geometry() %>%
    mutate(geom=geomExtended) %>%
    st_sf() %>%
    st_set_crs(28355) %>%
    # remove any loops
    filter(from_id != to_id) %>%
    dplyr::select(-fromX,-fromY,-toX,-toY) %>%
    mutate(length=round(as.numeric(st_length(.)),3))
  
  return(list(n_df_new,l_df_altered))
}


