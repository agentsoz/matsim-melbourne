road_processor <- function(this_lines_p ,this_defaults_df){
  # Filters roads and converting from OSM format to the desired dataframe format

  this_lines_p <- lines_p
  this_defaults_df <- defaults_df

  this_lines_p <-this_lines_p %>%
    #this_lines_p <- st_read(, layer="lines") %>%
    filter(!is.na(highway) | other_tags %like% "rail" | other_tags %like% "tram" | other_tags %like% "bus") %>%
    filter(!other_tags %like% "busbar") %>% # busbar is a type of powerline, which we don't need
    filter(!other_tags %like% "abandoned") %>% # abandoned rail lines, etc
    filter(highway %in% this_defaults_df$highwayType) %>%
    filter(!(highway == "service" & other_tags %like% "parking_aisle")) %>%
    filter(!other_tags %like% "private" | !other_tags %like% '"access"=>"no"') %>%
    mutate(osm_id=as.numeric(as.character(osm_id)))

  # Processing the "other_tags"  --------------------------------------------------
  for (i in 1:nrow(this_lines_p)){
    this_other_tags <- str_extract_all(this_lines_p$other_tags[i], boundary("word"))
    
    this_default_row <- which(this_defaults_df$highwayType == as.character(this_lines_p$highway[i]))
    
    # FreeSpeed
    has_speed <- any(grepl('"maxspeed"', this_other_tags))
    if(has_speed){
      # Reading from OSM
      this_loc <- as.integer(which(grepl("^maxspeed$", this_other_tags[[1]])))
      if(!is.na(as.integer(this_other_tags[[1]][this_loc + 1]))){
        this_lines_p[i, "freespeed"] <- as.integer(this_other_tags[[1]][this_loc + 1])/3.6
      }else{
        # Reading from defaults if unusul entry
        this_lines_p[i, "freespeed"]  <- this_defaults_df[this_default_row, "freespeed"]
      }
    }else{
      # Reading from defaults
      this_lines_p[i, "freespeed"]  <- this_defaults_df[this_default_row, "freespeed"]
    }
    
    # PermLanes
    has_lanes <- any(grepl('"lanes"', this_other_tags))
    if(has_lanes){
      # Reading from OSM
      this_loc <- as.integer(which(grepl("^lanes$", this_other_tags[[1]])))
      this_lines_p[i, "permlanes"] <- this_other_tags[[1]][this_loc + 1]
    }else{
      # Reading from defaults
      this_lines_p[i, "permlanes"]  <- this_defaults_df[this_default_row, "permlanes"]
    }
    
    # TODO ? Capacity = (Default Capacity / Default #Lanes)*Actual #Lanes
    this_cap_per_lane <- this_defaults_df[this_default_row, "capacity"] / this_defaults_df[this_default_row, "permlanes"]
    
    this_lines_p[i, "capacity"] <- as.integer(this_lines_p$permlanes[i]) * this_cap_per_lane
  }
  
  # Adding bicycle infrastructure -------------------------------------------
  
  # 	"cycleway"=>"shared_lane" ! There are tags that we are missing! This was not relevant
  
  this_lines_p <- this_lines_p %>% 
    mutate(bikeway=NA) %>%
    mutate(bikeway=ifelse(highway=="cycleway", 
                          "bikepath",bikeway)) %>%
    mutate(bikeway=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"lane"' | other_tags %like% '"cycleway:left"=>"lane"' | other_tags %like% '"cycleway:both"=>"lane"'),
                          "lane",bikeway)) %>%
    mutate(bikeway=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"track"' | other_tags %like% '"cycleway:left"=>"track"'),
                          "seperated_lane",bikeway))
  
  # Adding modes ------------------------------------------------------------
  
  this_lines_p$highway <- this_lines_p$highway  %>% as.character()
  
  # Bicycle
  
  for (i in 1:nrow(this_lines_p)){
    this_lines_p[i, "default_modes"] <- this_defaults_df$modes[which(this_defaults_df$highwayType %in% this_lines_p$highway[i])]
  }
  
  this_lines_p <- this_lines_p %>% 
    mutate(modes = NA) %>%
    mutate(modes = ifelse(test = grepl("bike" , default_modes) & !(other_tags %like% '"bicycle"=>"no"'), 
                          yes = "bike", 
                          no = ifelse(test = other_tags%like%'"bicycle"=>"yes"' | other_tags%like%'"bicycle"=>"designated"', 
                                      yes = "bike",
                                      no =  ifelse(test = !is.na(bikeway),
                                                   yes = "bike", 
                                                   no = NA)))) 
  
  this_lines_p <- this_lines_p %>%
    mutate(modes = ifelse(test = grepl("car" , default_modes) & !(other_tags %like% '"car"=>"no"') & !(other_tags %like% '"motor_vehicle"=>"no"'), 
                          yes = ifelse(test = is.na(modes), 
                                       yes = "car", 
                                       no = paste(modes, "car",sep = ", ")
                          ), 
                          no = modes)) 
  
  this_lines_p <- this_lines_p %>%
    mutate(modes = ifelse(test = grepl("walk" , default_modes) & !(other_tags %like% '"foot"=>"no"'), 
                          yes = ifelse(test = is.na(modes),
                                       yes = "walk", 
                                       no = paste(modes, "walk",sep = ", ")), 
                          no = ifelse(test = other_tags%like%'"foot"=>"yes"' | other_tags%like%'"foot"=>"designated"',
                                      yes = ifelse(test = is.na(modes), 
                                                   yes = "walk", 
                                                   no = paste(modes, "walk",sep = ", ")),
                                      no = modes)))
  
  # Adding bridge or tunnel
  
  #this_lines_p <- this_lines_p %>%
  #                    mutate(nonplanarity = ifelse(test = other_tags %like% 'bridge', 
  #                                                 yes = "bridge", 
  #                                                 no = ifelse(test = other_tags %like% 'tunnel',
  #                                                             yes = "tunnel",
  #                                                             no = "flat")))
  
  # Timming the data --------------------------------------------------------
  
  this_lines_p <- this_lines_p %>%
    dplyr::select(osm_id, highway, freespeed, permlanes, capacity, bikeway, modes, GEOMETRY)
  
  
  return(this_lines_p)
  
}