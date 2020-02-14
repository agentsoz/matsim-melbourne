exportXML <- function(l_df, n_df, outputFileName = "outputXML", addZ_coord){
  
  addMATSimNode <- function(this_node){
    if (addZ_coord){
      xnn<-newXMLNode("node", attrs=c(id=as.character(this_node$id), x=this_node$x, y=this_node$y, z=this_node$z))# assign attribute list to attributes tag
      
    }else {
      xnn<-newXMLNode("node", attrs=c(id=as.character(this_node$id), x=this_node$x, y=this_node$y))# assign attribute list to attributes tag
    }
     return(xnn)
  }
  
  addMATSimLink <- function(this_link){
    xll <- newXMLNode("link", attrs = c(id=as.character(this_link$id), from=as.character(this_link$from_id), to=as.character(this_link$to_id),
                                        length=this_link$length, capacity=this_link$capacity, freespeed=this_link$freespeed,
                                        permlanes=this_link$permlanes, oneway="1", modes=as.character(this_link$modes)))
    
    attribs <- this_link %>% mutate(bicycleInfrastructureSpeedFactor = 1.0) %>% 
      dplyr::select(osm_id, type = highway, bikeway, bicycleInfrastructureSpeedFactor) %>% 
      mutate(bikeway = if_else(is.na(bikeway),true = "No", bikeway))
    
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
      return(xll)
  }
  
  echo('Starting to write the XML\n')
  # Set the output file
  xml_file <- paste0('../outputs/outputNetworks/',outputFileName,'.xml')
  
  # Adding the prefix
  cat("<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE network SYSTEM \"http://www.matsim.org/files/dtd/network_v2.dtd\">\n
<network>\n
<nodes>\n",file=xml_file,append=FALSE)

  echo('Starting to add nodes to XML\n')
  for (i in 1:nrow(n_df)) {
    if(i %%50 == 0) printProgress(i, nrow(n_df), 'node')
    this_node_xml <- addMATSimNode(n_df[i,])
    cat(saveXML(this_node_xml),# assign attribute list to attributes tag
        file=xml_file,append=TRUE)
    cat("\n",file=xml_file,append=TRUE)
  }
  
  cat("</nodes>\n",file=xml_file,append=TRUE)
  cat("<links>\n",file=xml_file,append=TRUE)
  
  echo('\n')
  echo('Starting to add links to XML\n')
  
  for (i in 1:nrow(l_df)) {
    if(i %%50 == 0) printProgress(i, nrow(l_df), 'link')
    this_link_xml <- addMATSimLink(l_df[i,])
    cat(saveXML(this_link_xml),
        file=xml_file,append=TRUE)
    cat("\n",file=xml_file,append=TRUE)
  }
  
  cat("</links>\n",file=xml_file,append=TRUE)
  cat("</network>\n",file=xml_file,append=TRUE)
}
