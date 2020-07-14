makeMatsimNetwork<-function(test_area_flag=F,focus_area_flag=F,shortLinkLength=0.1,
                            add_z_flag=F,add.pt.flag=F,ivabm_pt_flag=F,write_xml=F,write_sqlite=F){
  
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
  source('./functions/addRoadAttributes.R')
  
  
  
  
  
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
  
  st_write(networkAttributed[[2]],'data/networkAttributed.sqlite', layer='links', delete_layer=T)
  st_write(networkAttributed[[1]],'data/networkAttributed.sqlite', layer='nodes', delete_layer=T)
  
  
  
  
  
  
  
  # Adjusting boundaries  -------------------------------
  
  test_area_boundary <- st_as_sfc("SRID=28355;POLYGON((318877.2 5814208.5, 321433.7 5814021.4, 321547.1 5812332.6 ,318836.3 5812083.8,  318877.2 5814208.5))")
  
  # https://github.com/JamesChevalier/cities/tree/master/australia/victoria
  focus_area_shire <- "australia/victoria/city-of-melbourne_victoria.poly"  
  
  # Reading inputs ----------------------------------------------------------
  
  # Reading the planar input (unprocessed)
  # osm_metadata <- st_read('data/melbourne.sqlite',layer="roads")%>%st_drop_geometry() # geometries are not important in this, we will use osm ids
  # this osm_metadata is already filtered to just the edges in network.sqlite
  osm_metadata <- st_read("data/network.sqlite",layer="osm_metadata")
  # Reading the nonplanar input (processed data by Alan)
  links <- st_read('data/network.sqlite' , layer="edges") # links
  nodes <- st_read('data/network.sqlite' , layer="nodes") # nodes
  
  # making the simplified network -------------------------------------------
  
  # node clusters based on those that are connected with link with less than 20 meters length
  system.time(
    df <- simplifyNetwork(links, nodes, osm_metadata, shortLinkLength)
  )
  nodes <- df[[1]]
  links <- df[[2]]

  
  # Cropping to the test_area_boundary  --------------------------------------------
  
  if(test_area_flag){
    nodes <- nodes %>%
      filter(lengths(st_intersects(., test_area_boundary)) > 0)
    links <- links %>%
      filter(from_id%in%nodes$id & to_id%in%nodes$id)
  }
  
  # OSM tags processing and attributes assignment ---------------------------
  
  osm_metadata <- osm_metadata %>% filter(osm_id%in%links$osm_id)
  
  # Creating defaults dataframe
  defaults_df <- buildDefaultsDF()
  # Assigning attributes based on defaults df and osm tags
  system.time(
    osm_attrib <- processOsmTags(osm_metadata, defaults_df) 
  )
  links <- links %>%
    left_join(osm_attrib, by="osm_id")
  
  
  if(focus_area_flag){
    # Getting the boundary area
    focus_area_boundary <- getAreaBoundary(focus_area_shire, 28355)
    # Filtering links
    links <- links %>%
      filter((lengths(st_intersects(., focus_area_boundary)) > 0) |  highway %in% defaults_df$highway[1:8])
    # Filtering nodes
    nodes<- nodes %>%
      filter(id%in%links$from_id | id%in%links$to_id)
  }
  
  #TODO: Fix the DEM so it covers the entire area.
  ## Adding elevation
  if(add_z_flag){
    elevation <- raster('data/DEMx10EPSG28355.tif') 
    
    # Assiging z coordinations to nodes
    nodes$z <- round(raster::extract(elevation ,as(nodes, "Spatial"),method='bilinear'))/10 # TODO Not working properly
    nodes <- nodes %>% dplyr::select(id, x = X, y = Y, z, GEOMETRY) %>% distinct(id, x, y, z, GEOMETRY) # id's should be unique
    
  }else{
    nodes <- nodes %>% dplyr::select(id, x = X, y = Y, GEOMETRY) %>% distinct(id, x, y, GEOMETRY) # id's should be unique
  }
  
  #st_write(links,"data/networkSimplified.sqlite",delete_layer=TRUE,layer="edges")
  #st_write(nodes,"data/networkSimplified.sqlite",delete_layer=TRUE,layer="nodes")
  
  # Adding a reverse link for bi-directional links
  bi_links <- links %>% filter(oneway==2) %>% 
    rename(from_id=to_id, to_id=from_id, toX=fromX, toY=fromY, fromX=toX, fromY=toY) %>% 
    #mutate(id=paste0("p_",from_id,"_",to_id,"_",row_number())) %>% 
    st_drop_geometry()%>% 
    dplyr::select(osm_id, from_id, to_id, fromX, fromY, toX, toY, length, highway, freespeed, permlanes, capacity, bikeway, isCycle, isWalk, isCar, modes)
  
  links <- links %>% 
    #mutate(id=paste0("p_",from_id,"_",to_id,"_",row_number())) %>% 
    st_drop_geometry() %>% 
    dplyr::select(osm_id, from_id, to_id, fromX, fromY, toX, toY, length, highway, freespeed, permlanes, capacity, bikeway, isCycle, isWalk, isCar, modes) %>% 
    rbind(bi_links)
  
  

  #add.pt.flag <- F
  
  if(add.pt.flag){
    links_pt <- gtfs2PtNetowrk(nodes) # ToDo studyRegion = st_union(st_convex_hull(nodes))
    links <- rbind(links, as.data.frame(links_pt)) %>% distinct()
  }
  

  
  # Cleaning before writing
  system.time(
    df <- cleanNetwork(links, nodes, "")
  ) 
  nodes<- df[[1]]
  links<- df[[2]]

  if(ivabm_pt_flag){
    df2 <-integrateIVABM(st_drop_geometry(nodes),links)
    #nodes<- df[[1]]
    #links<- df[[2]]
  }
  
  ## writing outputs - sqlite
  if (write_sqlite) {
    cat('\n')
    echo(paste0('Writing the sqlite output: ', nrow(links), ' links and ', nrow(nodes),' nodes\n'))
    
    # looks like the previous steps remove the geometry, this should add it back.
    # exporting the links to sqlite seems to take ~ 5 minutes, and can crash R.
    # linksGeom <- links %>%
    #   mutate(GEOMETRY=paste0("LINESTRING(",fromX," ",fromY,",",toX," ",toY,")")) %>%
    #   st_as_sf(wkt = "GEOMETRY", crs = 28355) %>%
    #   as.data.frame() %>%
    #   st_sf()
    # nodesGeom <- nodes %>%
    #   mutate(GEOMETRY=paste0("POINT(",X," ",Y,")")) %>%
    #   pull(GEOMETRY) %>%
    #   st_as_sfc(crs = 28355)
    # nodesGeom <- nodes %>%
    #   st_set_geometry(nodesGeom)
    # dir.create('./generatedNetworks')
    # st_write(linksGeom,'generatedNetworks/MATSimNetwork.sqlite', layer = 'links', delete_layer = T)
    # st_write(nodesGeom,'generatedNetworks/MATSimNetwork.sqlite', layer = 'nodes', delete_layer = T)
    
    #st_write(,'./generatedNetworks/MATSimNetwork.sqlite', layer = 'links',driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
    #st_write(, './generatedNetworks/MATSimNetwork.sqlite', layer = 'nodes',driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
    exportSQlite(links, nodes, outputFileName = "MATSimNetwork_noPT_V1.3")
    echo(paste0('Finished generating the sqlite output\n'))
  }
  
  ## writing outputs - MATSim XML - TODO make the xml writer dynamic based on the optional network attributes
  if (write_xml) {
    #links_attrib_ng <- links_attrib_cleaned %>% st_set_geometry(NULL) # Geometry in XML will 
    cat('\n')
    echo(paste0('Writing the XML output: ', nrow(links), ' links and ', nrow(nodes),' nodes\n'))
    exportXML(links, st_drop_geometry(nodes), outputFileName = "MATSimNetwork_noPT_V1.3", add_z_flag)
    echo(paste0('Finished generating the xml output\n'))
  }
  
}