# matsim-melbourne
A MATSim model for Melbourne


## Support for large files

Given that the model will invariably be using large data files from various sources, 
we will use [Git LFS support](https://help.github.com/articles/versioning-large-files/) 
in GitHub for storing these. The idea is to keep all such files in the `./data` directory.
LFS is already set up to track any file in this directory, so there is nothing special 
you have to do. Other than ensuring that you 
[install Git LFS](https://help.github.com/articles/installing-git-large-file-storage/), 
otherwise when you clone the repository you only receive the ``pointers'' to the large 
files and not the actual data.


## Data Sources

### OpenStreetMap extract for Australia  

* URL: http://download.gisgraphy.com/openstreetmap/pbf/AU.tar.bz2
* Last accessed: sometime in April 2017 
* Saved in `data/osm/`

### Victorian Integrated Survey of Travel and Activity (VISTA)

* Downloaded from  http://economicdevelopment.vic.gov.au/transport/research-and-data/vista/vista-online-site-has-been-permanently-removed
* Last Accessed: 1 Nov 2017
* Saved in `data/vista/`


