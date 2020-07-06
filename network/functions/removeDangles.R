
removeDangles <- function(nodes,edges,edgeLength){
  # nodes=linesSimplified[[1]]
  # edges=linesSimplified[[2]]
  # edgeLength=500
  numberOfEdges=-1
  edgesNoDangles <- edges %>%
    st_drop_geometry() %>%
    rowwise() %>%
    mutate(from=min(from_id,to_id),
           to=max(from_id,to_id)) %>%
    dplyr::select(from,to,length) %>%
    # a to b and b to a might have different lengths
    group_by(from,to) %>%
    summarise(length=max(length)) %>%
    as.data.table()
  
  while(numberOfEdges!=nrow(edgesNoDangles)) {
    numberOfEdges <- nrow(edgesNoDangles)
    # make a table consisting of the from and to ids, group by id, select the ids that only have a count of 1
    nodesThatTerminate <- data.table(id=c(edgesNoDangles$from,edgesNoDangles$to))[, .N,by="id"][N==1,id]
    
    edgesNoDangles <- edgesNoDangles %>%
      filter(length > edgeLength |
               (!from %in% nodesThatTerminate & !to %in% nodesThatTerminate))
  }
  validNodes <- union(edgesNoDangles$from,edgesNoDangles$to)
  nodesNoDangles <- nodes %>%
    filter(id %in% validNodes) %>%
    st_sf()
  
  edgesNoDanglesDF <- edges %>%
    filter(from_id %in% validNodes & to_id %in% validNodes) %>%
    st_sf()
  return(list(nodesNoDangles,edgesNoDanglesDF))

}