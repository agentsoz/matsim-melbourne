
library(sf)
library(dplyr)
library(data.table)
source("./shp2graph/defaults_df_builder.R")
# Defining feasible tag sets ----------------------------------------------

# Default look-up table
defaults_df <- defaults_df_builder()

# Reading inputs and initial filteration ----------------------------------

#lines_filtered <- st_read("../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/sqlite/melbourne.sqlite", layer="lines") %>%
lines_filtered <- st_read("../../../../OneDrive/OneDrive - RMIT University/Data/rawSpatial/sqlite/CBD_dockland.sqlite", layer="lines") %>%
  filter(!is.na(highway) | other_tags %like% "rail" | other_tags %like% "tram" | other_tags %like% "bus") %>%
  filter(!other_tags %like% "busbar") %>% # busbar is a type of powerline, which we don't need
  filter(!other_tags %like% "abandoned") %>% # abandoned rail lines, etc
  filter(highway %in% defaults_df$highwayType) %>%
  filter(!(highway == "service" & other_tags %like% "parking_aisle")) %>%
  filter(!other_tags %like% "private" | !other_tags %like% '"access"=>"no"')

# Adding max speed --------------------------------------------------------



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

# writing outputs ---------------------------------------------------------

st_write(lines_filtered, "../../../../OneDrive/OneDrive - RMIT University/Data/processedSpatial/CBD_dockland/CBD_dockland_filtered.sqlite",delete_layer=TRUE,layer_options=c("OVERWRITE=yes"),layer="lines")
