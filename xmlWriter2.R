library(XML)

xml <- xmlTree()


extract_name <- "carltonSingleBlock"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"


links_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/links_simplified.csv", sep = ""))

nodes_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/nodes_simplified.csv", sep = ""))

# names(xml)
xml$addTag("network", close=FALSE)
xml$addTag("nodes", close=FALSE)

for (i in 1:nrow(nodes_df)) {
  xml$addTag("node", attrs = c(id=as.character(nodes_df$id[i]), x=nodes_df$x[i], y=nodes_df$y[i], z="0"))
}
xml$closeTag()

xml$addTag("links", close=FALSE)
for(i in 1:nrow(links_df)){
  xml$addTag("link", attrs = c(id=as.character(links_df$id[i]), from=as.character(links_df$from[i]), to=as.character(links_df$to[i]),
                                           length=links_df$length[i], capacity=links_df$capacity[i], freespeed=links_df$freespeed[i],
                                           permlanes=links_df$permlanes[i], oneway="1", modes=as.character(links_df$modes[i]), origid=""))
}
xml$closeTag()
xml$closeTag()

xml_prefix <- '"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE network SYSTEM "http://www.matsim.org/files/dtd/network_v2.dtd">

'

saveXML(xml, paste("./", extract_name, "110.XML", sep = ""), encoding="utf-8", 
        prefix = xml_prefix)
