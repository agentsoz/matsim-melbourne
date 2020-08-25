integrateIVABM <- function(net1.nodes.df=NULL, net1.links.df=NULL){
  
  # net1.nodes.df <- st_drop_geometry(networkRestructured[[1]])
  # net1.links.df <- networkRestructured[[2]]
  # This code integrates RMIT generated network with PT and Park and Ride related network from IVABM
  # Required inputs from IVABM:
  #   - network file (.xml)
  #   - Transit schedule file (.xml)
  #   - PnR lookup file, contains links and parking capacity (.xml)
  
  #source('../exportXML.R')
  #source('./logging.R')
  
  echo<- function(msg) {
    cat(paste0(as.character(Sys.time()), ' | ', msg))  
  }
  
  printProgress<-function(row, total_row, char) {
    if((row-50)%%2500==0) echo('')
    cat('.')
    if(row%%500==0) cat('|')
    if(row%%2500==0) cat(paste0(char,' ', row, ' of ', total_row, '\n'))
  }
  
  # Reading network 1 -------------------------------------------------------
  # NOTE start from a cleaned matsim network
  if(is.null(net1.nodes.df) | is.null(net1.links.df)){
    xml.file.URL <- "./generatedNetworks/MATSimNetwork_V1.2.xml"
    
    root.xml <- xmlParse(xml.file.URL)
    net.nodes.xml <- xmlRoot(root.xml)[1]
    net.links.xml <- xmlRoot(root.xml)[2]
    
    net1.links.df <- xmlToList(net.links.xml[[1]]) %>% 
      unlist() %>%
      matrix(nrow = xmlSize(net.links.xml[[1]]), ncol = 24, byrow = T) %>% 
      as.data.frame() %>% 
      dplyr::select(id = V16, from_id = V17, to_id = V18, length = V19, freespeed = V20, 
                    capacity = V21, permlanes = V22, oneway = V23, modes = V24, 
                    bicycleInfrastructureSpeedFactor = V7, osm_id = V10, type = V13, 
                    bikeway = V8, GEOMETRY = V1) 
    
    net1.nodes.df <- xmlToList(net.nodes.xml[[1]]) %>% 
      unlist() %>% 
      matrix(nrow = xmlSize(net.nodes.xml[[1]]), ncol = 4, byrow = T) %>% 
      as.data.frame() %>%
      dplyr::select(-1) %>% 
      rename(id = V2, x = V3, y = V4)
  }
  
  net1.links.car.df <-  net1.links.df %>% 
    filter(modes %like% "car")
  
  net1.nodes.car.sf <- net1.nodes.df %>%  
    filter(id %in% net1.links.car.df$from_id | id %in% net1.links.car.df$to_id) %>% 
    mutate_if(is.factor, as.character) %>% 
    st_as_sf(coords = c("x", "y"), crs = 28355, remove = F) 
  
  # Reading network 2 -------------------------------------------------------
  xml.file.URL <- "./data/ivabm/network_2016_v3.xml"
  
  root.xml <- xmlParse(xml.file.URL)
  net.nodes.xml <- xmlRoot(root.xml)[2]
  net.links.xml <- xmlRoot(root.xml)[4]

  net2.nodes.df <- xmlToList(net.nodes.xml[[1]]) %>% 
    unlist() %>% 
    matrix(nrow = xmlSize(net.nodes.xml[[1]]), ncol = 4, byrow = T) %>% 
    as.data.frame() %>%
    dplyr::select(-1) %>% 
    rename(id = V2, x = V3, y = V4) %>% 
    mutate(id=paste0("ivabm_",id))
    
  net2.nodes.sf <- net2.nodes.df %>% 
    mutate_if(is.factor, as.character) %>% 
    dplyr::select(id, x, y) %>% 
    st_as_sf(coords = c("x", "y"), crs = 28355, remove = F) 
  
  net2.links.df <- xmlToList(net.links.xml[[1]]) %>% 
    unlist() %>%
    matrix(nrow = xmlSize(net.links.xml[[1]]), ncol = 10, byrow = T) %>% 
    as.data.frame() %>% 
    dplyr::select(id = V2, from_id = V3, to_id = V4, length = V5, freespeed = V6, 
                  capacity = V7, permlanes = V8, oneway = V9, modes = V10) %>% 
    mutate(from_id=paste0("ivabm_",from_id)) %>% 
    mutate(to_id=paste0("ivabm_",to_id)) 
  
  
  # Getting transit network -------------------------------------------------
  # Get Transit Lines from schedule - to check everything is covered
  xml.file.URL <- "./data/ivabm/Schedule/transitSchedule_2016_v2_scheduleD.xml"
  
  root.xml <- xmlParse(xml.file.URL)
  pt.routes.xml <- xmlRoot(root.xml)[2]
  pt.routes.df <- data.frame() # Sorry for this sin R community
  for (tr in 1:xmlSize(pt.routes.xml[[1]])){
    mode <- xmlToList(pt.routes.xml[[1]][[tr]][[2]]) %>% unlist()
    this_tr <- xmlToList(pt.routes.xml[[1]][[tr]][[4]]) %>% unlist() %>% 
      matrix(ncol = 1) %>% as.data.frame() %>% mutate(modes = mode)
    pt.routes.df <- rbind(pt.routes.df, this_tr)
  }
  pt.routes.df <- pt.routes.df %>% rename(id = V1) %>%  distinct(id, modes)
  
  # Extracting Transit Links from Net2
  pt.links.df <- net2.links.df  %>%  
    mutate(mode_temp = if_else(condition = id %in% pt.routes.df$id, true = "pt", 
                               false = "NA")) %>% 
    mutate(mode_temp = if_else(condition = (modes %like% "bus" & modes %like% "tram"), true = "bus,tram", 
                               false = mode_temp)) %>% 
    mutate(mode_temp = if_else(condition = (!(modes %like% "bus") & modes %like% "tram"), true = "tram", 
                               false = mode_temp)) %>% 
    mutate(mode_temp = if_else(condition = (!(modes %like% "tram") & modes %like% "bus"), true = "bus", 
                               false = mode_temp)) %>% 
    mutate(mode_temp = if_else(condition = (modes %like% "train"), true = "train", 
                               false = mode_temp))  %>% 
    filter(!mode_temp == "NA") %>% 
    dplyr::select(-modes) %>% 
    dplyr::rename(modes=mode_temp)
  
  pt.nodes.df <- net2.nodes.sf %>% filter(id %in% pt.links.df$from_id | id %in% pt.links.df$to_id)  
  
  # Extracting PnR links ----------------------------------------------------
  # Finding park and ride links
  pnr.links <- read.csv("./data/ivabm/PnR_2016_1pct_v1.csv", header = F) %>% dplyr::select(V2:V7) %>% unlist() %>% as.character()
  pnr.links.df <- net2.links.df  %>%  
    mutate(mode_temp = if_else(condition = (id %in% pnr.links), true = "car", false = "NA")) %>% 
    filter(mode_temp == "car") %>% 
    dplyr::select(-modes) %>% 
    dplyr::rename(modes=mode_temp)
  
  # Connecting PnR links to the main network --------------------------------
  # library(nngeo)
  # PnR from
  pnr.from.nodes <- net2.nodes.sf %>% filter(id %in% pnr.links.df$from_id) 
  
  closest <- data.frame(row=st_nn(st_geometry(pnr.from.nodes),st_geometry(net1.nodes.car.sf),k=1,returnDist=FALSE)  %>% 
    unlist()) 
  
  pnr.from.nodes <- cbind(st_drop_geometry(pnr.from.nodes), closest) %>% 
    inner_join(st_drop_geometry(net1.nodes.car.sf)%>%mutate(id_closest=row_number()), by=c("row"="id_closest")) %>% 
    dplyr::select(old_id = id.x, new_id = id.y )
  
  # PnR to
  pnr.to.nodes <- net2.nodes.sf %>% filter(id %in% pnr.links.df$to_id) 
  
  closest1 <- data.frame(row=st_nn(st_geometry(pnr.to.nodes),st_geometry(net1.nodes.car.sf),k=1,returnDist=FALSE) %>%
                           unlist()) 
  closest2 <- data.frame(row=st_nn(st_geometry(pnr.to.nodes),st_geometry(net1.nodes.car.sf),k=2,returnDist=FALSE)  %>% 
                           unlist()) %>%  dplyr::filter(row_number() %% 2 == 0)
  
  pnr.to.nodes <- cbind(st_drop_geometry(pnr.to.nodes), closest1) %>% 
    inner_join(st_drop_geometry(net1.nodes.car.sf)%>%mutate(id_closest=row_number()), by=c("row"="id_closest")) %>% 
    dplyr::select(old_id = id.x, new_id = id.y )
  
  pnr.to.nodes <- cbind(pnr.to.nodes, closest2) %>% 
    inner_join(st_drop_geometry(net1.nodes.car.sf)%>%mutate(id_closest=row_number()), by=c("row"="id_closest")) %>% 
    dplyr::select(old_id, new_id, new_id2 = id )
    
  
  # Merging all the links and nodes -----------------------------------------
  
  # Merging 'from' ids
  pnr.links.new.df <- pnr.links.df %>% mutate(from_id = as.character(from_id)) %>% 
    left_join(pnr.from.nodes, by = c("from_id" = "old_id")) %>% 
    dplyr::select(-from_id) %>% rename("from_id" = "new_id") %>% 
    dplyr::select(id, from_id, to_id, length, freespeed, capacity, permlanes, oneway, modes)
  
  # Merging 'to' ids
  pnr.links.new.df <- pnr.links.new.df  %>% mutate(to_id = as.character(to_id))  %>%  
    left_join(pnr.to.nodes, by = c("to_id" = "old_id")) %>% 
    mutate(new.id.s = if_else(from_id != new_id, true = new_id, false = new_id2))  %>% 
    dplyr::select(-to_id) %>% rename("to_id" = "new.id.s") %>% 
    dplyr::select(id, from_id, to_id, length, freespeed, capacity, permlanes, oneway, modes)
  
  # Merging pnr nodes
  pnr.nodes.net1  <- net1.nodes.df %>%  
    filter(id %in% pnr.links.new.df$to_id | id %in% pnr.links.new.df$from_id) 
  pnr.nodes.net2 <- net2.nodes.sf %>% 
    filter(id %in% pnr.links.new.df$to_id | id %in% pnr.links.new.df$from_id) 
  
  fncols <- function(data, cname) {
    add <-cname[!cname%in%names(data)]
    if(length(add)!=0) data[add] <- NA
    data
  }
  
  if(class(pnr.nodes.net2)[1]=="sf"){
    pnr.nodes.net2 <- st_drop_geometry(pnr.nodes.net2)
  }
  # Merging pnr links and nodes
  pnr.links.final <- pnr.links.new.df %>% distinct(id, .keep_all = T)
  
  if(nrow(pnr.nodes.net2)>0){
    pnr.nodes.net2 <-  fncols(pnr.nodes.net2, colnames(pnr.nodes.net1)) %>% 
      dplyr::select(colnames(pnr.nodes.net1))
    pnr.nodes.final <- rbind(pnr.nodes.net1, pnr.nodes.net2) %>% distinct(id, .keep_all = T)
  }else{
    pnr.nodes.final <- pnr.nodes.net1
  }
  
  
  # exportXML(list(pnr.links.final, pnr.nodes.final), outputFileName = "pnrOnly_v010")
  # Merging pnr and pt links
  if(class(pt.nodes.df)[1]=="sf"){
    pt.nodes.df <- st_drop_geometry(pt.nodes.df)
  }
  pt.nodes.df <-  fncols(pt.nodes.df, colnames(pnr.nodes.net1)) %>% 
    dplyr::select(colnames(pnr.nodes.net1))
  net2.links.final <- rbind(pnr.links.final, pt.links.df) %>% distinct(id, .keep_all = T) %>% mutate_if(is.factor, as.character)
  net2.nodes.final <- rbind(pt.nodes.df,pnr.nodes.final) %>% distinct(id, .keep_all = T) 
  
  # Net1 final
  net1.links.final <- net1.links.df %>% 
    #mutate(oneway = "1") %>% 
    #dplyr::select(id, from_id, to_id, length, freespeed, capacity, permlanes, oneway, modes) %>%
    mutate_if(is.factor, as.character)
  
  net2.links.final <-  net2.links.final %>% 
    left_join(net2.nodes.final,by =c("from_id"="id")) %>% 
    rename(fromX=x,fromY=y) %>% 
    left_join(net2.nodes.final,by =c("to_id"="id")) %>% 
    rename(toX=x,toY=y) %>% 
    mutate(isOneway=1) %>% 
    mutate(isCar=ifelse(stringr::str_detect(modes,"car"), yes = 1, no = 0)) %>% 
    mutate(isCycle=ifelse(stringr::str_detect(modes,"bicycle"), yes = 1, no = 0)) %>% 
    mutate(isWalk=ifelse(stringr::str_detect(modes,"walk"), yes = 1, no = 0)) %>% 
    fncols(colnames(net1.links.final)) %>% 
    dplyr::select(colnames(net1.links.final)) 
    
  # Combining net1 with net2
  total.links <- rbind(net2.links.final, net1.links.final)
  total.nodes <- rbind(net2.nodes.final, net1.nodes.df) %>% 
    distinct(id, .keep_all = T) 
  
  #exportXML(list(total.links, total.nodes), outputFileName = "GMel_2D_IVABMPT_GMel_20m_pnrAdded_v1.3")
  
  return(list(total.nodes,total.links))

}























