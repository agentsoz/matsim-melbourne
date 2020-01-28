sampleMelbourne2016Population <- function(samplePercentage, outcsvgz) {
  
  samplePersons <- function(persons_csv_gz, samplePercent = NULL) {
    #sampleSize<-10 #for testing purposes
    #infile<-'persons/melbourne-2016-population.persons.csv.gz'
    infile<-persons_csv_gz
    # get the number of persons in this population file  
    rows<-as.numeric(system(paste0('gunzip -c \"', infile, '\" | wc -l'), intern=TRUE))
    
    if (is.null(samplePercent)) {
      # default sample size is the full set
      percent = rows
    } else {
      # clip to within 0-100 %
      percent<-max(min(samplePercent,100),0) 
    }
    sampleSize<-floor(rows*percent)
    
    # get the csv header
    gz1<-gzfile(infile, 'rt')
    header<-read.csv(gz1, nrows=1, header=F, stringsAsFactors=F, strip.white=T )
    close(gz1)
    
    # read in the population
    gz1<-gzfile(infile, 'rt')
    all<-read.csv(gz1, header=F, stringsAsFactors=F, strip.white=T )
    close(gz1)
    
    # sample the required number of persons from the population
    if (sampleSize == rows) {
      sampleSet = all
    } else {
      sampleSet<-all[1+sample(nrow(all)-1, sampleSize),] # sample any but the header rows
    }
    
    colnames(sampleSet)<-header
    sampleSet<-sampleSet[order(as.numeric(rownames(sampleSet))),]
    return(sampleSet)
  }
  
  echo<- function(msg) {
    cat(paste0(as.character(Sys.time()), ' | ', msg))  
  }
  
  printProgress<-function(row, char) {
    m=1 # multiplier
    if((row-1)%%(50*m)==0) echo('')
    if(row%%(1*m)==0) cat(char) 
    if(row%%(10*m)==0) cat('|')
    if(row%%(50*m)==0) cat(paste0(' ', row,'\n'))
  }
  
  # get all the Melbourne 2016 persons files by SA2
  df<-data.frame(SA2=list.files(pattern = "\\persons.csv.gz$", recursive = TRUE), stringsAsFactors=FALSE)
  df$samplePercent<-samplePercentage
  persons<-NULL
  echo(paste0("Selecting a ", samplePercentage, "% population sample from Melbourne's ", nrow(df), " SA2 areas (can take a while)\n"))
  for(row in 1:nrow(df)) {
    printProgress(row,".")
    persons<-rbind(persons,samplePersons(df$SA2[row], df$samplePercent[row]))
  }
  cat('\n')
  echo(paste0("Wrote ", nrow(persons), " sampled persons to ", outcsvgz, '\n'))
  write.csv(persons, file=gzfile(outcsvgz), quote=TRUE, row.names = FALSE)
}


# usage example
# sampleMelbourne2016Population(0.001, "mel2016_0.001p.csv.gz")
