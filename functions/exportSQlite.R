exportSQlite <- function(l_df, n_df, outputFileName = "outputSQlite"){
  # Creating a geometry for each link from the geometry of its nodes 
  linksGeometry <- mapply(function(a,b) st_cast(st_combine(c(a,b)),"LINESTRING"), 
                          l_df %>%
                            dplyr::select(from_id) %>% left_join(n_df,by=c("from_id"="id")) %>%
                            pull(GEOMETRY),
                          l_df %>%
                            dplyr::select(to_id) %>% left_join(n_df,by=c("to_id"="id")) %>%
                            pull(GEOMETRY)
  ) %>%
    st_as_sfc()
  # Adding the geomtery to lines df
  l_df <- l_df %>%
    st_set_geometry(linksGeometry) %>%
    st_set_crs(28355)
  # writing sqlite outputs
  st_write(l_df, paste0('../outputs/outputNetworks/', outputFileName,'.sqlite'), layer = 'lines', 
           driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
  st_write(n_df, paste0('../outputs/outputNetworks/', outputFileName,'.sqlite'), layer = 'nodes', 
           driver = 'SQLite', layer_options = 'GEOMETRY=AS_XY', delete_layer = T)
  
}
