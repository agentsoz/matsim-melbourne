suppressPackageStartupMessages(library(data.table)) 

# Probabilistically selects an index from the vector of probabilities
selectIndexFromProbabilities <-function(vv) {
  if(is.null(vv) || is.na(vv)) return(vv)
  if(length(vv)==0 || length(vv)==1) return(length(vv))
  vv<-vv/sum(vv) # normalise to 1
  v<-cumsum(vv) # cumulative sum to 1
  roll<-runif(1)
  select<-match(TRUE,v>roll) # pick the first col that is higher than the dice roll
  return(select)
}

# Converts seconds to HH:MM:SS format
toHHMMSS <- function(secs) {
  if(is.null(secs) || is.na(secs) || !is.numeric(secs)) return("??:??:??")
  h<-secs %/% (60*60)
  m<-(secs - (h*60*60)) %/% 60
  s<-secs - (h*60*60) - (m*60)
  hhmmss<-paste0(str_pad(h,2,pad="0"),":",
                 str_pad(m,2,pad="0"),":",
                 str_pad(s,2,pad="0"))
  return(hhmmss)
}

# Timestamped console output
echo<- function(msg) {
  cat(paste0(as.character(Sys.time()), ' | ', msg))
}

# Progress bar
printProgress<-function(row, char, majorInterval=100, minorInterval=10) {
  if(is.null(row) || is.na(row) || !is.numeric(row)) return()
  if((row-1)%%majorInterval==0) echo('')
  cat(char)
  if(row%%minorInterval==0) cat('|')
  if(row%%majorInterval==0) cat(paste0(' ', row,'\n'))
}
