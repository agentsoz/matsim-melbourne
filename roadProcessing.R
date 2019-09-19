
library(sf)
library(dplyr)
library(data.table)

# Defining feasible tag sets ----------------------------------------------

# Probably it is safer to control tags that we want, rather than tags we don't want
highway_tags <- c("motorway", "trunk", "primary", "secondary", "tertiary", "residential", 
                  "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link", 
                  "living_street", 	"service", "pedestrian", "track", "footway", "steps", "cycleway") 

# tags that are assumed bikes are allowed to ride
bike_feasible_tags <- c("primary", "secondary", "tertiary", "residential", "living_street", "cycleway")
# tags that are assumed bikes are allowed to ride                        
walk_feasible_tags <- c("pedestrian", "footway", "steps")

car_feasbile_tags <- c("motorway", "trunk", "primary", "secondary", "tertiary", "residential", 
                       "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link", 
                       "living_street", "service")

# Reading inputs and initial filteration ----------------------------------

lines_filtered <- st_read("../../../cloudstor/IV-ABM/networkGeneration/melbourne.sqlite", layer="lines") %>%
  filter(!is.na(highway) | other_tags %like% "rail" | other_tags %like% "tram" | other_tags %like% "bus") %>%
  filter(!other_tags %like% "busbar") %>% # busbar is a type of powerline, which we don't need
  filter(!other_tags %like% "abandoned") %>% # abandoned rail lines, etc
  filter(highway %in% highway_tags) %>%
  filter(!(highway == "service" & other_tags %like% "parking_aisle")) %>%
  filter(!other_tags %like% "private" | !other_tags %like% '"access"=>"no"')

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

st_write(lines_filtered, "../../outputs/melbourne_filtered.sqlite",delete_layer=TRUE,layer_options=c("OVERWRITE=yes"),layer="lines")
