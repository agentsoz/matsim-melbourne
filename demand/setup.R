# Function to pre-process some data; need only be run once
setup<-function(setupDir) {
  
  source("util.R", local=TRUE)
  source("vista.R", local=TRUE)
  
  dir.create(setupDir, showWarnings=FALSE, recursive=TRUE)
  
  if (!file.exists('data/VISTA_12_18_CSV.zip.dir/T_VISTA1218_V1.csv')) {
    echo(paste0('Some required files are missing in the ./data directory. ',
                'Please see ./data/README.md\n'))
    return(FALSE)
  }
  
  # Extract VISTA activities and save separately into weekday and weekend activities
  vista_csv <- 'data/VISTA_12_18_CSV.zip.dir/T_VISTA1218_V1.csv'
  out_weekday_activities_csv_gz <- paste0(setupDir,'/vista_2012_18_extracted_activities_weekday.csv.gz')
  out_weekend_activities_csv_gz <- paste0(setupDir,'/vista_2012_18_extracted_activities_weekend.csv.gz')
  echo(paste0('Extracting VISTA weekday/end activities from ', vista_csv, ' (can take a while)\n'))
  extract_and_write_activities_from(vista_csv, out_weekday_activities_csv_gz, out_weekend_activities_csv_gz)
  echo(paste0('Wrote ', out_weekday_activities_csv_gz, ' and ', out_weekend_activities_csv_gz,'\n'))
  
  # Simplify some activitiy classes to activity groups
  echo(paste0('Grouping some VISTA activities\n'))
  simplify_activities_and_create_groups(out_weekday_activities_csv_gz)
  echo(paste0('Updated ', out_weekday_activities_csv_gz,'\n'))
  simplify_activities_and_create_groups(out_weekend_activities_csv_gz)
  echo(paste0('Updated ', out_weekend_activities_csv_gz,'\n'))
  
  # Write out the activity probabilitities by time bins
  binsize<-48 # 30-min bins
  echo(paste0('Extracting VISTA weekday/end activities times into ',binsize,' bins (can take a while)\n'))
  out_weekday_activities_time_bins_csv_gz<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekday_time_bins.csv.gz')
  out_weekend_activities_time_bins_csv_gz<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekend_time_bins.csv.gz')
  extract_and_write_activities_time_bins(
    out_weekday_activities_csv_gz,
    out_weekday_activities_time_bins_csv_gz,
    binsize)
  extract_and_write_activities_time_bins(
    out_weekend_activities_csv_gz,
    out_weekend_activities_time_bins_csv_gz,
    binsize)
  echo(paste0('Wrote ', out_weekday_activities_time_bins_csv_gz, ' and ', out_weekend_activities_time_bins_csv_gz,'\n'))
  
  # Create markov chain model for trip chains
  #prefix<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekday')
  #infile<-paste0(prefix,'.csv.gz')
  #outfile<-paste0(prefix,'_markov_chain_model.rds')
  #pdffile<-paste0(prefix,'_markov_chain_model.pdf')
  
  #echo(paste0('Generating markov chain model of VISTA activities from ', infile, ' (can take a while)\n'))
  #mc<-create_markov_chain_model('Weekday Activities',infile)
  #saveRDS(mc, file = outfile)
  #pdf(pdffile,width=8.5,height=8.5, paper="special")
  #plot(mc,col=heat.colors(20))
  #graphics.off()
  #echo(paste0('Wrote markov chain model to ', outfile, '\n'))
  #echo(paste0('Wrote model visualisation to ', pdffile, '\n'))
  
  echo('Setup complete\n')
  return(TRUE)
}

# example usage
runexample<- function() {
  status<-setup('output/1.setup')
}