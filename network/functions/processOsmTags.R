processOsmTags <- function(osm_df,this_defaults_df){
  getMetadataInfo <- function(osm_tags) {
    hghw_tag <- osm_tags[1]
    other_tags <- osm_tags[2]

    freespeed=NA
    permlanes=NA
    oneway=NA
    modes=NA
    bikeway=NA
    isCycle=NA
    isWalk=NA
    isCar=NA
    if (!is.na(other_tags)) {
      tags <- str_extract_all(other_tags, boundary("word")) %>% unlist()
      cycleway_tags <- tags[which(tags %like% "cycleway")+1]
      if(any(is.na(cycleway_tags))) cycleway_tags <- c()
      bicycle_tags <- tags[which(tags=="bicycle")+1]
      if(any(is.na(bicycle_tags))) bicycle_tags <- c()
      car_tags <- tags[which(tags %in% c("car","motor_vehicle"))+1]
      if(any(is.na(car_tags))) car_tags <- c()
      foot_tags <- tags[which(tags %like% "foot")+1]
      if(any(is.na(foot_tags))) foot_tags <- c()
      
      if("maxspeed" %in% tags) freespeed=as.integer(tags[which(tags=="maxspeed")+1])/3.6
      if("lanes" %in% tags) permlanes=as.integer(tags[which(tags=="lanes")+1])
      
      if(hghw_tag=="cycleway") bikeway="bikepath"
      #if(any(bicycle_tags %in% c("yes","designated"))) bikeway="unmarked"
      if(any(cycleway_tags=="shared_lane")) bikeway="shared_lane"
      if(any(cycleway_tags=="lane") & hghw_tag!="cycleway") bikeway="lane"
      if(any(cycleway_tags=="track")& hghw_tag!="cycleway") bikeway="seperated_lane"
      if(any(car_tags=="no")) isCar=FALSE
      if(any(foot_tags=="no")) isWalk=FALSE
      if(any(foot_tags %in% c("yes","designated"))) isWalk=TRUE
      if(!is.na(bikeway) | any(bicycle_tags %in% c("yes","designated"))) isCycle=TRUE
      if(any(bicycle_tags %in% "no")) isCycle = FALSE
         
      
      
      
    }
    data.frame(freespeed=freespeed,permlanes=permlanes,bikeway=bikeway,isCycle=isCycle,isWalk=isWalk,isCar=isCar)
  }
  
  
  osmAttributed <- apply(osm_df[,c("highway","other_tags")],MARGIN = 1, getMetadataInfo)%>%bind_rows()

  
  osmAttributedWithDefaults <- cbind(osm_df,osmAttributed) %>%
    dplyr::select(-other_tags) %>%
    left_join(this_defaults_df, by=c("highway"="highwayType")) %>%
    mutate(freespeed.x=ifelse(is.na(freespeed.x),freespeed.y,freespeed.x)) %>%
    mutate(permlanes.x=ifelse(is.na(permlanes.x),permlanes.y,permlanes.x)) %>%
    mutate(isCycle.x=ifelse(is.na(isCycle.x),isCycle.y,isCycle.x)) %>%
    #mutate(bikeway=ifelse(is.na(bikeway)&isCycle.x==TRUE,"unmarked",bikeway)) %>%
    mutate(isWalk.x=ifelse(is.na(isWalk.x),isWalk.y,isWalk.x)) %>%
    mutate(isCar.x=ifelse(is.na(isCar.x),isCar.y,isCar.x)) %>%
    mutate(capacity.x = (capacity / permlanes.y) * permlanes.x ) %>% 
    dplyr::select(osm_id,highway,freespeed=freespeed.x,permlanes=permlanes.x, capacity=capacity.x,
                  bikeway,isCycle=isCycle.x,isWalk=isWalk.x,isCar=isCar.x)
  
    
    osmAttributedWithModes <- osmAttributedWithDefaults %>% 
      mutate(modes = if_else(condition = isCar, true = "car", false = NULL)) %>% 
      mutate(modes = if_else(condition = isCycle, 
                             true = if_else(condition = is.na(modes), true = "bicycle", false = paste(modes, "bicycle", sep=",")), 
                             false = modes)) %>% 
      mutate(modes = if_else(condition = isWalk, 
                             true = if_else(condition = is.na(modes), true = "walk", false = paste(modes, "walk", sep=",")), 
                             false = modes))
    
    osmAttributedCleaned  <- osmAttributedWithModes %>%
      filter(!is.na(modes) & !is.na(freespeed) & !is.na(permlanes) & !is.na(capacity)) %>%
      mutate(permlanes = replace(permlanes, permlanes == 0.0, 1.0)) %>% 
      mutate(capacity = replace(capacity, capacity == 0.0, 100.0))
                    
  return(osmAttributedCleaned)
}
