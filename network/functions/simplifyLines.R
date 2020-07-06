###############################################################################
### Information                                                             ###
###############################################################################

# Sometimes the route between two intersections is comprised of a different
# number of edges, so we have to deal with them differently:
# 1 edge:   There is a direct edge between the two intersections, so we 
#           leave it alone
# 3+ edges: We remove all edges touching intersections, and cluster the
#           remaining to find the chain of edges
# 2 edges:  There is a single non-intersection node, and must be handled
#           separately since the clustering will remove them

# temp <- function(df){
#   View(filter(df,from_id==147405 | to_id==147405))
# }

# nodes <- st_read("data-intermediate/network.sqlite",layer="nodes")
# edges <- st_read("data-intermediate/network.sqlite",layer="edges")

# nodes <-noDangles[[1]]
# edges <-noDangles[[2]]
simplifyLines <- function(nodes,edges){
    
  nodesNoGeom <- nodes %>%
    st_drop_geometry()
  
  edgesNoGeom <- edges %>%
    st_drop_geometry()
  
  edgesNoGeomUndirected <- edgesNoGeom %>%
    rowwise() %>%
    mutate(from=min(from_id,to_id),
           to=max(from_id,to_id)) %>%
    dplyr::select(from,to) %>%
    distinct()
    
  
  # the node ids of intersections (not a dataframe)
  nodesIntersections <- rbind(
    edgesNoGeomUndirected %>% dplyr::select(id=from),
    edgesNoGeomUndirected %>% dplyr::select(id=to) ) %>%
    group_by(id) %>%
    summarise(count=n()) %>%
    filter(count!=2) %>%
    pull(id)
  
  nodesIntersectionsGeom <- nodes %>%
    filter(id %in% nodesIntersections)
  nodesIntersectionsCoords <- nodesIntersectionsGeom %>%
                                      st_coordinates() %>%
    as.data.frame()
  nodesIntersectionsDF <- cbind(st_drop_geometry(nodesIntersectionsGeom),
                                 nodesIntersectionsCoords)
    

  # when an a route between two intersections is comprised of a chain of edges.
  # the following code will join these up into a single edge.
  edgesIndirect <- edgesNoGeom %>%
    filter(!from_id %in% nodesIntersections | !to_id %in% nodesIntersections)
  
  # when there's only a direct edge between the intersections, and so can remain
  # unchanged
  edgesDirect <- edgesNoGeom %>%
    filter(from_id %in% nodesIntersections & to_id %in% nodesIntersections)
  
  # we want all of the edges, except the ones that touch an intersection
  edgesIndirect_noEdgesAtIntersections <- edgesIndirect %>%
    dplyr::select(from_id,to_id,road_type) %>%
    filter(!from_id %in% nodesIntersections & !to_id %in% nodesIntersections) %>%
    mutate(edge_id = row_number()) %>%
    dplyr::select(edge_id,from_id,to_id,road_type)
  
  # Take the edges that don't touch intersections, and make them into a graph.
  network_graph <- edgesIndirect_noEdgesAtIntersections %>%
    dplyr::select(from_id,to_id)
  
  # The nodes that make up the graph
  graph_verticies <- union(network_graph$from_id,network_graph$to_id) %>%
    sort()
  
  # Making the graph for the intersections
  g <- graph_from_data_frame(network_graph, vertices=graph_verticies,
                             directed=TRUE)
  
  ##############################################################################
  ### Finding connected components                                           ###
  ##############################################################################
  comp <- components(g)
  comp_df <- data.frame(id=as.integer(names(comp$membership)),
                        cluster_id=comp$membership, row.names=NULL)
  
  # nodes that are not part of long lines (i.e., in graph_verticies),
  # and not intersections. This is to handle routes of length 2.
  nodes_length_2 <- setdiff(nodesNoGeom$id,graph_verticies) %>%
    setdiff(nodesIntersections) %>%
    sort() %>%
    as.data.frame() %>%
    rename(id=".") %>%
    mutate(cluster_id=row_number()+max(comp_df$cluster_id))
  
  # Add them to the clusters so all non-direct edges can be fixed
  # This is just the nodes
  all_clusters <- rbind(comp_df,nodes_length_2)
  
  # Find the edges based on the nodes. Note that this WILL include edges that
  # touch intersections.
  cluster_edges <- rbind(
    edgesIndirect %>%
      inner_join(all_clusters, by=c("from_id"="id")),
    edgesIndirect %>%
      inner_join(all_clusters, by=c("to_id"="id"))
  )
  
  # most lines will have a from_id and to_id that are intersections
  clusterEndpointsDirected <- inner_join(
    cluster_edges %>%
      filter(from_id %in% nodesIntersections) %>%
      dplyr::select(from_id,cluster_id),
    cluster_edges %>%
      filter(to_id %in% nodesIntersections) %>%
      dplyr::select(to_id,cluster_id),
    by="cluster_id") %>%
    dplyr::select(cluster_id,from_id,to_id) %>%
    distinct() %>% # in case we get duplicates, which shouldn't happen
    filter(from_id != to_id) # remove loops
  
  # The cluster ids of the undirected lines
  remainingClusters <- setdiff(all_clusters$cluster_id,
                               clusterEndpointsDirected$cluster_id)
  
  # some lines don't have a from_id and to_id that are intersections, meaning
  # they have no consistent direction. We assign from_id and to_id arbitrarily.
  clusterEndpointsUndirected <- rbind(
    cluster_edges %>%
      filter(cluster_id %in% remainingClusters &
               from_id %in% nodesIntersections) %>%
      dplyr::select(node_id=from_id,cluster_id),
    cluster_edges %>%
      filter(cluster_id %in% remainingClusters &
               to_id %in% nodesIntersections) %>%
      dplyr::select(node_id=to_id,cluster_id)
  ) %>%
    group_by(cluster_id) %>%
    summarise(from_id=min(node_id),to_id=max(node_id)) %>%
    # If from_id equals to_id, then it's a loop and can be discarded
    filter(from_id != to_id)
  
  # all cluster endpoints
  clusterEndpoints <- rbind(clusterEndpointsDirected,
                            clusterEndpointsUndirected) %>%
    arrange(cluster_id)
  
  # road_type of each cluster (was previously osm_id)
  clusterOSM <- cluster_edges %>%
    group_by(cluster_id,road_type) %>%
    summarise(length=sum(length,na.rm=T)) %>%
    group_by(cluster_id) %>%
    slice(which.max(length)) %>%
    ungroup() %>%
    dplyr::select(cluster_id,road_type)
  
  # total length of each cluster
  clusterLength <- cluster_edges %>%
    rowwise() %>%
    mutate(from=min(from_id,to_id),
           to=max(from_id,to_id)) %>%
    group_by(cluster_id,from,to) %>%
    slice(which.min(length)) %>%
    ungroup() %>%
    group_by(cluster_id) %>%
    summarise(length=sum(length,na.rm=T))
  
  # making a final dataset of the simplified indirect edges
  edgesIndirect_final <- clusterEndpoints %>%
    inner_join(clusterOSM, by="cluster_id") %>%
    inner_join(clusterLength, by="cluster_id") %>%
    dplyr::select(road_type,length,from_id,to_id)
  
  allEdges <- rbind(edgesDirect,edgesIndirect_final) %>%
    # rowwise() %>%
    # older version where direction doesn't matter
    # mutate(from=min(from_id,to_id),
    #        to=max(from_id,to_id)) %>%
    # group_by(road_type,from,to) %>%
    # if multiple roads go from a to b and are of the same type, keep only the shortest
    group_by(road_type,from_id,to_id) %>%
    slice(which.min(length)) %>%
    ungroup() %>%
    # dplyr::select(-from,-to) %>%
    inner_join(nodesIntersectionsDF, by=c("from_id"="id")) %>%
    inner_join(nodesIntersectionsDF, by=c("to_id"="id")) %>%
    mutate(GEOMETRY=paste0("LINESTRING(",X.x," ",Y.x,",",X.y," ",Y.y,")")) %>%
    st_as_sf(wkt = "GEOMETRY", crs = 28355) %>%
    as.data.frame() %>%
    st_sf() %>%
    dplyr::select(road_type,length,from_id,to_id)
  
  # # add the direct edges to the simplified indirect edges, add line geometry
  # allEdges <- rbind(edgesDirect,edgesIndirect_final) %>%
  #   inner_join(nodesIntersectionsDF, by=c("from_id"="id")) %>%
  #   inner_join(nodesIntersectionsDF, by=c("to_id"="id")) %>%
  #   mutate(GEOMETRY=paste0("LINESTRING(",X.x," ",Y.x,",",X.y," ",Y.y,")")) %>%
  #   st_as_sf(wkt = "GEOMETRY", crs = 28355) %>%
  #   as.data.frame() %>%
  #   st_sf() %>%
  #   dplyr::select(road_type,length,from_id,to_id)
  
  return(list(nodesIntersectionsGeom,allEdges))
  
}
# st_write(allEdges,'data-intermediate/network3.sqlite', layer = 'links', delete_layer = T)
# st_write(nodesIntersectionsGeom,'data-intermediate/network3.sqlite', layer = 'nodes', delete_layer = T)
