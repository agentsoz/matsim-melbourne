processOsmTags <- function(osm_df,this_defaults_df){
  # osm_df <- osm_metadata
  # this_defaults_df <- defaults_df
  
  osmWithDefaults <- inner_join(osm_df,this_defaults_df,by="highway")
  # pre splitting the tags to save time
  tagList <- strsplit(gsub('=>',',', gsub('"', '', osmWithDefaults$other_tags)),',')
  
  osmWithDefaults <- osmWithDefaults %>%
    mutate(oneway=1, # Assuming 1 means two ways and 2 means two ways
           bikeway=ifelse(highway=="cycleway","bikepath",NA)) %>%
    dplyr::select(osm_id,highway,freespeed,permlanes,capacity,oneway,bikeway,isCycle,isWalk,isCar)
  
  getMetadataInfo <- function(i) {
    df <- osmWithDefaults[i,]
    tags=tagList[[i]]
    
    if (length(tags)>1) {
      
      cycleway_tags <- tags[which(tags %like% "cycleway")+1]
      if(any(is.na(cycleway_tags))) cycleway_tags <- c()
      bicycle_tags <- tags[which(tags=="bicycle")+1]
      if(any(is.na(bicycle_tags))) bicycle_tags <- c()
      car_tags <- tags[which(tags %in% c("car","motor_vehicle"))+1]
      if(any(is.na(car_tags))) car_tags <- c()
      foot_tags <- tags[which(tags %like% "foot")+1]
      if(any(is.na(foot_tags))) foot_tags <- c()
      oneway_tags <-  as.character(tags[which(tags=="oneway")+1])
      if(length(oneway_tags)==0) oneway_tags <- c()
      
      if("maxspeed" %in% tags) {
        freeSpeed=as.integer(tags[which(tags=="maxspeed")+1])/3.6
        # added is.na since one of the maxspeed has a value of "50; 40"
        if(!is.na(freeSpeed)) {
          df$freespeed[1]=freeSpeed
        }
      }
      if("lanes" %in% tags) {
        newLanes=as.integer(tags[which(tags=="lanes")+1])
        # some osm tags set the number of lanes to zero
        # added is.na since one of the lanes has a value of "2; 3"
        if(!is.na(newLanes) & newLanes > 0) {
          # recalibrating the capacity
          df$capacity[1]= df$capacity[1] * (newLanes/df$permlanes[1])
          df$permlanes[1]=newLanes
        }
      }
      
      if(any(oneway_tags=="yes")) df$oneway[1]=2
      #if(any(bicycle_tags %in% c("yes","designated"))) df$bikeway[1]="unmarked"
      if(any(cycleway_tags=="shared_lane")) df$bikeway[1]="shared_lane"
      if(any(cycleway_tags=="lane") & df$highway[1]!="cycleway") df$bikeway[1]="lane"
      if(any(cycleway_tags=="track")& df$highway[1]!="cycleway") df$bikeway[1]="seperated_lane"
      if(any(car_tags=="no")) df$isCar[1]=FALSE
      if(any(foot_tags=="no")) df$isWalk[1]=FALSE
      if(any(foot_tags %in% c("yes","designated"))) df$isWalk[1]=TRUE
      if(!is.na(df$bikeway[1]) | any(bicycle_tags %in% c("yes","designated"))) df$isCycle[1]=TRUE
      if(any(bicycle_tags %in% "no")) df$isCycle[1] = FALSE
    }
    return(df)
  }
  
  osmAttributed <- lapply(1:nrow(osmWithDefaults),getMetadataInfo)%>%bind_rows()
  
  osmAttributedWithModes <- osmAttributed %>% 
    mutate(modes = if_else(condition = isCar, true = "car", false = NULL)) %>% 
    mutate(modes = if_else(condition = isCycle, 
                           true = if_else(condition = is.na(modes), true = "bicycle", false = paste(modes, "bicycle", sep=",")), 
                           false = modes)) %>% 
    mutate(modes = if_else(condition = isWalk, 
                           true = if_else(condition = is.na(modes), true = "walk", false = paste(modes, "walk", sep=",")), 
                           false = modes))
  
  # this code probably isn't needed anymore as it's been implemented in the getMetadataInfo function
  # osmAttributedCleaned  <- osmAttributedWithModes %>%
  #   filter(!is.na(modes) & !is.na(freespeed) & !is.na(permlanes) & !is.na(capacity)) %>%
  #   mutate(permlanes = replace(permlanes, permlanes == 0.0, 1.0)) %>% 
  #   mutate(capacity = replace(capacity, capacity == 0.0, 100.0))
  
  return(osmAttributedWithModes)
}
