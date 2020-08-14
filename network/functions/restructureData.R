# networkAttributed=networkDirect
restructureData <- function(networkAttributed){
  nodes <- networkAttributed[[1]]
  links <- networkAttributed[[2]]
  
  nodes <- nodes %>% # Changing to MATSim expected format
    mutate(x = as.numeric(sf::st_coordinates(.)[,1]),
           y = as.numeric(sf::st_coordinates(.)[,2])) %>% 
    mutate(type=if_else(as.logical(is_roundabout), 
                        true = if_else(as.logical(is_signal), 
                                       true = "signalised_roundabout",
                                       false = "simple_roundabout"), 
                        false = if_else(as.logical(is_signal), 
                                        true = "signalised_intersection",
                                        false = "simple_intersection"))) %>% 
    dplyr::select(id, x, y, type, geom) %>% 
    distinct(id, .keep_all=T)
  
  # Bike hierarchy:
  # bikepath           = 4
  # seperated_lane     = 3
  # lane               = 2
  # shared_lane        = 1
  # no_lane/no_cycling = 0

    links <- links %>%  # For the next steps it is probably faster and easier if links are not spatial objects - AJ 14 July 2020
      sf::st_coordinates() %>%
      as.data.frame() %>%
      cbind(name=c("from","to")) %>%
      tidyr::pivot_wider(names_from = name, values_from = c(X,Y)) %>% 
      cbind(st_drop_geometry(links)) %>%
      # add in mode
      mutate(modes=ifelse(                isCar==1,                          "car",    NA)) %>%
      mutate(modes=ifelse(!is.na(modes)&isCycle==1, paste(modes,"bicycle",sep=","), modes)) %>%
      mutate(modes=ifelse( is.na(modes)&isCycle==1,                      "bicycle", modes)) %>%
      mutate(modes=ifelse( !is.na(modes)&isWalk==1,    paste(modes,"walk",sep=","), modes)) %>%
      mutate(modes=ifelse(  is.na(modes)&isWalk==1,                         "walk", modes)) %>%
      # convert bikeway from numbers to text
      mutate(bikeway=ifelse(bikeway==0, NA              , bikeway)) %>%
      mutate(bikeway=ifelse(bikeway==1, "bikepath"      , bikeway)) %>%
      mutate(bikeway=ifelse(bikeway==2, "seperated_lane", bikeway)) %>%
      mutate(bikeway=ifelse(bikeway==3, "lane"          , bikeway)) %>%
      mutate(bikeway=ifelse(bikeway==4, "shared_lane"   , bikeway)) %>%
      dplyr::select(from_id, to_id, fromX=X_from, fromY=Y_from, toX=X_to, 
                    toY=Y_to, length, freespeed, permlanes, capacity, bikeway,
                    isCycle, isWalk, isCar, modes)
    
  return(list(nodes,links))
}