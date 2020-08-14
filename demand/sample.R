sampleMelbourne2016Population <- function(samplePercentage, outcsvgz) {
  
  source('util.R', local=TRUE)
  
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
    sampleSize<-round(rows*(percent/100.0))
    
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
  
  # Fix their home location SA1 code (convert from SA1_7DIGCODE to SA1_MAINCODE_2016)
  echo(paste0('Assigning SA1_MAINCODE_2016 to persons in ', outcsvgz, ' (can take a while)\n'))
  assignSa1Maincode(outcsvgz, outcsvgz, 'data/sa1_2016_aust.csv.gz') # overwriting outfile
  echo(paste0('Updated ', outcsvgz,'\n'))
  
}

# example usage
runexample<- function(percent) {
  samplesize<-percent
  outdir<-'./output/2.sample'
  dir.create(outdir, showWarnings = FALSE, recursive=TRUE)
  outfile<-paste0(outdir,'/sample.csv.gz')
  sampleMelbourne2016Population(samplesize, outfile)
}