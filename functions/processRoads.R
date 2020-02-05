
processOsmTags <- function(osm_df,this_defaults_df){

  getMetadataInfo <- function(other_tags) {
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
      if(any(bicycle_tags %in% c("yes","designated"))) bikeway="unmarked"
      if(any(cycleway_tags=="shared_lane")) bikeway="shared_lane"
      if(any(cycleway_tags=="lane")) bikeway="lane"
      if(any(cycleway_tags=="track")) bikeway="track"
      if(any(car_tags=="no")) isCar=FALSE
      if(any(foot_tags=="no")) isWalk=FALSE
      if(any(foot_tags %in% c("yes","designated"))) isWalk=TRUE
      if(!is.na(bikeway)) isCycle=TRUE
    }
    data.frame(freespeed=freespeed,permlanes=permlanes,bikeway=bikeway,isCycle=isCycle,isWalk=isWalk,isCar=isCar)
  }
  
  osmAttributed <- lapply(osm_df$other_tags, getMetadataInfo)%>%bind_rows()

  osmAttributedWithDefaults <- cbind(osm_df,osmAttributed) %>%
    dplyr::select(-other_tags) %>%
    left_join(this_defaults_df, by=c("highway"="highwayType")) %>%
    mutate(freespeed.x=ifelse(is.na(freespeed.x),freespeed.y,freespeed.x)) %>%
    mutate(permlanes.x=ifelse(is.na(permlanes.x),permlanes.y,permlanes.x)) %>%
    mutate(isCycle.x=ifelse(is.na(isCycle.x),isCycle.y,isCycle.x)) %>%
    mutate(bikeway=ifelse(is.na(bikeway)&isCycle.x==TRUE,"unmarked",bikeway)) %>%
    mutate(isWalk.x=ifelse(is.na(isWalk.x),isWalk.y,isWalk.x)) %>%
    mutate(isCar.x=ifelse(is.na(isCar.x),isCar.y,isCar.x)) %>%
    dplyr::select(osm_id,highway,freespeed=freespeed.x,permlanes=permlanes.x,
                  bikeway,isCycle=isCycle.x,isWalk=isWalk.x,isCar=isCar.x)
  
  return(osmAttributedWithDefaults)
}
