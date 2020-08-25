exportXML <- function(network4xml, outputFileName = "outputXML"){
  # network4xml <- networkFinal
  
  source('./functions/etc/logging.R')
  
  if(class(network4xml[[1]])[1]=="sf"){
    n_df <- st_drop_geometry(network4xml[[1]])
  }else{
    n_df <- network4xml[[1]]
  }
  
  if(class(network4xml[[2]])[1]=="sf"){
    l_df <- st_drop_geometry(network4xml[[2]])
  }else{
    l_df <- network4xml[[2]]
  }
  
  cat('\n')
  echo(paste0('Writing the XML output: ', nrow(l_df), ' links and ', nrow(n_df),' nodes\n'))
  
  addMATSimNode <- function(x){
    this_node <- n_df[x,]
    if ("z" %in% colnames(this_node)){
      this_node <- this_node %>% mutate(z = if_else(is.na(z), true = 10, z))
      xnn<-newXMLNode("node", attrs=c(id=as.character(this_node$id), 
                                      x=as.character(this_node$x), 
                                      y=as.character(this_node$y), 
                                      z=as.character(this_node$z), 
                                      type=as.character(this_node$type)))
    }else {
      xnn<-newXMLNode("node", attrs=c(id=as.character(this_node$id), 
                                      x=as.character(this_node$x), 
                                      y=as.character(this_node$y), 
                                      type=as.character(this_node$type)))
    }
    if(x %%50 == 0) printProgress(x, nrow(n_df), 'node')
    cat(saveXML(xnn),# assign attribute list to attributes tag
        file=xml_file,append=TRUE)
    cat("\n",file=xml_file,append=TRUE)
  }
  
  addMATSimLink <- function(x){
    this_link <- l_df[x,]
    if(x %%50 == 0) printProgress(x, nrow(l_df), 'link')
    
    xll <- newXMLNode("link", attrs = c(id=as.character(this_link$id), 
                                        from=as.character(this_link$from_id), 
                                        to=as.character(this_link$to_id),
                                        length=this_link$length, 
                                        capacity=this_link$capacity, 
                                        freespeed=this_link$freespeed,
                                        permlanes=this_link$permlanes, 
                                        oneway="1", 
                                        modes=as.character(this_link$modes)))
    attribs <- this_link  %>% 
      dplyr::select(osm_id, type, bikeway, bicycleInfrastructureSpeedFactor)
    xlattribs <- lapply(
      seq_along(attribs),
      function(i,x,n) { 
        xx<-newXMLNode("attribute", attrs=c(name = n[[i]], class="java.lang.String"))
        xmlValue(xx)<-x[[i]]
        xx
      }, 
      x=attribs,
      n=names(attribs))
    lattribs <- newXMLNode("attributes")
    addChildren(lattribs, xlattribs)
    addChildren(xll, lattribs)
    cat(saveXML(xll),
        file=xml_file,append=TRUE)
    cat("\n",file=xml_file,append=TRUE)
  }
  
  echo('Starting to write the XML\n')
  # Set the output file
  dir.create('./generatedNetworks/', showWarnings = FALSE)
  xml_file <- paste0('./generatedNetworks/',outputFileName,'.xml')
  # Adding the prefix
  open(file(xml_file), "wt")
  cat("<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE network SYSTEM \"http://www.matsim.org/files/dtd/network_v2.dtd\">\n
<network>\n
<nodes>\n",file=xml_file,append=FALSE)

  echo('Starting to add nodes to XML\n')
  purrr::map_dfr(1:nrow(n_df),addMATSimNode)
  cat("</nodes>\n",file=xml_file,append=TRUE)
  cat("<links>\n",file=xml_file,append=TRUE)
  
  echo('\n')
  echo('Starting to add links to XML\n')
  # adding missing columns
  fncols <- function(data, cname) {
    add <-cname[!cname%in%names(data)]
    if(length(add)!=0) data[add] <- NA
    data
  }
  
  # Adding a reverse links for bi-directionals
  bi_links <- l_df %>% 
    filter(isOneway==0) %>% 
    rename(from_id=to_id, to_id=from_id, toX=fromX, toY=fromY, fromX=toX, fromY=toY) %>% 
    #mutate(id=paste0("p_",from_id,"_",to_id,"_",row_number())) %>% 
    dplyr::select(from_id, to_id, fromX, fromY, toX, toY, length, freespeed, permlanes,
                  capacity, isOneway, bikeway, isCycle, isWalk, isCar, modes)
  
  l_df <- rbind(l_df, bi_links) %>% 
    mutate(tempId = paste0(from_id,"_",to_id,bikeway,modes)) %>% 
    distinct(tempId, .keep_all = T ) %>% 
    dplyr::select(-tempId)
  
  # Adding bicycle and extra information
  l_df <-  fncols(l_df, c("id","osm_id", "highway", "bikeway", "bicycleInfrastructureSpeedFactor")) 
  l_df <- l_df %>%
    mutate(id = replace(id, is.na(id), row_number())) %>% 
    mutate(osm_id = replace(osm_id, is.na(osm_id), 9999999999)) %>% 
    mutate(type = replace(highway, is.na(highway), "NotSpecified")) %>% 
    mutate(bikeway = replace(bikeway, is.na(bikeway),"No")) %>% 
    mutate(bicycleInfrastructureSpeedFactor = replace(bicycleInfrastructureSpeedFactor, 
                                                      is.na(bicycleInfrastructureSpeedFactor),1.0))
  
  purrr::map_dfr(1:nrow(l_df),addMATSimLink)
  cat("</links>\n",file=xml_file,append=TRUE)
  cat("</network>\n",file=xml_file,append=TRUE)
  
  echo(paste0('Finished generating the xml output\n'))
  close(file(xml_file))
}
