library(sf)
library(dplyr)

acts <- read.csv("mel2016popn100pax.xml.acts.csv")
actsCoords <- acts %>%
  dplyr::select(personId,act_id,x,y)
acts <- acts %>%
  st_as_sf(coords = c("x", "y"), crs = 28355)

legs <- read.csv("mel2016popn100pax.xml.legs.csv") %>%
  left_join(actsCoords, by=c("personId"="personId","origin_act_id"="act_id")) %>%
  left_join(actsCoords, by=c("personId"="personId","dest_act_id"="act_id"),
            suffix = c("", ".d")) %>%
  mutate(geom=paste0("LINESTRING(",x," ",y,",",x.d," ",y.d,")")) %>%
  st_as_sf(wkt = "geom", crs = 28355) %>%
  dplyr::select(X,personId,origin_act_id,dest_act_id,mode,geom) %>%
  mutate(length=round(as.numeric(st_length(geom))))
  
st_write(acts,"population.gpkg",delete_layer=TRUE,layer="acts")
st_write(legs,"population.gpkg",delete_layer=TRUE,layer="legs")
