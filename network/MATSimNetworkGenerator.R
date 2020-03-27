makeMatsimNetwork<-function(test_area_flag=F,focus_area_flag=F,shortLinkLength=0.1,
                            add_z_flag=F,add.pt.flag=F,write_xml=F,write_sqlite=F){
  
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
  # TODO ids should change.
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
  source('./functions/cleanNetwork.R')
  source('./functions/gtfs2PtNetowrk.R')
  
  echo<- function(msg) {
    cat(paste0(as.character(Sys.time()), ' | ', msg))  
  }
  
  printProgress<-function(row, total_row, char) {
    if((row-50)%%2500==0) echo('')
    cat('.')
    if(row%%500==0) cat('|')
    if(row%%2500==0) cat(paste0(char,' ', row, ' of ', total_row, '\n'))
  }
  
  # Seting control variables and directories  -------------------------------
  
  
  # Filter to a small study area or not
  #test_area_flag <- F #Crop or not (T/F) 
  test_area_boundary <- st_as_sfc("SRID=28355;POLYGON((318877.2 5814208.5, 321433.7 5814021.4, 321547.1 5812332.6 ,318836.3 5812083.8,  318877.2 5814208.5))")
  
  # Have a smaller area with detailed and rest with only main roads
  #focus_area_flag <-F # TODO Test if focus area works properly
  focus_area_shire <- "australia/victoria/city-of-melbourne_victoria.poly"   # https://github.com/JamesChevalier/cities/tree/master/australia/victoria
  
  # simplification
  #shortLinkLength = 20 # change to 0.01 for (almost) no simplification
  
  # Add elevation (T/F)
  #add_z_flag <- F
  
  # Specifiying which output format wanted (T/F)
  #write_xml <- T 
  #write_sqlite <- T
  
  # Reading inputs ----------------------------------------------------------
  
  # Reading the planar input (unproccessed)
  osm_metadata <- st_read('data/melbourne.sqlite',layer="roads")%>%st_drop_geometry() # geometries are not important in this, we will use osm ids
  # Reading the nonplanar input (processed data by Alan)
  lines_np <- st_read('data/network.sqlite' , layer="edges") # lines
  nodes_np <- st_read('data/network.sqlite' , layer="nodes") # nodes
  
  # making the simplified network -------------------------------------------
  
  # node clusters based on those that are connected with link with less than 20 meters length
  df <- simplifyNetwork(lines_np, nodes_np, osm_metadata, shortLinkLength)
  nodes_p <- df[[1]]
  lines_p <- df[[2]]
  
  # Croping to the test_area_boundary  --------------------------------------------
  
  if(test_area_flag){
    nodes_p <- nodes_p %>%
      filter(lengths(st_intersects(., test_area_boundary)) > 0)
    lines_p <- lines_p %>%
      filter(from_id%in%nodes_p$id & to_id%in%nodes_p$id)
  }
  
  # OSM tags processing and attributes assingment ---------------------------
  
  osm_metadata <- osm_metadata %>% filter(osm_id%in%lines_p$osm_id)
  
  # Creating defaults dataframe
  defaults_df <- buildDefaultsDF()
  # Processing the planar network and assining attributes based on defaults df and osm tags
  system.time(
    osm_attrib <- processOsmTags(osm_metadata, defaults_df) 
  )
  lines_p_attrib <- lines_p %>%
    left_join(osm_attrib, by="osm_id")
  
  
  if(focus_area_flag){
    # Getting the boundary area
    focus_area_boundary <- getAreaBoundary(selected_shire, 28355)
    # Filtering lines
    lines_p_attrib <- lines_p_attrib %>%
      filter((lengths(st_intersects(., focus_area_boundary)) > 0) |  highway %in% defaults_df$highwayType[1:8])
    # Filtering nodes
    nodes_p<- nodes_p %>%
      filter(id%in%lines_p_attrib$from_id | id%in%lines_p_attrib$to_id)
  }
  
  
  #TODO: Add in the PT network generation here. Fix the DEM so it covers the entire area.
  
  #add.pt.flag <- F
  
  if(add.pt.flag){
    pt.network <- gtfs2PtNetowrk() # ToDo combining with the main network
  }
  
  
  ## Adding elevation
  if(add_z_flag){
    elevation <- raster('data/DEMx10EPSG28355.tif') 
    
    # Assiging z coordinations to nodes
    nodes_p$z <- round(raster::extract(elevation ,as(nodes_p, "Spatial"),method='bilinear'))/10 # TODO Not working properly
    nodes_p <- nodes_p %>% dplyr::select(id, x = X, y = Y, z, GEOMETRY) %>% distinct(id, x, y, z, GEOMETRY) # id's should be unique
    
  }else{
    nodes_p <- nodes_p %>% dplyr::select(id, x = X, y = Y, GEOMETRY) %>% distinct(id, x, y, GEOMETRY) # id's should be unique
  }
  
  # Cleaning before writing
  system.time(
    df <- cleanNetwork(lines_p_attrib, nodes_p, "")
  ) 
  nodes_p<- df[[1]]
  lines_p<- df[[2]]
  
  
  
  ## writing outputs - sqlite
  if (write_sqlite) {
    dir.create('./generatedNetworks/', showWarnings = FALSE)
    cat('\n')
    echo(paste0('Writing the sqlite output: ', nrow(lines_p), ' links and ', nrow(nodes_p),' nodes\n'))
    
    st_write(lines_p,'./generatedNetworks/MATSimNetwork.sqlite', layer = 'lines', 
             driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
    st_write(nodes_p, './generatedNetworks/MATSimNetwork.sqlite', layer = 'nodes', 
             driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
    #exportSQlite(lines_p_attrib, nodes_p, outputFileName = "outputSQliteFocusedCoM")
    echo(paste0('Finished generating the sqlite output\n'))
  }
  
  ## writing outputs - MATSim XML - TODO make the xml writer dynamic based on the optional network attributes
  if (write_xml) {
    #lines_p_attrib_ng <- lines_p_attrib_cleaned %>% st_set_geometry(NULL) # Geometry in XML will 
    cat('\n')
    echo(paste0('Writing the XML output: ', nrow(lines_p), ' links and ', nrow(nodes_p),' nodes\n'))
    exportXML(lines_p, nodes_p, outputFileName = "MATSimNetwork", add_z_flag)
    echo(paste0('Finished generating the xml output\n'))
  }
  
}