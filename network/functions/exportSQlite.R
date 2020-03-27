exportSQlite <- function(l_df, n_df, outputFileName){

  dir.create('./generatedNetworks/', showWarnings = FALSE)

    l_df <- l_df %>% 
    mutate(GEOMETRY=paste0("LINESTRING(",fromX," ",fromY,",",toX," ",toY,")")) %>%
    st_as_sf(wkt = "GEOMETRY", crs = 28355)
  
  # writing sqlite outputs
  st_write(l_df, paste0('./generatedNetworks/', outputFileName,'.sqlite'), layer = 'links', 
           driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
  st_write(n_df, paste0('./generatedNetworks/', outputFileName,'.sqlite'), layer = 'nodes', 
           driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
  
}
