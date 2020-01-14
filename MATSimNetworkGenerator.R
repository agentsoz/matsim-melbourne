#libraries
library(sf)
library(dplyr)
library(data.table)
library(stringr)
library(igraph)
library(raster)
library(XML)
library(rgdal)

#functions}
source('./functions/defaults_df_builder.R')
source('./functions/road_processor.R')
source('./functions/simplifyNetwork.R')
source('./functions/exportSQlite.R')
source('./functions/exportXML.R')

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
# NOTE elevation file needs to be in this crs already
crs_final <- 28355
# Study area
smaller_study_area <- F #Crop or not (T/F)
# Carlton CBD test area
#study_area <- st_as_sfc("SRID=7845;POLYGON((969309.8 -4294159.6, 969309.8 -4292207.1, 971316.7 -4292207.1,971316.7 -4294159.6,  969309.8 -4294159.6))")
study_area <- st_as_sfc("SRID=28355;POLYGON((318877.2 5814208.5, 321433.7 5814021.4, 321547.1 5812332.6 ,318836.3 5812083.8,  318877.2 5814208.5))")
#study_area <- study_area %>% st_transform(crs_final)

# Network simplification (T/F)
networkSimplication <- F 
# Output format (T/F)
write_xml <- T 
write_sqlite <- F

### Reading inputs
# Reading the planar input (unproccessed)
inputSQLite <- paste0(data_folder, 'melbourne.sqlite') 
lines_p <- st_read(inputSQLite , layer="roads") %>% 
  st_transform(crs_final) 

# Reading the nonplanar input (processed data by Alan)
inputSQLite_np <- paste0(data_folder, 'network.sqlite') 
# lines
lines_np <- st_read(inputSQLite_np , layer="edges") %>% 
  mutate(id = 1:n()) %>% 
  st_transform(crs_final) 
# nodes
nodes_np <- st_read(inputSQLite_np , layer="nodes") %>% 
  mutate(id = 1:n())%>% 
  st_transform(crs_final) 

# Croping to the study area
if(smaller_study_area){
  lines_p <- lines_p %>%
    filter(lengths(st_intersects(., study_area)) > 0)
  lines_np <- lines_np %>%
    filter(lengths(st_intersects(., study_area)) > 0)
}

## OSM tags processing and attributes assingment
# Creating defaults dataframe
defaults_df <- buildDefaultsDF()
# Processing the planar network and assining attributes based on defaults df and osm tags
lines_p_attrib <- processRoads(lines_p , defaults_df)
# Removing the geometries
lines_p_attrib <- lines_p_attrib %>% st_set_geometry(NULL)
# Adding attributes from the planar network to the non-planar network
lines_np <- lines_np %>%
  left_join(lines_p_attrib, by = "osm_id") %>% 
  st_set_geometry(NULL)

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
  exportSQlite(lines_np, nodes_np, outputFileName = "outputSQliteBIG")
  echo(paste0('Finished generating the sqlite output\n'))
}

if (write_xml) {
  cat('\n')
  echo(paste0('Writing the XML output: ', nrow(lines_np), ' links and ', nrow(nodes_np),' nodes\n'))
  exportXML(lines_np, nodes_np, outputFileName = "outputXMLBig")
  echo(paste0('Finished generating the xml output\n'))
}
