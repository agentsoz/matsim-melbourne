# A code to combine two network
# NOTE XMLs should be in the same coordinate system
combineNetworks <- function(netwok1_xml_url = "./data/cleanedNetwork_carOnly.xml.gz", network2_xml_url = "./data/pnrOnly4.xml" ){
  library(XML)
  library(dplyr)
  library(sf)
  library(data.table)
  
  source('./functions/exportXML.R')
  echo<- function(msg) {
    cat(paste0(as.character(Sys.time()), ' | ', msg))  
  }
  
  printProgress<-function(row, total_row, char) {
    if((row-50)%%2500==0) echo('')
    cat('.')
    if(row%%500==0) cat('|')
    if(row%%2500==0) cat(paste0(char,' ', row, ' of ', total_row, '\n'))
  }
  
  # Reading network2
  
  netwrok1_xml <- xmlParse(netwok1_xml_url)
  netwrok1_nodes <- xmlRoot(netwrok1_xml)[2]
  netwrok1_links <- xmlRoot(netwrok1_xml)[4]
  
  netwrok1_nodes_df <- xmlToList(netwrok1_nodes[[1]]) %>% 
    unlist() %>% 
    matrix(nrow = xmlSize(netwrok1_nodes[[1]]), ncol = 4, byrow = T) %>% 
    as.data.frame() %>%
    dplyr::select(-1) %>% 
    rename(id = V2, x = V3, y = V4)
  
  
  netwrok1_links_df <- xmlToList(netwrok1_links[[1]]) %>% 
    unlist() %>%
    matrix(nrow = xmlSize(netwrok1_links[[1]]), ncol = 12, byrow = T) %>% 
    as.data.frame() %>% 
    dplyr::select(id = V4, from_id = V5, to_id = V6, length = V7, freespeed = V8, capacity = V9, permlanes = V10, oneway = V11, modes = V12) 
  
  
  # Reading network1
  
  network2_xml <- xmlParse(network2_xml_url)
  network2_nodes <- xmlRoot(network2_xml)[1]
  network2_links <- xmlRoot(network2_xml)[2]
  
  network2_nodes_df <- xmlToList(network2_nodes[[1]]) %>% 
    unlist() %>% 
    matrix(nrow = xmlSize(network2_nodes[[1]]), ncol = 3, byrow = T) %>% 
    as.data.frame() %>%
    rename(id = V1, x = V2, y = V3)
  
  network2_links_df <- xmlToList(network2_links[[1]]) %>% 
    unlist() %>%
    matrix(nrow = xmlSize(network2_links[[1]]), ncol = 12, byrow = T) %>% 
    as.data.frame() %>% 
    dplyr::select(id = V4, from_id = V5, to_id = V6, length = V7, freespeed = V8, capacity = V9, permlanes = V10, oneway = V11, modes = V12) 
  
  # Combining these two
  total_nodes <- rbind(netwrok1_nodes_df, network2_nodes_df) %>% 
    distinct(id, .keep_all = T)
  
  total_links <- rbind(netwrok1_links_df, network2_links_df) %>% 
    distinct(id, .keep_all = T)
  
  
  # Wrting XML
  
  exportXML(total_links, total_nodes, outputFileName = "combinedConnectedCleaned_pnrAdded_v4", addZ_coord = F)
}

