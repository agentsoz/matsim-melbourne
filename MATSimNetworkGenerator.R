#libraries
library(sf)
library(lwgeom)
library(dplyr)
library(data.table)
library(stringr)
library(igraph)
library(raster)
library(XML)
library(rgdal)

#functions}
source('./functions/buildDefaultsDF.R')
source('./functions/processRoads.R')
source('./functions/simplifyNetwork.R')
source('./functions/exportSQlite.R')
source('./functions/exportXML.R')
source('./functions/getAreaBoundary.R')

echo<- function(msg) {
  cat(paste0(as.character(Sys.time()), ' | ', msg))  
}

printProgress<-function(row, total_row, char) {
  if((row-50)%%2500==0) echo('')
  cat('.')
  if(row%%500==0) cat('|')
  if(row%%2500==0) cat(paste0(char,' ', row, ' of ', total_row, '\n'))
}

## Seting control variables and directories 
# Change this based on your folder structure
data_folder <- 'D:/jafshin/cloudstor/Shared/melbNetworkScripted/' 
data_folder <- 'data/'
# NOTE elevation file needs to be in this crs already
crs_final <- 28355

# Filter to a small study area or not
smaller_study_area <- F #Crop or not (T/F) 
# Carlton CBD test area
#study_area <- st_as_sfc("SRID=7845;POLYGON((969309.8 -4294159.6, 969309.8 -4292207.1, 971316.7 -4292207.1,971316.7 -4294159.6,  969309.8 -4294159.6))")
study_area <- st_as_sfc("SRID=28355;POLYGON((318877.2 5814208.5, 321433.7 5814021.4, 321547.1 5812332.6 ,318836.3 5812083.8,  318877.2 5814208.5))")

# Have a smaller area with detailed and rest with only main roads
focus_area <- T
# Based on https://github.com/JamesChevalier/cities/tree/master/australia/victoria
selected_shire <- "australia/victoria/city-of-melbourne_victoria.poly"
focus_area_boundary <- getAreaBoundary(selected_shire, crs_final)

# Network simplification (T/F)
networkSimplication <- F 

# Specifiying which output format wanted (T/F)
write_xml <- T 
write_sqlite <- T

### Reading inputs
# Reading the planar input (unproccessed)
osm_metadata <- st_read(paste0(data_folder, 'melbourne.sqlite'),layer="roads")%>%st_drop_geometry()
# inputSQLite <- paste0(data_folder, 'melbourne.sqlite') 
# lines_p <- st_read(inputSQLite , layer="roads") %>% 
#   st_transform(crs_final) %>% 
#   mutate(detailed =  ifelse(lengths(st_intersects(., focus_area_boundary)) > 0,  "Yes",
#                             ifelse(focus_area, "No", "Yes")))


# Reading the nonplanar input (processed data by Alan)
inputSQLite_np <- paste0(data_folder, 'network.sqlite') 
# lines
lines_np <- st_read(inputSQLite_np , layer="edges")
  # mutate(id = paste0(from_id,"_",to_id))
# nodes
nodes_np <- st_read(inputSQLite_np , layer="nodes") #nodes already has an id

# making the simplified network
if (networkSimplication){
  # node clusters based on those that are connected with link with less than 10 meters length
  df <- simplifyNetwork(lines_np, nodes_np, osm_metadata, shortLinkLength = 20)
  nodes_p <- df[[1]]
  lines_p <- df[[2]]
}

# write simplified network to file
st_write(lines_p,"data/networkSimplified.sqlite",delete_layer=TRUE,layer="edges")
st_write(nodes_p,"data/networkSimplified.sqlite",delete_layer=TRUE,layer="nodes")


# Croping to the study area
if(smaller_study_area){
  nodes_p <- nodes_p %>%
    filter(lengths(st_intersects(., study_area)) > 0)
  lines_p <- lines_p %>%
    filter(from_id%in%nodes_p$to_id & to_id%in%nodes_p$to_id)
}

## OSM tags processing and attributes assingment
osm_metadata <- osm_metadata %>% filter(osm_id%in%lines_p$osm_id)
# Creating defaults dataframe
defaults_df <- buildDefaultsDF()
# Processing the planar network and assining attributes based on defaults df and osm tags
system.time(
  osm_attrib <- processOsmTags(osm_metadata, defaults_df)
)
#   user  system elapsed 
# 79.248   0.020  79.249 

lines_p_attrib <- lines_p %>%
  left_join(osm_attrib, by="osm_id")
st_write(lines_p_attrib,"data/networkSimplifiedAttributed.sqlite",delete_layer=TRUE,layer="edges")



#TODO: Add in the PT network generation here. Fix the DEM so it covers the entire area.










## Adding elevation
# Reading elevation raster file
elevation <- raster(paste0(data_folder, 'DEMs/DEMx10EPSG28355.tif')) 
#projectRaster(elevation, crs=CRS(paste("+init=epsg:", crs_final, sep = "")))
#writeRaster(elevation, filename="./DEMx10EPSG28355.tif", format="GTiff", overwrite=TRUE)
# Assiging z coordinations to nodes
nodes_np$z <- round(raster::extract(elevation ,as(nodes_np, "Spatial"),method='bilinear'))/10 # TODO Not working properly
# replacing NA z coords to 10
nodes_np <- nodes_np %>%
  mutate(z = ifelse(test = is.na(z)
                    ,yes = 10,
                    no = z))

# Converting nodes geometry to x and y columns
nodes_np[,c("x", "y")] <- do.call(rbind, st_geometry(nodes_np)) %>% 
  as_tibble() %>% setNames(c("x","y"))
# rearranging nodes dataframe
nodes_np <- nodes_np %>% dplyr::select(id, x, y, z, GEOMETRY)

if (networkSimplication){
  # node clusters based on those that are connected with link with less than 10 meters lenght
  df <- simplifyNetwork(lines_np, nodes_np, shortLinkLength = 10)
  nodes_np <- df[[1]]
  lines_np <- df[[2]]
}

lines_np <- lines_np %>% filter(!is.na(freespeed)) %>% filter(from_id != to_id) # removing those that there was no match in planar dataframe and those links that 
nodes_np <- nodes_np %>% filter(id %in% lines_np$from_id | id %in% lines_np$to_id ) %>% distinct(id, x, y, z)# removing links that their nodes are removed

if (write_sqlite) {
  cat('\n')
  echo(paste0('Writing the sqlite output: ', nrow(lines_np), ' links and ', nrow(nodes_np),' nodes\n'))
  exportSQlite(lines_np, nodes_np, outputFileName = "outputSQliteFocusedCoM")
  echo(paste0('Finished generating the sqlite output\n'))
}

if (write_xml) {
  cat('\n')
  echo(paste0('Writing the XML output: ', nrow(lines_np), ' links and ', nrow(nodes_np),' nodes\n'))
  exportXML(lines_np, nodes_np, outputFileName = "outputXMLBig")
  echo(paste0('Finished generating the xml output\n'))
}
