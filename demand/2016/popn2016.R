samplePersons <- function(persons_csv_gz, samplePercent = NULL) {
  #sampleSize<-10 #for testing purposes
  #infile<-'persons/melbourne-2016-population.persons.csv.gz'
  infile<-persons_csv_gz
  # get the number of persons in this population file  
  rows<-as.numeric(system(paste('gunzip -c', infile, '| wc -l'), intern=TRUE))

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


assignSa1Maincode <- function(persons) {
  # read in the SA1s file
  gz1<-gzfile('persons/SA1_2016_AUST.csv.gz', 'rt')
  sa1s<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  sa1s$SA1_MAINCODE_2016<-as.character(sa1s$SA1_MAINCODE_2016)
  sa1s$SA1_7DIGITCODE_2016<-as.character(sa1s$SA1_7DIGITCODE_2016)
  
  # create a new column for SA1_MAINCODE_2016
  persons$SA1_MAINCODE_2016<-""
  
  # match and assign
  df<-apply(persons, 1, function(p) {
    sa1<-sa1s[sa1s$SA2_MAINCODE_2016==p['SA2_MAINCODE'] & sa1s$SA1_7DIGITCODE_2016==p['SA1_7DIGCODE'],]
    p['SA1_MAINCODE_2016']<-sa1$SA1_MAINCODE_2016
    p
  })
  df<-t(df)
  return(df)
}


