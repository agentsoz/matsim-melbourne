crop2Poly <- function(networkInput,selectPolygon){
  # https://github.com/JamesChevalier/cities/tree/master/australia/victoria
  focus_area_boundary <- getAreaBoundary(paste0("australia/victoria/",selectPolygon,".poly"), 28355)
  networkInput[[1]] <- networkInput[[1]] %>%
    filter(lengths(st_intersects(., focus_area_boundary)) > 0)
  networkInput[[2]] <- networkInput[[2]] %>%
    filter(from_id%in%networkInput[[1]]$id & to_id%in%networkInput[[1]]$id)
  return(networkInput)
}

getAreaBoundary <- function(shire, new_crs){
  selected_shire_URL <- paste0("https://raw.githubusercontent.com/JamesChevalier/cities/master/", shire)
  download.file(selected_shire_URL, "file.poly" )
  my_data <- read.delim("file.poly", header = F, blank.lines.skip = TRUE) %>%
    filter(!is.na(V2)) %>%
    dplyr::select("V2", "V3") %>%
    st_as_sf(coords = c("V2","V3"), crs = 4326) %>%
    st_transform(new_crs) %>%
    st_union() %>%
    st_convex_hull()
  
  file.remove("file.poly")
  #linestrings <- lapply(X = 1:(nrow(my_data)-1), FUN = function(x) {
  #  pair <- st_combine(c(my_data$geometry[x], my_data$geometry[x + 1]))
  #  line <- st_cast(pair, "LINESTRING")
  #  return(line)
  #})
  # One MULTILINESTRING object with all the LINESTRINGS
  
  # multilinetring <- st_multilinestring(do.call("rbind", linestrings))
  
  #return(multilinetring)
  return(my_data)
}