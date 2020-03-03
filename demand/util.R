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

# usage example
# assignSa1Maincode('./mel2016_0.001p.csv.gz', './mel2016_0.001p_final.csv.gz', 'data/sa1_2016_aust.csv.gz')
assignSa1Maincode <- function(persons_csv_gz, out_persons_csv_gz, sa1_csv_gz) {
  

  # read in the SA1s file
  gz1<-gzfile(sa1_csv_gz, 'rt')
  sa1s<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  sa1s$SA1_MAINCODE_2016<-as.numeric(sa1s$SA1_MAINCODE_2016)
  sa1s$SA1_7DIGITCODE_2016<-as.numeric(sa1s$SA1_7DIGITCODE_2016)
  sa1s_dt<-data.table(sa1s)
  setkey(sa1s_dt, SA1_7DIGITCODE_2016, SA2_MAINCODE_2016)
  
  # read in the persons
  gz1<-gzfile(persons_csv_gz, 'rt')
  persons<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  persons$SA1_7DIGCODE<-as.numeric(persons$SA1_7DIGCODE)
  persons$SA2_MAINCODE<-as.numeric(persons$SA2_MAINCODE)
  
  # create a new column for SA1_MAINCODE_2016
  #persons$SA1_MAINCODE_2016<-""
  
  # match and assign
  df<-apply(persons, 1, function(p) {
    #sa1<-sa1s[sa1s$SA1_7DIGITCODE_2016==p['SA1_7DIGCODE'] & sa1s$SA2_MAINCODE_2016==p['SA2_MAINCODE'],]
    sa1<-sa1s_dt[.(as.numeric(p['SA1_7DIGCODE']),as.numeric(p['SA2_MAINCODE']))]
    p['SA1_MAINCODE_2016']<-sa1$SA1_MAINCODE_2016
    p
  })
  df<-t(df)
  df<-as.data.frame(df)
  write.csv(df, file=gzfile(out_persons_csv_gz), quote=TRUE, row.names = FALSE)
}


