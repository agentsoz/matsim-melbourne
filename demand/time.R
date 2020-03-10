assignTimesToActivities <- function(plancsv, binSizeInMins, outcsv, writeInterval) {

  options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes
  
  suppressPackageStartupMessages(library(stringr))
  source('util.R')
  
  # Converts mins to HH:MM:SS format
  toHHMMSS <- function(mins) {
    if(is.null(mins) || is.na(mins) || !is.numeric(mins)) return("??:??:??")
    h<-mins %/% 60
    m<-mins - (h*60)
    s<-0
    hhmmss<-paste0(str_pad(h,2,pad="0"),":",
                   str_pad(m,2,pad="0"),":",
                   str_pad(s,2,pad="0"))
    return(hhmmss)
  }
  
  
  # Read in the plans
  gz1<-gzfile(plancsv, 'rt')
  echo(paste0('Loading VISTA-like plans from ', plancsv, '\n'))
  plans<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  echo('Assigning start/end times to activities  (can take a while)\n')
  pp<-plans
  pp$act_start_hhmmss<-""; pp$act_end_hhmmss<-""
  wplans<-pp[FALSE,]
  write.table(wplans, file=outcsv, append=FALSE, row.names=FALSE, sep = ',')
  processed<-0
  i=0
  error<-FALSE
  while(i<nrow(pp)) {
    i<-i+1
    
    if(i<nrow(pp) && (pp[i,]$EndBin == pp[i+1,]$StartBin)) {
      # if the end bin of this activity is the same as the start bin of the next activity, 
      # then put this end time in the first half of the bin
      pp[i,]$act_start_hhmmss<-toHHMMSS(((pp[i,]$StartBin*binSizeInMins)+sample(binSizeInMins, 1))-binSizeInMins)
      pp[i,]$act_end_hhmmss<-toHHMMSS(((pp[i,]$EndBin*binSizeInMins)+sample(binSizeInMins/2, 1))-binSizeInMins)
      
    } else if (i>1 && (pp[i,]$StartBin == pp[i-1,]$EndBin)) {
      # if the start bin of this activity is the same as the end bin of the previous activity, 
      # then put this start time in the second half of the bin
      pp[i,]$act_start_hhmmss<-toHHMMSS(((pp[i,]$StartBin*binSizeInMins)+sample(binSizeInMins/2, 1)+(binSizeInMins/2))-binSizeInMins)
      pp[i,]$act_end_hhmmss<-toHHMMSS(((pp[i,]$EndBin*binSizeInMins)+sample(binSizeInMins, 1))-binSizeInMins)
      
    } else if (pp[i,]$StartBin == pp[i,]$EndBin) {
      # else if the start/bin bins of this activity is the same, then ensure start is before end
      pp[i,]$act_start_hhmmss<-toHHMMSS(((pp[i,]$EndBin*binSizeInMins)+sample(binSizeInMins/2, 1))-binSizeInMins)
      pp[i,]$act_end_hhmmss<-toHHMMSS(((pp[i,]$StartBin*binSizeInMins)+sample(binSizeInMins/2, 1)+(binSizeInMins/2))-binSizeInMins)
      
    } else {
      # else put the start/end times anywhere in the bin
      pp[i,]$act_start_hhmmss<-toHHMMSS(((pp[i,]$StartBin*binSizeInMins)+sample(binSizeInMins, 1))-binSizeInMins)
      pp[i,]$act_end_hhmmss<-toHHMMSS(((pp[i,]$EndBin*binSizeInMins)+sample(binSizeInMins, 1))-binSizeInMins)
    }
    
    # add it to out list
    wplans<-rbind(wplans, pp[i,])
    # record progress for each person
    if(i==nrow(pp) || pp[i,]$AgentId != pp[i+1,]$AgentId) {
      processed<-processed+1
      if(error) {
        printProgress(processed, 'x')
      } else {
        printProgress(processed, '.')
      }
    }
    # write it out at regular intervals
    if (processed%%writeInterval==0 || i==nrow(pp)) {
      write.table(wplans, file=outcsv, append=TRUE, row.names=FALSE, col.names=FALSE, sep = ',')
      wplans<-wplans[FALSE,] # remove all rows
    }
  }
  cat('\n')
  echo(paste0('Wrote ',processed,' plans to ', outcsv , '\n'))
}


# example usage
runexample<- function() {
  binSizeInMins<-30
  plancsv<-'output/6.place/plan.csv'
  outdir<-'output/7.time'
  dir.create(outdir, showWarnings = FALSE, recursive=TRUE)
  outcsv<-paste0(outdir,'/plan.csv')
  writeInterval <- 100 # write to file every so many plans
  
  assignTimesToActivities(plancsv, binSizeInMins, outcsv, writeInterval)
}