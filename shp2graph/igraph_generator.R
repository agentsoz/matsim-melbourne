igraph_generator <- function(node_list, edge_list, attribs_df = NULL){
  
  # creating a graph from list of edges
  my_graph <- graph_from_edgelist(edge_list[,c(2,3)], directed=FALSE)
  
  # Adding x and y coordinates
  my_graph<- set_vertex_attr(my_graph,"x", V(my_graph), Nodes.coordinates(node_list)[,1])
  my_graph<- set_vertex_attr(my_graph,"y", V(my_graph), Nodes.coordinates(node_list)[,2])
  
  #Extracting edges of the graph
  my_graph_edges <- E(my_graph)
  
  # Adding edge attributes, if available
  if(is.null(attribs_df)){
    warning("Link attributes are not provided")
  }else{
    eanms<-colnames(attribs_df)
    n <- length(eanms)
    for (i in 1:n){
      my_graph<-set.edge.attribute(my_graph, eanms[i], my_graph_edges, as.character(attribs_df[,i]))
    }
  }
  return(my_graph)
}