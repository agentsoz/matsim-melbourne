getAreaBoundary <- function(shire, new_crs){
  selected_shire_URL <- paste0("https://raw.githubusercontent.com/JamesChevalier/cities/master/", shire)
  download.file(selected_shire_URL, "file.poly" )
  
  my_data <- read.delim("file.txt", header = F, blank.lines.skip = TRUE) %>%
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