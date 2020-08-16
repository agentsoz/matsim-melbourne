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
    message(paste0("- Cropping to a test area:                        ",crop2TestArea))
   #message(paste0("- Detailed network only in the focus area:        ", focus_area_flag))
    message(paste0("- Shortest link lenght in network simplification: ", shortLinkLength))
    message(paste0("- Adding elevation:                               ", addElevation))
    message(paste0("- Adding PT from GTFS:                            ", addGtfs))
    message(paste0("- Adding PT from IV-ABM:                          ", addIvabmPt))
    message(paste0("- Writing outputs in MATSim XML format:           ", writeXml))
    message(paste0("- Writing outputs in SQLite format:               ", writeSqlite))
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
  library(purrr)
  
  #functions
  source('./functions/etc/logging.R')
  # source('./functions/simplifyNetwork.R')
  source('./functions/crop2TestArea.R')
  source('./functions/buildDefaultsDF.R')
  source('./functions/processOsmTags.R')
  source('./functions/largestConnectedComponent.R')
  source('./functions/simplifyIntersections.R')
  source('./functions/combineRedundantEdges.R')
  source('./functions/combineUndirectedAndDirectedEdges.R')
  source('./functions/simplifyLines.R')
  source('./functions/removeDangles.R')
  source('./functions/makeEdgesDirect.R')
  source('./functions/restructureData.R')
  source('./functions/adjustingBikeLinks.R')
  source('./functions/addElevation2Nodes.R')
  source('./functions/gtfs2PtNetowrk.R')
  source('./functions/etc/IVABMIntegrator.R')
  source('./functions/cleanNetwork.R')
  source('./functions/exportSQlite.R')
  source('./functions/exportXML.R')
    
  
  message("========================================================")
  message("                **Launching Network Generation**")
  message("--------------------------------------------------------")
  
  # Note: writing logical fields to sqlite is a bad idea, so switching to integers
  networkInput <- list(st_read("data/network.sqlite",layer="nodes",quiet=T),
                       st_read("data/network.sqlite",layer="edges",quiet=T))
  # select from https://github.com/JamesChevalier/cities/tree/master/australia/victoria
  if(crop2TestArea)system.time(networkInput <- crop2Poly(networkInput,
                                                         "city-of-melbourne_victoria"))  
  
  osm_metadata <- st_read("data/network.sqlite",layer="osm_metadata",quiet=T)
  defaults_df <- buildDefaultsDF()
  system.time( osmAttributes <- processOsmTags(osm_metadata,defaults_df))
  
  edgesAttributed <- networkInput[[2]] %>%
    inner_join(osmAttributes, by="osm_id") %>%
    dplyr::select(-osm_id,-highway)
  
  # keep only the largest connected component
  largestComponent <- largestConnectedComponent(networkInput[[1]],edgesAttributed)
  
  # simplify intersections while preserving attributes and original geometry.
  system.time(intersectionsSimplified <- simplifyIntersections(largestComponent[[1]],
                                                               largestComponent[[2]],
                                                               20))
  
  # Merge edges going between the same two nodes, picking the shortest geometry.
  # * One-way edges going in the same direction will be merged
  # * Pairs of one-way edges in opposite directions will be merged into a two-way edge.
  # * Two-way edges will be merged regardless of direction.
  # * One-way edges will NOT be merged with two-way edges.
  system.time(edgesCombined <- combineRedundantEdges(intersectionsSimplified[[1]],
                                                     intersectionsSimplified[[2]]))
  
  # Merge one-way and two-way edges going between the same two nodes. In these 
  # cases, the merged attributes will be two-way.
  # This guarantees that there will only be a single edge between any two nodes.
  system.time(combinedUndirectedAndDirected <- 
                combineUndirectedAndDirectedEdges(edgesCombined[[1]],
                                                  edgesCombined[[2]]))
  
  # If there is a chain of edges between intersections, merge them together
  system.time(edgesSimplified <- simplifyLines(combinedUndirectedAndDirected[[1]],
                                               combinedUndirectedAndDirected[[2]]))
  
  # Remove dangles
  system.time(noDangles <- removeDangles(edgesSimplified[[1]],edgesSimplified[[2]],500))
  
  # Do a second round of simplification. I don't think this is working properly this round.
  system.time(edgesCombined2 <- combineRedundantEdges(noDangles[[1]],
                                                      noDangles[[2]]))
  system.time(combinedUndirectedAndDirected2 <- 
                combineUndirectedAndDirectedEdges(edgesCombined2[[1]],
                                                  edgesCombined2[[2]]))
  
  # simplify geometry so all edges are straight lines
  system.time(networkDirect <- 
                makeEdgesDirect(combinedUndirectedAndDirected2[[1]],
                                combinedUndirectedAndDirected2[[2]]))
  
  # add mode to edges, add type to nodes, change bikeway from numbers to text
  networkRestructured <- restructureData(networkDirect)
  system.time(networkRestructured[[2]] <- adjustingBikeLinks(networkRestructured[[2]]))
  if(addElevation) system.time(networkRestructured[[1]] <- addElevation2Nodes(networkRestructured[[1]], 
                                                                        'data/DEMx10EPSG28355.tif'))
  if(addGtfs) system.time(networkRestructured[[2]] <- addGtfsLinks(networkRestructured[[1]], 
                                                                   networkRestructured[[2]])) 
  if(addIvabmPt) system.time(networkRestructured <- integrateIVABM(st_drop_geometry(networkRestructured[[1]]), 
                                                                   networkRestructured[[2]]))
  
  system.time(networkFinal <- cleanNetwork(networkRestructured, 
                                           network_modes="")) # leave the network_modes empty if not needed
  
  # writing outputs ---------------------------------------------------------
  message("========================================================")
  message("|               **Launching Output Writing**           |")
  message("--------------------------------------------------------")

  if(writeSqlite) system.time(exportSQlite(networkFinal, outputFileName = "MATSimMelbNetwork"))
  if(writeXml) system.time(exportXML(networkFinal, outputFileName = "MATSimMelbNetwork")) # uncomment if you want xml output
}

