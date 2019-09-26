igraph_generator <- function(node_list, edge_list, attribs_df = NULL){
  
  # creating a graph from list of edges
  my_graph <- graph_from_edgelist(edgelist[,c(2,3)], directed=FALSE)
  
  # Adding x and y coordinates
  my_graph<- set_vertex_attr(my_graph,"x", V(my_graph), Nodes.coordinates(nodelist)[,1])
  my_graph<- set_vertex_attr(my_graph,"y", V(my_graph), Nodes.coordinates(nodelist)[,2])
  
  #Extracting edges of the graph
  my_graph_edges <- E(my_graph)
  
  # Adding edge attributes, if available
  if(is.null(eadf)){
    warning("Link attributes are not provided")
  }else{
    eanms<-colnames(eadf)
    n <- length(eanms)
    for (i in 1:n){
      my_graph<-set.edge.attribute(my_graph, eanms[i], my_graph_edges, as.character(eadf[,i]))
    }
  }
  

  return(my_graph)
}