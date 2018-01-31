### Content

* [About this directory](#about-this-directory)
* [Files Contained](#files-contained)
* [Contributors](#contributors)


### About this directory

Very initial scenario, trying to be maximally pragmatic.  Elements:
* VISTA data translated 1:1 to MATSim plans.  All activity types 
and modes are retained and automatically copied into a file which
now shows up as baseConfig.xml .
* VISTA persons do not have weight one; that aspect is ignored. 

### Files contained

The following list describes the files contained in the directory

* baseConfig.xml -- see above

* comparisonConfigDump.xml -- cannot remember what this is

##### without network

* pop.xml.gz -- Raw translation of VISTA file.  Only coordinates, no network.  Run
this together with an arbitrary (e.g. new) network to get matsim input files that
work together with a specific network.

##### high resolution network

* mergedGmelbNetwork.xml.gz -- 
The road network is something that I got from Zahra Navidi.  
It minimally has the problem that its border goes right through
Geelong.  It should be re-generated with having trunk roads for
a much larger area (see MATSim book).

I _seem to recall_ (but this would need to be verified) that the following files go
together with this network:

* pop-routed.xml.gz -- pop.xml.gz plus routing.  Saves
much computing time in zeroth iteration.
* pop-routed-accessegress.xml.gz -- Same as 
pop-routed.xml.gz, but using the "accessEgressRouting" of 
MATSim.  Means that there are additional access/egressWalk
leg in particular to/from car legs.  Useful in particular for
multi-modal routing when some links do not have all
modes (i.e. you may have to walk to a different link if you
use bicycle then if you drive).

##### lower resolution network

I then removed very narrow links (like much
of the inner city links in Melbourne), since they make
handling very slow, and screwed up traffic dynamics downtown.
Needs to be investigated.

* net.xml.gz -- Probably that lower resolution network file.
* plans-file-new-29-nov.xml.gz -- File that is consistent with this other network (I think).

### Contributors

* Kai Nagel, TU Berlin
* Karthikey Surineni, RMIT University (very initial documentation)




