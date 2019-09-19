# this is the code I used to convert the .osm file into a sqlite file
# ogr2ogr -f "SQLite" -nln lines -dsco SPATIALITE=YES -dialect SQLite -sql "SELECT * FROM lines" "/home/alan/melbourneNetwork/melbourne.sqlite" "/home/alan/melbourneNetwork/melbourne.osm"
# ogr2ogr -f "SQLite" -nln multilines -append -dsco SPATIALITE=YES -dialect SQLite -sql "SELECT * FROM multilinestrings" "/home/alan/melbourneNetwork/melbourne.sqlite" "/home/alan/melbourneNetwork/melbourne.osm"


library(sf) # for spatial things
library(dplyr)
library(data.table)


lines_filtered <- st_read("melbourne.sqlite", layer="lines") %>%
  filter(!is.na(highway) | other_tags %like% "rail" | other_tags %like% "tram" | other_tags %like% "bus") %>%
  filter(!other_tags %like% "busbar") %>% # busbar is a type of powerline, which we don't need
  filter(!other_tags %like% "abandoned") # abandoned rail lines, etc
  
multilines_filtered <- st_read("melbourne.sqlite", layer="multilines")  %>%
  filter(other_tags %like% "road" | other_tags %like% "train" | other_tags %like% "tram" | other_tags %like% "bus" | other_tags %like% "bicycle")

st_write(lines_filtered, "melbourne_filtered.sqlite",delete_layer=TRUE,layer_options=c("OVERWRITE=yes"),layer="lines")
st_write(multilines_filtered, "melbourne_filtered.sqlite",layer_options=c("OVERWRITE=yes"),layer="multilines")


bike_lines <- lines_filtered %>%
  mutate(bike=NA) %>%
  mutate(bike=ifelse(highway=="cycleway",
                     "cycleway",bike)) %>%
  mutate(bike=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"lane"' | other_tags %like% '"cycleway:left"=>"lane"'),
                     "bike lane",bike)) %>%
  mutate(bike=ifelse(highway!="cycleway" & (other_tags %like% '"cycleway"=>"track"' | other_tags %like% '"cycleway:left"=>"track"'),
                     "sep bike lane",bike)) %>%
  filter(!is.na(bike))
st_write(bike_lines, "bike_lines.sqlite",delete_layer=TRUE,layer_options=c("OVERWRITE=yes"),layer="bike_lines")

"oneway"=>"yes","surface"=>"asphalt","maxspeed"=>"40","cycleway:left"=>"lane"