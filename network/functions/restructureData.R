restructureData <- function(networkAttributed){
  nodes <- networkAttributed[[1]]
  links <- networkAttributed[[2]]
  
  nodes <- nodes %>% # Changing to MATSim expected format
    mutate(x = sf::st_coordinates(.)[,1],
           y = sf::st_coordinates(.)[,2]) %>% 
    mutate(type=if_else(as.logical(is_roundabout), 
                        true = if_else(as.logical(is_signal), 
                                       true = "signalised_roundabout",
                                       false = "simple_roundabout"), 
                        false = if_else(as.logical(is_signal), 
                                        true = "signalised_intersection",
                                        false = "simple_intersection"))) %>% 
    dplyr::select(id, x, y, type, geom) %>% 
    distinct(id,.keep_all = T)

    links <- links %>%  # For the next steps it is probably faster and easier if links are not spatial objects - AJ 14 July 2020
    sf::st_coordinates() %>%
    as.data.frame() %>%
    cbind(name=c("from","to")) %>%
    tidyr::pivot_wider(names_from = name, values_from = c(X,Y)) %>% 
    cbind(st_drop_geometry(links)) %>% 
    dplyr::select(from_id, to_id, fromX=X_from, fromY=Y_from, toX=X_to, toY=Y_to, length, freespeed, permlanes, capacity, bikeway, isCycle, isWalk, isCar, modes)
  
  return(list(nodes,links))
}