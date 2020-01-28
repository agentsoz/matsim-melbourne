assignSa1Maincode <- function(persons_csv_gz, out_persons_csv_gz, sa1_csv_gz) {
  
  # read in the SA1s file
  gz1<-gzfile(sa1_csv_gz, 'rt')
  sa1s<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  sa1s$SA1_MAINCODE_2016<-as.character(sa1s$SA1_MAINCODE_2016)
  sa1s$SA1_7DIGITCODE_2016<-as.character(sa1s$SA1_7DIGITCODE_2016)
  
  # read in the persons
  gz1<-gzfile(persons_csv_gz, 'rt')
  persons<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)

  # create a new column for SA1_MAINCODE_2016
  #persons$SA1_MAINCODE_2016<-""
  
  # match and assign
  df<-apply(persons, 1, function(p) {
    sa1<-sa1s[sa1s$SA1_7DIGITCODE_2016==p['SA1_7DIGCODE'] & sa1s$SA2_MAINCODE_2016==p['SA2_MAINCODE'],]
    p['SA1_MAINCODE_2016']<-sa1$SA1_MAINCODE_2016
    p
  })
  df<-t(df)
  df<-as.data.frame(df)
  write.csv(df, file=gzfile(out_persons_csv_gz), quote=TRUE, row.names = FALSE)
}


# usage example
# assignSa1Maincode('./mel2016_0.001p.csv.gz', './mel2016_0.001p_final.csv.gz', 'data/sa1_2016_aust.csv.gz')
