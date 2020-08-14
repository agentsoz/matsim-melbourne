adjustingBikeLinks <- function(links){
  # OSM don't record two way bikepaths, but most are.
  # As a solution I assume all bikepaths are bi-directional.
  # This function duplicates a bikepath with reverse direction
  # if there only one direction is included.
  
  #links <- networkRestructured[[2]]
  #bikePaths <- links %>% 
  #  filter(bikeway=="bikepath") 
  #test2 <- sapply(1:nrow(bikePaths),checkReverseLink) 
  links <- purrr::map_dfr(1:nrow(bikePaths),checkReverseLink) %>% 
    rbind(links)
  
  return(links)
}

checkReverseLink <- function(x){
  bp <- bikePaths[x,]
  rvs <- bikePaths %>% 
    filter(from_id%in%bp$to_id && to_id%in%bp$from_id)
  if(nrow(rvs)==0){
    bi_bp <- bp %>%
      #mutate(modes=paste0("reversed_",from_id)) %>% 
      rename(from_id=to_id, to_id=from_id, toX=fromX, toY=fromY, fromX=toX, fromY=toY) %>% 
      #mutate(id=paste0("p_",from_id,"_",to_id,"_",row_number())) %>% 
      dplyr::select(from_id, to_id, fromX, fromY, toX, toY, length, freespeed, permlanes,
                    capacity, bikeway, isCycle, isWalk, isCar, modes)
    
    return(bi_bp)
  }
}
