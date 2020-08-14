largestConnectedComponent <- function(n_df,l_df){
  l_df_no_geom <- l_df %>%
    st_drop_geometry() %>%
    dplyr::select(from=from_id,to=to_id)
  # remove the disconnected bits
  
  # Making the graph for the intersections
  g <- graph_from_data_frame(l_df_no_geom, directed = FALSE) 
  #plot(g,  vertex.size=0.1, vertex.label=NA, vertex.color="red", edge.arrow.size=0, edge.curved = 0)
  
  # Getting components
  comp <- components(g)
  nodes_in_largest_component <- data.frame(node_id=as.integer(names(comp$membership)),
                                           cluster_id=comp$membership, row.names=NULL) %>%
    filter(cluster_id==which.max(comp$csize)) %>%
    pull(node_id) %>%
    base::unique()
  
  n_df_filtered <- n_df %>%
    filter(id%in%nodes_in_largest_component) %>%
    dplyr::select(id,is_roundabout,is_signal)
  
  l_df_filtered <- l_df %>%
    filter(from_id%in%nodes_in_largest_component & to_id%in%nodes_in_largest_component)
  
  return(list(n_df_filtered,l_df_filtered))
}