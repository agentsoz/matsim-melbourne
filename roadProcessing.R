# 2. Filtering roads and converting from OSM format to desired dataframe format

library(sf)
library(dplyr)
library(data.table)
library(stringr)
library(igraph)
library(raster)

source("./functions/defaults_df_builder.R")

#crs_final <- 7845
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"
osm_extract <- "carltonSingleBlock"
#osm_extract <- "melbourne"

inputSQLite <- paste(oneDriveURL, "/Data/processedSpatial/", osm_extract,"/",osm_extract,"_croped.sqlite", sep = "") 
outputSQLite <- paste(oneDriveURL, "/Data/processedSpatial/", osm_extract,"/",osm_extract,"_filtered.sqlite", sep = "")
# Defining feasible tag sets ----------------------------------------------

# Default look-up table
defaults_df <- defaults_df_builder()

# Reading inputs and initial filteration ----------------------------------

lines_filtered <- st_read(inputSQLite , layer="lines") %>%
#lines_filtered <- st_read(, layer="lines") %>%
  filter(!is.na(highway) | other_tags %like% "rail" | other_tags %like% "tram" | other_tags %like% "bus") %>%
  filter(!other_tags %like% "busbar") %>% # busbar is a type of powerline, which we don't need
  filter(!other_tags %like% "abandoned") %>% # abandoned rail lines, etc
  filter(highway %in% defaults_df$highwayType) %>%
  filter(!(highway == "service" & other_tags %like% "parking_aisle")) %>%
  filter(!other_tags %like% "private" | !other_tags %like% '"access"=>"no"')

# Adding link lenght ------------------------------------------------------
# It is for the all 
#lines_filtered <- lines_filtered %>%
#                  mutate(lenght = st_length(lines_filtered$geometry)) 
#plot(lines_filtered["lenght"])

#object.size(lines_filtered)

#lines_filtered_simple <- st_simplify(lines_filtered, preserveTopology = T, dTolerance = 100)

#object.size(lines_filtered_simple)

#plot(lines_filtered_simple["lenght"])

# Converting the Coordinates
#lines_filtered <- st_transform(lines_filtered, crs_final)


# Processing the "other_tags"  --------------------------------------------------

for (i in 1:nrow(lines_filtered)){
  this_other_tags <- str_extract_all(lines_filtered$other_tags[i], boundary("word"))
  
  this_default_row <- which(defaults_df$highwayType == as.character(lines_filtered$highway[i]))
  
  # FreeSpeed
  has_speed <- any(grepl('"maxspeed"', this_other_tags))
  if(has_speed){
    # Reading from OSM
    this_loc <- as.integer(which(grepl("^maxspeed$", this_other_tags[[1]])))
    if(!is.na(as.integer(this_other_tags[[1]][this_loc + 1]))){
      lines_filtered[i, "freespeed"] <- as.integer(this_other_tags[[1]][this_loc + 1])/3.6
    }else{
      # Reading from defaults if unusul entry
      lines_filtered[i, "freespeed"]  <- defaults_df[this_default_row, "freespeed"]
    }
  }else{
    # Reading from defaults
    lines_filtered[i, "freespeed"]  <- defaults_df[this_default_row, "freespeed"]
  }
  
  # PermLanes
  has_lanes <- any(grepl('"lanes"', this_other_tags))
  if(has_lanes){
    # Reading from OSM
    this_loc <- as.integer(which(grepl("^lanes$", this_other_tags[[1]])))
    lines_filtered[i, "permlanes"] <- this_other_tags[[1]][this_loc + 1]
  }else{
    # Reading from defaults
    lines_filtered[i, "permlanes"]  <- defaults_df[this_default_row, "permlanes"]
  }
  
  # TODO Capacity = (Default Capacity / Default #Lanes)*Actual #Lanes
  this_cap_per_lane <- defaults_df[this_default_row, "capacity"] / defaults_df[this_default_row, "permlanes"]
  
  lines_filtered[i, "capacity"] <- as.integer(lines_filtered$permlanes[i]) * this_cap_per_lane
}

# Adding bicycle infrastructure -------------------------------------------

# 	"cycleway"=>"shared_lane" ! There are tags that we are missing! This was not relevant

lines_filtered <- lines_filtered %>% 
                  mutate(bikeway=NA) %>%
                  mutate(bikeway=ifelse(highway=="cycleway", 
                                         "bikepath",bikeway)) %>%
                  mutate(bikeway=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"lane"' | other_tags %like% '"cycleway:left"=>"lane"' | other_tags %like% '"cycleway:both"=>"lane"'),
                                         "lane",bikeway)) %>%
                  mutate(bikeway=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"track"' | other_tags %like% '"cycleway:left"=>"track"'),
                                     "seperated_lane",bikeway))

# Adding modes ------------------------------------------------------------

lines_filtered$highway <- lines_filtered$highway  %>% as.character()

# Bicycle

for (i in 1:nrow(lines_filtered)){
  lines_filtered[i, "default_modes"] <- defaults_df$modes[which(defaults_df$highwayType %in% lines_filtered$highway[i])]
}

lines_filtered <- lines_filtered %>% 
                    mutate(modes = NA) %>%
                    mutate(modes = ifelse(test = grepl("bike" , default_modes) & !(other_tags %like% '"bicycle"=>"no"'), 
                                          yes = "bike", 
                                          no = ifelse(test = other_tags%like%'"bicycle"=>"yes"' | other_tags%like%'"bicycle"=>"designated"', 
                                                      yes = "bike",
                                                      no =  ifelse(test = !is.na(bikeway),
                                                                   yes = "bike", 
                                                                   no = NA)))) 

lines_filtered <- lines_filtered %>%
                    mutate(modes = ifelse(test = grepl("car" , default_modes) & !(other_tags %like% '"car"=>"no"') & !(other_tags %like% '"motor_vehicle"=>"no"'), 
                                           yes = ifelse(test = is.na(modes), 
                                                        yes = "car", 
                                                        no = paste(modes, "car",sep = ", ")
                                                        ), 
                                           no = modes)) 

lines_filtered <- lines_filtered %>%
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

lines_filtered <- lines_filtered %>%
                    mutate(nonplanarity = ifelse(test = other_tags %like% 'bridge', 
                                                 yes = "bridge", 
                                                 no = ifelse(test = other_tags %like% 'tunnel',
                                                             yes = "tunnel",
                                                             no = "flat")))

# Timming the data --------------------------------------------------------

lines_filtered <- lines_filtered %>%
                    dplyr::select(osm_id, name, highway, freespeed, permlanes, capacity, bikeway, modes, nonplanarity, geometry)



# writing outputs ---------------------------------------------------------

st_write(lines_filtered, outputSQLite, layer = "lines", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")
