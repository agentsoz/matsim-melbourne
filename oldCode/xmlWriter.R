 # I needed to change the function a bit to also read the attributes as characters
#library(igraph)
#library(raster)
library(sf)
library(XML)

extract_name <- "carltonSingleBlock"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"

links_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/links.csv", sep = ""))

nodes_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/nodes_elevated.csv", sep = ""))


doc <- newXMLDoc()

network_tag <- newXMLNode("network", doc = doc)

nodes_tag <- newXMLNode("nodes", parent = network_tag)

for(i in 1:nrow(nodes_df)){
  
  newXMLNode("node", attrs = c(id=nodes_df$id[i], x=nodes_df$x[i], y=nodes_df$y[i], z=10), "", parent = nodes_tag)

}

links_tag <- newXMLNode("links", parent = network_tag)

for(i in 1:nrow(links_df)){
  link_tag <- newXMLNode("link", attrs = c(id=links_df$id[i], from=links_df$from[i], to=links_df$to[i],
                                           length=links_df$length[i], capacity=links_df$capacity[i], freespeed=links_df$freespeed[i],
                                           permlanes=links_df$permlanes[i], oneway="1", modes=as.character(links_df$modes[i]), origid=""), 
                         "", parent = links_tag)
  
  attributes_tag <- newXMLNode("attributes",parent = link_tag)
  newXMLNode("attribute", attrs = c(name="type", class="java.lang.String"), links_df$highway[i], parent = attributes_tag)
  newXMLNode("attribute", attrs = c(name="bicycleInfrastructureSpeedFactor", class="java.lang.Double" ), "1.0", parent = attributes_tag)
}

doc_type <- Doctype(name = "network",system = "http://www.matsim.org/files/dtd/network_v2.dtd")


saveXML(doc, paste("./", extract_name, "3.XML", sep = ""), encoding="utf-8", 
        prefix = "http://www.matsim.org/files/dtd/network_v2.dtd", 
        doctype = as(doc_type, "character"))

## generating an igraph 
#shp_graph <- igraph_generator(node_list = shp_node_edge[[2]], edge_list = shp_node_edge[[3]],  attribs_df = shp_node_edge[[5]])

#plot(shp_graph, vertex.label = NA, vertex.size = 0.5, vertex.size2 = 0.5, mark.col = "green",
#     main = "The converted igraph graph")

#write_graph(shp_graph, file = outputXml, "graphml")
