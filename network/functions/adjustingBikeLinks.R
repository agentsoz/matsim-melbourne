adjustingBikeLinks <- function(links){
  # OSM don't record two way bikepaths, but most are.
  # As a solution I assume all bikepaths are bi-directional.
  # This function duplicates a bikepath with reverse direction
  # if there only one direction is included.
  
  #links <- networkRestructured[[2]]
  #bikePaths <- links %>% 
  #  filter(bikeway=="bikepath") 
  #test2 <- sapply(1:nrow(bikePaths),checkReverseLink)
  
  bikePaths <- links %>% filter(bikeway=="bikepath") 
  bikepaths_reverse <- bikePaths %>% 
    rename(from_id=to_id, to_id=from_id, toX=fromX, toY=fromY, fromX=toX, fromY=toY) %>% 
    #mutate(id=paste0("p_",from_id,"_",to_id,"_",row_number())) %>% 
    dplyr::select(from_id, to_id, fromX, fromY, toX, toY, length, freespeed, permlanes,
                  capacity, bikeway, isCycle, isWalk, isCar, modes)
  
  links_new <- rbind(links, bikepaths_reverse) %>% 
    mutate(tempId = paste0(from_id,"_",to_id,bikeway,modes)) %>% 
    distinct(tempId, .keep_all = T ) %>% 
    dplyr::select(-tempId)
  
    return(links_new)
  
}
