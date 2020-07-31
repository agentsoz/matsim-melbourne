library(XML)

# Function to generate MATSim person XML
generateMATSimPersonXML <- function(pid, p, acts, legs) {
  
  ### internal function to generate MATSim person attributes
  attachMATSimPersonAttributes <- function(pp,p) {
    attrs<-drop(as.matrix(p)) # get named vector of attributes
    # create person attributes
    xattr<-lapply(
      seq_along(attrs),
      function(i,x,n) { 
        xx<-newXMLNode("attribute", attrs=c(name = n[[i]], class="java.lang.String"))
        xmlValue(xx)<-x[[i]]
        xx
      }, 
      x=attrs, 
      n=names(attrs))
    # assign attribute list to attributes tag
    xattrs<-newXMLNode("attributes")
    addChildren(xattrs,xattr) 
    # attach attributes to person
    addChildren(pp,xattrs) 
    return(pp)
  }
  
  ### internal function to generate MATSim person plan of activities and legs
  attachMATSimPersonPlanXML<- function(pp, acts, legs) {
    # create the activities
    xacts<-apply(
      acts, 1,
      function(x) {
        n<-newXMLNode("activity", attrs=c(type=x[[2]], x=x[[4]], y=x[[5]], start_time=x[[9]], end_time=x[[10]]))
      })
    # create the legs
    xlegs<-apply(
      legs, 1,
      function(x) { 
        n<-newXMLNode("leg", attrs=c(x[2]))
        n
      })
    #interleave the activities and legs
    idx <- order(c(seq_along(xacts), seq_along(xlegs)))
    xactslegs<-(c(xacts,xlegs))[idx]
    #create a new plan
    xplan<-newXMLNode("plan", attrs=c(selected="yes"))
    # attach the activities and legs to the plan
    addChildren(xplan,xactslegs)
    #attach plan to person
    addChildren(pp,xplan)
    return(pp)  
  }
  
  # new XML node for this person
  pp<-newXMLNode("person", attrs=c(id=pid))
  # attach person attributes to XML node
  pp<-attachMATSimPersonAttributes(pp,p) 
  # attach plan with activities and legs to XML node
  pp<-attachMATSimPersonPlanXML(pp, acts, legs)
  # return the XML node
  return(pp)
}  
