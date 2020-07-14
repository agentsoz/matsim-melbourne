makeMatsimNetwork<-function(test_area_flag=F,focus_area_flag=F,shortLinkLength=0.1,
                            add_z_flag=F,add.pt.flag=F,ivabm_pt_flag=F,write_xml=F,write_sqlite=F){
  
  # to Check with Alan
  # - Removed the cropings and flag areas as they seemed redundant now that we have small network
  # - removed bi-directional link processing as it is now done in the postgres code
  # - Removed the simplifications as they are now done elsewhere
  
  # test_area_flag=F
  # focus_area_flag=F
  # shortLinkLength=20
  # add_z_flag=F
  # add.pt.flag=F
  # ivabm_pt_flag=F
  # write_xml=F
  # write_sqlite=T
  
  message("========================================================")
  message("                **Network Generation Setting**")
  message("--------------------------------------------------------")
  message(paste0("- Cropping to a test area:                        ",test_area_flag))
  message(paste0("- Detailed network only in the focus area:        ", focus_area_flag))
  message(paste0("- Shortest link lenght in network simplification: ", shortLinkLength))
  message(paste0("- Adding elevation:                               ", add_z_flag))
  message(paste0("- Adding PT from GTFS:                            ", add.pt.flag))
  message(paste0("- Writing outputs in MATSim XML format:           ", write_xml))
  message(paste0("- Writing outputs in SQLite format:               ", write_sqlite))
  message("========================================================")
  # 
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
  
  #functions
  source('./functions/buildDefaultsDF.R')
  source('./functions/processOsmTags.R')
  source('./functions/simplifyNetwork.R')
  source('./functions/exportSQlite.R')
  source('./functions/exportXML.R')
  source('./functions/etc/getAreaBoundary.R')
  source('./functions/etc/IVABMIntegrator.R')
  source('./functions/etc/logging.R')
  source('./functions/cleanNetwork.R')
  source('./functions/gtfs2PtNetowrk.R')
  
  source('functions/simplifyLines.R')
  source('functions/removeDangles.R')
  source('functions/removeRedundantUndirectedEdges.R')
  source('functions/addRoadAttributes.R')
  
  
  # New method for simplifiying network ----------------------------------------------------------
  
  # Note: writing logical fields to sqlite is a bad idea, so switching to integers
  nodes <- st_read("data/network.sqlite",layer="nodes")
  edges <- st_read("data/network.sqlite",layer="edges")
  osm_metadata <- st_read("data/network.sqlite",layer="osm_metadata")
  
  defaults_df <- buildDefaultsDF()
  system.time( osmAttributes <- processOsmTags(osm_metadata,defaults_df))
  
  osmAttributeGroups <- osmAttributes %>%
    dplyr::select(osm_id,freespeed,permlanes,capacity,oneway,bikeway,isCycle,isWalk,isCar,modes) %>%
    group_by(freespeed,permlanes,capacity,oneway,bikeway,isCycle,isWalk,isCar) %>%
    mutate(road_type=group_indices()) %>%
    ungroup()
  road_types <- osmAttributeGroups %>%
    dplyr::select(road_type,freespeed,permlanes,capacity,oneway,bikeway,isCycle,isWalk,isCar,modes) %>%
    distinct()
  osmAttributeGroups2 <- osmAttributeGroups %>%
    dplyr::select(osm_id,road_type)
  edgesWithType <- edges %>%
    left_join(osmAttributeGroups2,by="osm_id") %>%
    dplyr::select(road_type,length,from_id,to_id) %>%
    st_sf()
  
  system.time(noDangles <- removeDangles(nodes,edgesWithType,500))
  system.time(linesSimplified <- simplifyLines(noDangles[[1]],noDangles[[2]]))
  system.time(NoDangles2 <- removeDangles(linesSimplified[[1]],
                                          linesSimplified[[2]],500))
  system.time(networkSimplified <- simplifyNetwork(NoDangles2[[1]],
                                                   NoDangles2[[2]],
                                                   osm_metadata,20))
  system.time(noRedundancies <- removeRedundantUndirectedEdges(networkSimplified[[1]],
                                                               networkSimplified[[2]],
                                                               road_types))
  system.time(linesSimplified2 <- simplifyLines(noRedundancies[[1]],
                                                noRedundancies[[2]]))
  system.time(noRedundancies2 <- removeRedundantUndirectedEdges(linesSimplified2[[1]],
                                                                linesSimplified2[[2]],
                                                                road_types))
  system.time(networkAttributed <- addRoadAttributes(noRedundancies2[[1]],
                                                     noRedundancies2[[2]],
                                                     road_types))
  
  #st_write(networkAttributed[[2]],'data/networkAttributed.sqlite', layer='links', delete_layer=T)
  #st_write(networkAttributed[[1]],'data/networkAttributed.sqlite', layer='nodes', delete_layer=T)
  
  # For simplicity for now I divide them into nodes and links, we can switch to keeping NetworkAttributed in next versions
  nodes <- networkAttributed[[1]]
  nodes <- nodes %>% # Changing to MATSim expected format
    mutate(x = sf::st_coordinates(.)[,1],
           y = sf::st_coordinates(.)[,2]) %>% 
    mutate(type=if_else(as.logical(is_roundabout), 
                        true = if_else(as.logical(is_signal), 
                                       true = "signalised_roundabout",
                                       false = "simple_roundabout"), 
                        false = if_else(as.logical(is_signal), 
                                        true = "signalised_intersection",
                                        false = "simple_intersection"))) %>% 
    dplyr::select(id, x, y, type, geom)

  links <- networkAttributed[[2]] # What happended to the OSM ID? and also highway tag - AJ 14 July 2020
    
  links <- links %>%  # For the next steps it is probably faster and easier if links are not spatial objects - AJ 14 July 2020
    sf::st_coordinates() %>%
    as.data.frame() %>%
    cbind(name=c("from","to")) %>%
    tidyr::pivot_wider(names_from = name, values_from = c(X,Y)) %>% 
    cbind(st_drop_geometry(links)) %>% 
    dplyr::select(from_id, to_id, fromX=X_from, fromY=Y_from, toX=X_to, toY=Y_to, length, freespeed, permlanes, capacity, bikeway, isCycle, isWalk, isCar, modes)
    
  ## Adding elevation
  #TODO: Fix the DEM so it covers the entire area.
  if(add_z_flag){
    elevation <- raster('data/DEMx10EPSG28355.tif') 
    nodes$z <- round(raster::extract(elevation ,as(nodes, "Spatial"),method='bilinear'))/10 # TODO Not working properly
    nodes <- nodes %>% distinct(id,.keep_all = T) # id's should be unique
  }else{
    nodes <- nodes %>% 
      distinct(id,.keep_all = T) # id's should be unique
  }

  if(add.pt.flag){
    links_pt <- gtfs2PtNetowrk(nodes) # ToDo studyRegion = st_union(st_convex_hull(nodes)) 
    links_pt <- links_pt %>% 
      mutate(oneway=1) %>% 
      dplyr::select(names(links)) # highway and id are missing at the moment, not sure if necessary  - AJ 14 July 2020
    links <- rbind(links, as.data.frame(links_pt)) %>% distinct()
  }
  
  # Cleaning before writing
  system.time(
    df <- cleanNetwork(links, nodes, "")
  ) 
  nodes<- df[[1]]
  links<- df[[2]]

  # We are not likely to use this again, will remove soon - AJ 14 July 2020
  #if(ivabm_pt_flag){
  #  df2 <-integrateIVABM(st_drop_geometry(nodes),links)
    #nodes<- df[[1]]
    #links<- df[[2]]
  #}
  
  ## writing outputs - sqlite
  if (write_sqlite) {
    cat('\n')
    echo(paste0('Writing the sqlite output: ', nrow(links), ' links and ', nrow(nodes),' nodes\n'))
    exportSQlite(links, nodes, outputFileName = "MATSimNetwork_test_14July")
    echo(paste0('Finished generating the sqlite output\n'))
  }
  
  ## writing outputs - MATSim XML
  # TODO make the xml writer dynamic based on the optional network attributes
  if (write_xml) {
    cat('\n')
    echo(paste0('Writing the XML output: ', nrow(links), ' links and ', nrow(nodes),' nodes\n'))
    exportXML(links, st_drop_geometry(nodes), outputFileName = "MATSimNetwork_test_14July", add_z_flag)
    echo(paste0('Finished generating the xml output\n'))
  }
}