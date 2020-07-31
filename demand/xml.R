writePlanAsMATSimXML <- function(plancsv, outxml, writeInterval) {

  options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes
  
  suppressPackageStartupMessages(library(XML))
  source('util.R', local=TRUE)
  
  # Read in the plans
  gz1<-gzfile(plancsv, 'rt')
  echo(paste0('Loading VISTA-like plans from ', plancsv, '\n'))
  plans<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  echo('Writing as MATSim XML (can take a while)\n')
  str=c(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<!DOCTYPE population SYSTEM "http://www.matsim.org/files/dtd/population_v6.dtd">',
    '<population>'
  )
  cat(str,file=outxml, sep="\n")
  
  pp<-plans
  popnWriteBuffer=list()
  processed<-0
  i=0
  while(i<nrow(pp)) {
    i<-i+1
    
    # if this row marks the start of a new person's plan
    if(i==1 || (pp[i,]$AgentId != pp[i-1,]$AgentId)) {
      # count the persons
      processed<-processed+1
      # create a new person
      pxml<-newXMLNode("person", attrs=c(id=processed-1))
      # create a new plan
      pplan<-newXMLNode("plan", attrs=c(selected="yes"))
      # attach plan to person
      addChildren(pxml,pplan)
    } else {
      # if not the first activity then also add a leg
      leg<-newXMLNode("leg", attrs=c(mode=pp[i,]$ArrivingMode))
      addChildren(pplan, leg)
    }

    # add this row as an activity    
    act<-newXMLNode("activity", attrs=c(type=pp[i,]$Activity, x=pp[i,]$x, y=pp[i,]$y, start_time=pp[i,]$act_start_hhmmss, end_time=pp[i,]$act_end_hhmmss))
    addChildren(pplan, act)

    # if this row marks the end of a person's plan 
    if(i==nrow(pp) || pp[i,]$AgentId != pp[i+1,]$AgentId) {
      # add person to write buffer
      popnWriteBuffer[[1+((processed-1)%%writeInterval)]]<-pxml
      # write it out at regular intervals
      if (processed%%writeInterval==0 || i==nrow(pp)) {
        lapply(popnWriteBuffer, function(x, file, append, sep) {
          if (!is.null(x)) {
            cat(saveXML(x), file=file, append=append, sep=sep)
          }
        }, file=outxml, append=TRUE, sep="\n")
        popnWriteBuffer=list() # clear the buffer after writing it out
      }
      # report progress
      printProgress(processed,'.')
    }

  }
  cat('</population>',file=outxml, append=TRUE,sep="\n")
  cat('\n')
  echo(paste0('Wrote ',processed,' plans to ', outxml , '\n'))
  # close off the population XML
}


# example usage
runexample<- function() {
  plancsv<-'output/7.time/plan.csv'
  outxml<-'output/plan.xml'
  writeInterval <- 2 # write to file every so many plans
  
  writePlanAsMATSimXML(plancsv, outxml, writeInterval)
}