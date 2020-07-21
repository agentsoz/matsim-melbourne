makeMatsimNetwork<-function(crop2TestArea=F, shortLinkLength=20, addElevation=F, 
                            addGtfs=F, addIvabmPt=F, writeXml=F, writeSqlite=T){

    # crop2TestArea=F
    # shortLinkLength=20
    # addElevation=F
    # addGtfs=F
    # addIvabmPt=F
    # writeXml=F
    # writeSqlite=T
    
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
  source('./functions/etc/logging.R')
  source('./functions/buildDefaultsDF.R')
  source('./functions/processOsmTags.R')
  source('./functions/simplifyNetwork.R')
  source('./functions/exportSQlite.R')
  source('./functions/exportXML.R')
  source('./functions/etc/getAreaBoundary.R')
  source('./functions/etc/IVABMIntegrator.R')
  source('./functions/cleanNetwork.R')
  source('./functions/gtfs2PtNetowrk.R')
  source('./functions/restructureData.R')
  source('./functions/addElevation.R')
  
  source('functions/simplifyLines.R')
  source('functions/removeDangles.R')
  source('functions/removeRedundantUndirectedEdges.R')
  source('functions/addRoadAttributes.R')
  
  message("========================================================")
  message("                **Launching Network Generation**")
  message("--------------------------------------------------------")
  
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
                                                   osm_metadata,shortLinkLength20))
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
  
  networkRestructured <- restructureData(networkAttributed)
  
  if(addElevation) system.time(networkRestructured[[1]] <- addElevation(networkRestructured[[1]], 'data/DEMx10EPSG28355.tif')) # adding elevation - comment if not needed
  if(addGtfs) system.time(networkRestructured[[2]] <- addGtfsLinks(networkRestructured[[1]], networkRestructured[[2]])) # adding psedu-network from GFTS - comment if not needed
  if(addIvabmPt) system.time(networkRestructured <- integrateIVABM(st_drop_geometry(networkRestructured[[1]]), networkRestructured[[2]])) # adding pt from IVABM - comment if not needed
  
  system.time(networkFinal <- cleanNetwork(networkRestructured, network_modes="")) # leave the network_modes empty if not needed
  
  # writing outputs ---------------------------------------------------------
  message("========================================================")
  message("|               **Launching Output Writing**           |")
  message("--------------------------------------------------------")
  
  if(writeSqlite) system.time(exportSQlite(networkFinal, outputFileName = "MATSimNetwork_test_15July"))
  if(writeXml) system.time(exportXML(networkFinal, outputFileName = "MATSimNetwork_test_15July")) # uncomment if you want xml output
}

