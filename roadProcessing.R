
library(sf)
library(dplyr)
library(data.table)
library(stringr)

source("./shp2graph/defaults_df_builder.R")

crs_final <- 28355

inputSQLite <- "../../../OneDrive/Data/rawSpatial/osmExtracts/CBD_dockland.osm"
# inputSQLite <-"../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/sqlite/CBD_dockland.sqlite"
outputSQLite <- "../../../OneDrive/Data/processedSpatial/CBD_dockland/CBD_dockland_filtered.sqlite"
#outputSQLite <- "../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/CBD_dockland/CBD_dockland_filtered.sqlite"
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
lines_filtered <- lines_filtered %>%
                  mutate(lenght = st_length(lines_filtered$geometry))

plot(lines_filtered["lenght"])

object.size(lines_filtered)

lines_filtered_simple <- st_simplify(lines_filtered, preserveTopology = T, dTolerance = 100)

object.size(lines_filtered_simple)

plot(lines_filtered_simple["lenght"])

# Processing the "other_tags"  --------------------------------------------------

for (i in 1:nrow(lines_filtered)){
  this_other_tags <- str_extract_all(lines_filtered$other_tags[i], boundary("word"))
  
  # FreeSpeed
  has_speed <- any(grepl('"maxspeed"', this_other_tags))
  if(has_speed){
    # Reading from OSM
    this_loc <- as.integer(which(grepl("^maxspeed$", this_other_tags[[1]])))
    if(!is.na(as.integer(this_other_tags[[1]][this_loc + 1]))){
      lines_filtered[i, "freespeed"] <- as.integer(this_other_tags[[1]][this_loc + 1])/3.6
    }else{
      # Reading from defaults if unusul entry
      this_loc <- which(defaults_df$highwayType == as.character(lines_filtered$highway[i]))
      lines_filtered[i, "freespeed"]  <- defaults_df[this_loc, "freespeed"]
    }
  }else{
    # Reading from defaults
    this_loc <- which(defaults_df$highwayType == as.character(lines_filtered$highway[i]))
    lines_filtered[i, "freespeed"]  <- defaults_df[this_loc, "freespeed"]
  }
  
  # PermLanes
  has_lanes <- any(grepl('"lanes"', this_other_tags))
  if(has_lanes){
    # Reading from OSM
    this_loc <- as.integer(which(grepl("^lanes$", this_other_tags[[1]])))
    lines_filtered[i, "permlanes"] <- this_other_tags[[1]][this_loc + 1]
  }else{
    # Reading from defaults
    this_loc <- which(defaults_df$highwayType == as.character(lines_filtered$highway[i]))
    lines_filtered[i, "permlanes"]  <- defaults_df[this_loc, "permlanes"]
  }
  
  # TODO Capacity ??
}

# Adding bicycle infrastructure -------------------------------------------

lines_filtered <- lines_filtered %>% 
                  mutate(bikeway=NA) %>%
                  mutate(bikeway=ifelse(highway=="cycleway", 
                                         "bikepath",bikeway)) %>%
                  mutate(bikeway=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"lane"' | other_tags %like% '"cycleway:left"=>"lane"'),
                                         "lane",bikeway)) %>%
                  mutate(bikeway=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"track"' | other_tags %like% '"cycleway:left"=>"track"'),
                                     "seperated_lane",bikeway))

# Adding modes ------------------------------------------------------------


# Bicycle
lines_filtered <- lines_filtered %>% 
                  mutate(modes = NA) %>%
                  mutate(modes = ifelse("bike" %like% defaults_df$modes[which(defaults_df$highwayType == as.character(highway))] & !(other_tags %like% '"bicycle"=>"no"'), 
                                        "bike",
                                        modes)) %>%
  mutate(modes = ifelse("car" %like% defaults_df$modes[which(defaults_df$highwayType == as.character(highway))] & !(other_tags %like% '"car"=>"no"'), 
                        paste(modes, "car",sep = ", "),
                        modes)) 

                                  mutate(modes=ifelse(highway %in% bike_feasible_tags & !(other_tags %like% '"bicycle"=>"no"'), 
                        "bicycle",NA)) %>% # High hierarchy roads that bike are not allowed
                  mutate(modes=ifelse(other_tags%like%'"bicycle"=>"yes"' | other_tags%like%'"bicycle"=>"designated"' & !(modes %like% "bicycle"), 
                        "bicycle",modes)) # 
# Car
lines_filtered <- lines_filtered %>% 
  mutate(modes=ifelse(highway %in% car_feasbile_tags, 
                      ifelse(is.na(modes), "car", paste(modes, "car",sep = ", ")),
                      modes))
# Walk
lines_filtered <- lines_filtered %>% 
                  mutate(modes=ifelse(highway %in% walk_feasible_tags & !(other_tags %like% '"foot"=>"no"'), 
                                      ifelse(is.na(modes), "walk", paste(modes, "walk",sep = ", ")),
                                      modes)) %>%
                  mutate(modes=ifelse(other_tags%like%'"foot"=>"yes"' | other_tags%like%'"foot"=>"designated"' & !(modes %like% "walk"),
                                      ifelse(is.na(modes), "walk", paste(modes, "walk",sep = ", ")),
                                      modes))



# Timming the data --------------------------------------------------------

lines_filtered <- lines_filtered %>%
                  select()

# writing outputs ---------------------------------------------------------

st_write(lines_filtered, outputSQLite,layer="lines", driver = "SQLite", layer_options = "GEOMETRY=AS_XY")
