exportSQlite <- function(network4sqlite, outputFileName){
  
  cat('\n')
  echo(paste0('Writing the sqlite output: ', nrow(network4sqlite[[2]]), ' links and ', nrow(network4sqlite[[1]]),' nodes\n'))
  
  dir.create('./generatedNetworks/', showWarnings = FALSE)
  
  if(class(network4sqlite[[1]])!="sf"){
  network4sqlite[[1]] <- network4sqlite[[1]] %>% 
    mutate(GEOMETRY=paste0("POINT(",x," ",y,")")) %>%
    st_as_sf(wkt = "GEOMETRY", crs = 28355) %>% 
    as.data.frame() %>%
    st_sf()
  }
  if(class(network4sqlite[[2]])!="sf"){
  network4sqlite[[2]] <- network4sqlite[[2]] %>% 
    mutate(GEOMETRY=paste0("LINESTRING(",fromX," ",fromY,",",toX," ",toY,")")) %>%
    st_as_sf(wkt = "GEOMETRY", crs = 28355) %>% 
    as.data.frame() %>%
    st_sf()
  }
  
  
  # writing sqlite outputs
  st_write(network4sqlite[[2]], paste0('./generatedNetworks/', outputFileName,'.sqlite'), layer = 'links', 
           driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
  st_write(network4sqlite[[1]], paste0('./generatedNetworks/', outputFileName,'.sqlite'), layer = 'nodes', 
           driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
  
  echo(paste0('Finished generating the sqlite output\n'))
  
}
