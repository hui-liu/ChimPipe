#!/bin/bash

<<authors
*****************************************************************************
	
	ChimPipe.sh
	
	This file is part of the ChimPipe pipeline 

	Copyright (c) 2014 Bernardo Rodríguez-Martín 
					   Emilio Palumbo 
					   Sarah Djebali 
	
	Computational Biology of RNA Processing group
	Department of Bioinformatics and Genomics
	Centre for Genomic Regulation (CRG)
					   
	Github repository - https://github.com/Chimera-tools/ChimPipe
	
	Documentation - https://chimpipe.readthedocs.org/

	Contact - chimpipe.pipeline@gmail.com
	
	Licenced under the GNU General Public License 3.0 license.
******************************************************************************
authors

# FUNCTIONS
############

# Function 1. Print basic usage information
############################################
function usage
{
cat <<help
	
**** ChimPipe version $version ****

Execute ChimPipe on one Illumina paired-end RNA-seq dataset (sample).
	
*** USAGE

FASTQ:

	$0 --fastq_1 <mate1_fastq> --fastq_2 <mate2_fastq> -g <genome_index> -a <annotation> -t <transcriptome_index> -k <transcriptome_keys> [OPTIONS]

BAM:	

	$0 --bam <bam> -g <genome_index> -a <annotation> [OPTIONS]

*** MANDATORY ARGUMENTS
		
* FASTQ:

	--fastq_1			<FASTQ>		First mate sequencing reads in FASTQ format. It can be gzip compressed [.gz].
	--fastq_2			<FASTQ>		Second mate sequencing reads in FASTQ format. It can be gzip compressed [.gz].
	-g|--genome-index		<GEM>		Reference genome index in GEM format.
	-a|--annotation			<GTF>		Reference gene annotation file in GTF format.                                			
	-t|--transcriptome-index	<GEM>		Annotated transcriptome index in GEM format.
	-k|--transcriptome-keys		<KEYS>		Transcriptome to genome coordinate conversion keys.  
	--sample-id			<STRING>	Sample identifier (output files are named according to this id).  
	
* BAM:	

	--bam				<BAM>		Mapped reads in BAM format. A splicing aware aligner is needed to map the reads. 
	-g|--genome-index		<GEM>		Reference genome index in GEM format.
	-a|--annotation			<GTF>		Reference genome annotation file in GTF format.
	--sample-id			<STRING>	Sample identifier (the output files will be named according to this id).  
	
*** [OPTIONS] can be:

* General: 
	--log				<STRING>	Log level [error | warn | info | debug]. Default warn.
	--threads			<INTEGER>	Number of threads to use. Default 1.
	-o|--output-dir			<PATH>		Output directory. Default current working directory. 
	--tmp-dir			<PATH>		Temporary directory. Default /tmp.	
	--no-cleanup					Keep intermediate files. 		
	--dry						Test the pipeline. Writes the commands to the standard output.
	-h|--help					Display partial usage information, only mandatory plus general arguments.
	-f|--full-help					Display full usage information with additional options. 

help
}


# Function 2. Print all the other options
##########################################
function usage_long
{
cat <<help
* Read information:
	--max-read-length		<INTEGER>	Maximum read length. This is used to create the de-novo transcriptome and acts as an upper bound. Default 150.
	-l|--seq-library 		<STRING> 	Type of sequencing library [MATE1_SENSE | MATE2_SENSE | UNSTRANDED].
                        				UNSTRANDED for not strand-specific protocol (unstranded data) and the others for the different types 
							of strand-specific protocols (stranded data).
* Mapping phase parameters
                        				
  First mapping:
	-C|--consensus-ss-fm		<(couple_1)>, ... ,<(couple_s)>	with <couple> := <donor_consensus>+<acceptor_consensus>
                                 			List of couples of donor/acceptor splice site consensus sequences. Default='GT+AG,GC+AG,ATATC+A.,GTATC+AT'
	-S|--min-split-size-fm		<INTEGER>	Minimum split size for the segmental mapping steps. Default 15.
	--refinement-step-size-fm   	<INTEGER>   	If not mappings are found a second attempt is made by eroding "N" bases toward the ends of the read. 
							A value of 0 disables it. Default 2. 
	--no-stats					Disable mapping statistics. Default enabled.

  Second Mapping:
	-c|--consensus-ss-sm		<(couple_1)>, ... ,<(couple_s)>	List of couples of donor/acceptor splice site consensus sequences. Default='GT+AG'
	-s|--min-split-size-sm		<INTEGER>	Minimum split size for the segmental mapping steps. Default 15.
	--refinement-step-size-sm   	<INTEGER>   	If not mappings are found a second attempt is made by eroding "N" bases toward the ends of the read. 
							A value of 0 disables it. Default 2. 
    
* Chimera detection phase parameters:

	--similarity-gene-pairs	<TEXT>			Text file with similarity information between the gene pairs in the annotation.
							Needed for the filtering module to discard chimeric junctions connecting highly similar genes. 
							If this file is not provided it will be computed by ChimPipe.
													
help
}

# Function 3. Display a link to ChimPipe's documentation
########################################################
function doc
{
cat <<help
A complete documentation for ChimPipe can be found at: http://chimpipe.readthedocs.org/en/latest/index.html		
help
}

# Function 4. Short help 
#########################
function usagedoc
{
usage
doc
}

# Function 5. Long help 
#########################
function usagelongdoc
{
usage
usage_long
doc
}

# Function 6. Print a section header for the string variable
##############################################################
function printHeader {
    string=$1
    echo "`date` ***** $string *****"
}

# Function 7. Print a subsection header for the string variable
################################################################
function printSubHeader {
    string=$1
    echo "`date` * $string *"
}

# Function 8. Print log information (Steps and errors)
#######################################################
function log {
    string=$1
    label=$2
    if [[ ! $ECHO ]];then
        if [[ "$label" != "" ]];then
            printf "[$label] $string"
        else
            printf "$string"
        fi
    fi
}

# Function 6. Execute and print to stdout commands 
###################################################
function run {
    command=($1)
    if [[ $2 ]];then
         ${2}${command[@]}
    else
        echo -e "\n"" "${command[@]}
        eval ${command[@]}
    fi
}

# Function 7. Copy annotation, genome index, transcriptome index 
#################################################################
# and keys to the temporary directory
#####################################
function copyToTmp {
    IFS=',' read -ra files <<< "$1"
    for i in ${files[@]};do
        case $i in
            "annotation")
                if [[ ! -e $TMPDIR/`basename $annot` ]];then
                    log "Copying annotation file to $TMPDIR..." $step
                    run "cp $annot $TMPDIR" "$ECHO"
                    log "done\n"
                fi
                ;;
            "index")
                if [[ ! -e $TMPDIR/`basename $genomeIndex` ]];then
                    log "Copying genome index file to $TMPDIR..." $step
                    run "cp $genomeIndex $TMPDIR" "$ECHO"
                    log "done\n"
                fi
                ;;
            "t-index")
                if [[ ! -e $TMPDIR/`basename $transcriptomeIndex` ]];then
                    log "Copying annotated transcriptome index file to $TMPDIR..." $step
                    run "cp $transcriptomeIndex $TMPDIR" "$ECHO"
                    log "done\n"
                fi
                ;;
            "keys")
                if [[ ! -e $TMPDIR/`basename $transcriptomeKeys` ]];then
                    log "Copying annotated transcriptome keys file to $TMPDIR..." $step
                    run "cp $transcriptomeKeys $TMPDIR" "$ECHO"
                    log "done\n"
                fi
                ;;
            esac
    done
}

# Function 8. Run the gemtools RNA-Seq pipeline to map all the reads  
###################################################################
# to the genome, to the transcriptome and de-novo
##################################################
# Input files:
# - $fastq1 
# - $fastq2
# - $genomeIndex
# - $annot
# - $transcriptomeIndex
# - $transcriptomeKeys
# Output files:
# -	${lid}_firstMap.map.gz
# - ${lid}_firstMap.stats.txt
# - ${lid}_firstMap.stats.json


function firstMapping_FASTQinput {

	# 1.1) Produce a filtered and sorted bam file with the aligments
	####################################################	
	if [ ! -s $gemFirstMap ]; 
	then
		step="FIRST-MAP"
		startTimeFirstMap=$(date +%s)
		printHeader "Executing first mapping step"    
	    
		## Copy needed files to TMPDIR
		copyToTmp "index,annotation,t-index,keys"

		log "Running GEMtools rna pipeline on ${lid}..." $step
		run "$gemtools --loglevel $logLevel rna-pipeline -f $fastq1 $fastq2 -i $TMPDIR/`basename $genomeIndex` -a $TMPDIR/`basename $annot` -r $TMPDIR/`basename $transcriptomeIndex` -k $TMPDIR/`basename $transcriptomeKeys` -q $quality --max-read-length $maxReadLength --max-intron-length 300000000 --min-split-size $splitSizeFM --refinement-step $refinementFM --junction-consensus $spliceSitesFM --no-filtered --no-bam --no-xs $stats --no-count -n `basename ${gemFirstMap%.map.gz}` --compress-all --output-dir $TMPDIR -t $threads >> $firstMappingDir/${lid}_firstMap.log 2>&1" "$ECHO" 
   
	   	if [ -s $TMPDIR/`basename $gemFirstMap` ]; 
	   	then 
			# Copy files from temporary to output directory
		    run "cp $TMPDIR/`basename $gemFirstMap` $gemFirstMap" "$ECHO"	       	    
	   		endTimeFirstMap=$(date +%s)        		
			printHeader "First mapping for $lid completed in $(echo "($endTimeFirstMap-$startTimeFirstMap)/60" | bc -l | xargs printf "%.2f\n") min"
	   	else
       	    log "Error running the GEMtools pipeline file\n" "ERROR"
       	    exit -1
	   	fi		
	else
    	printHeader "First mapping GEM file already exists... skipping first mapping step"
	fi
		
	# 1.2) Produce a filtered SAM file with the aligments
	####################################################
	gemFirstMapFiltered=$firstMappingDir/${lid}_firstMap_filtered.map.gz
		
	if [ ! -s $gemFirstMapFiltered ];
	then
		step="FIRST-MAP.FILTERMAP"
		startTime=$(date +%s)
		printSubHeader "Executing conversion GEM to BAM step"
		run "$gtFilterRemove -i $gemFirstMap --max-matches 10 --max-levenshtein-error 4 -t $hthreads | $pigz -p $hthreads > $gemFirstMapFiltered" "$ECHO"
		
		if [ -s $gemFirstMapFiltered ];
		then
			endTime=$(date +%s)
			printSubHeader "Conversion step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
		else
			log "Error producing the bam file\n" "ERROR"
			exit -1
		fi
	else
		printSubHeader "First mapping BAM file already exists... skipping conversion step"
	fi
	
	# 1.3) Convert the SAM into a sortered BAM file
	#################################################	
	step="FIRST-MAP.CONVERT2BAM"
	startTime=$(date +%s)
	printSubHeader "Executing conversion GEM to BAM step"

	## Copy needed files to TMPDIR
	copyToTmp "index"	
	log "Converting $lid to bam..." $step
	run "$pigz -p $hthreads -dc $gemFirstMapFiltered | $gem2sam -T $hthreads -I $TMPDIR/`basename $genomeIndex` --expect-paired-end-reads -q offset-$quality -l | samtools view -@ $threads -bS - | samtools sort -@ $threads -m 4G - ${bamFirstMap%.bam} >> $firstMappingDir/${lid}_map2bam_conversion.log 2>&1" "$ECHO"
	if [ -s $bamFirstMap ];
	then
		endTime=$(date +%s)
		printSubHeader "Conversion step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
	else
		log "Error producing the bam file\n" "ERROR"
		exit -1
	fi
		
}


# Function 9. Parse user's input
################################
function getoptions {
ARGS=`$getopt -o "g:a:t:k:o:hfl:C:S:c:s:" -l "fastq_1:,fastq_2:,bam:,genome-index:,annotation:,transcriptome-index:,transcriptome-keys:,sample-id:,log:,threads:,output-dir:,tmp-dir:,no-cleanup,dry,help,full-help,max-read-length:,seq-library:,consensus-ss-fm:,min-split-size-fm:,refinement-step-size-fm:,no-stats,consensus-ss-sm:,min-split-size-sm:,refinement-step-size-sm:,similarity-gene-pairs:" \
      -n "$0" -- "$@"`
	
#Bad arguments
if [ $? -ne 0 ];
then
  exit 1
fi

# A little magic
eval set -- "$ARGS"

while true;
do
  case "$1" in
   	
   	## MANDATORY ARGUMENTS
      --fastq_1)
	  if [ -n "$2" ];
	  then
              fastq1=$2
	  fi
	  shift 2;;
      
      --fastq_2)
	  if [ -n "$2" ];
	  then
              fastq2=$2
	  fi
	  shift 2;;
      
      --bam)
	  if [ -n "$2" ];
	  then
              bamFirstMap=$2
              bamAsInput="TRUE"
	  fi
	  shift 2;;
      
      -g|--genome-index)
	  if [ -n "$2" ];
	  then
              genomeIndex=$2
	  fi
	  shift 2;;

      -a|--annotation)
	  if [ -n "$2" ];
	  then
              annot=$2
	  fi
	  shift 2;;
      
      -t|--transcriptome-index)
	  if [ -n "$2" ];
	  then
              transcriptomeIndex=$2
	  fi
	  shift 2;;
    
      -k|--transcriptome-keys)
	  if [ -n "$2" ];
	  then
              transcriptomeKeys=$2
	  fi
	  shift 2;;    
	
      --sample-id)
	  if [ -n "$2" ];
	  then
              lid=$2
	  fi
	  shift 2;;
       
    ## OPTIONS
    
	# General:
    
      --log)
	  if [ -n $2 ];
	  then
              logLevel=$2
	  fi
	  shift 2;;
	
      --threads)
	  if [ -n $2 ];
	  then
      	      threads=$2
	  fi
	  shift 2;;
       	 
	-o|--output-dir)
	  if [ -n $2 ];
	  then
       	      outDir=$2
	  fi
	  shift 2;;
      
      --tmp-dir)
      	  if [ -n $2 ];
      	  then
              TMPDIR=$2
      	  fi
      	  shift 2;;
      
      --no-cleanup)
	  cleanup="FALSE";
	  shift;;   	
      
      --dry)
	  ECHO="echo "
	    shift;;

      -h|--help)
	  usagedoc;
	  exit 1
	  shift;;
      
      -f|--full-help)
	  usagelongdoc;
	  exit 1
	  shift;;	
    
    # Reads information:
      --max-read-length)
	  if [ -n $2 ];
	  then
              maxReadLength=$2
	  fi
	  shift 2;;
      
      -l|--seq-library)
	  if [ -n $2 ];
	  then
              readDirectionality=$2
	  fi
	  shift 2;;
     
    # First mapping parameters: 
      -C|--consensus-ss-fm)
	  if [ -n "$2" ];
	  then
	      spliceSitesFM=$2
	  fi
	  shift 2;;
      
    -S|--min-split-size-fm)
    	  if [ -n "$2" ];
	  then
	      splitSizeFM=$2
	  fi
	  shift 2;;
      
      --refinement-step-size-fm)
	  if [ -n "$2" ];
	  then
	      refinementFM=$2
	  fi
	  shift 2;;
      
      --no-stats)
    	  if [ -n "$2" ];
	  then
	      mapStats="FALSE"  
	  fi
	  shift;;
      
	# Second mapping parameters:
      
      -c|--consensus-ss-sm)
	  if [ -n "$2" ];
	  then
	      spliceSitesSM=$2
	  fi
	  shift 2;;
	
      -s|--min-split-size-sm)
    	  if [ -n "$2" ];
	  then
	      splitSizeSM=$2
	  fi
	  shift 2;;
	
      --refinement-step-size-sm)
	  if [ -n "$2" ];
	  then
	      refinementSM=$2
	  fi
	  shift 2;;
	
	# Chimera detection phase parameters:
      
      --filter-chimeras)
	  if [ -n $2 ];
	  then
	      filterConf="$2"
	  fi
	  shift 2;;
      
      --similarity-gene-pairs)
	  if [ -n $2 ];
	  then
	      simGnPairs="$2"
	  fi
	  shift 2;;
      
      --)
	  shift
	  break;;  
  esac
done
}


# SETTING UP THE ENVIRONMENT
############################

# ChimPipe version 
version=v0.8.8

# Enable extended pattern matching 
shopt -s extglob

# 1. ChimPipe's root directory
##############################
# It will be exported as an environmental variable since it will be used by every ChimPipe's scripts 
# to set the path to the bin, awk and bash directories. 
root=/nfs/users/rg/sdjebali/Chimeras/ChimPipe

export rootDir=$root 

# 2. Parse input arguments with getopt  
######################################
getopt=$root/bin/getopt

getoptions $0 $@ # call Function 5 and passing two parameters (name of the script and command used to call it)

# 3. Check input variables 
##########################

## Mandatory arguments
## ~~~~~~~~~~~~~~~~~~~

if [[ "$bamAsInput" != "TRUE" ]];
then
	## A) FASTQ as input
	bamAsInput="FALSE";
	if [[ ! -e $fastq1 ]]; then log "The mate 1 FASTQ provided does not exist. Mandatory argument --fastq_1\n" "ERROR" >&2; usagedoc; exit -1; fi
	if [[ ! -e $fastq2 ]]; then log "The mate 2 FASTQ provided does not exist. Mandatory argument --fastq_2\n" "ERROR" >&2; usagedoc; exit -1; fi
	if [[ ! -e $transcriptomeIndex ]]; then log "The transcriptome index provided does not exist. Mandatory argument -t|--transcriptome-index\n" "ERROR" >&2; usagedoc; exit -1; fi
	if [[ ! -e $transcriptomeKeys ]]; then log "The transcriptome keys provided do not exist. Mandatory argument -k|--transcriptome-keys\n" "ERROR" >&2; usagedoc; exit -1; fi
else
	## B) BAM as input
	if [[ ! -e $bamFirstMap ]]; then log "The BAM provided do not exist. Mandatory argument --bam\n" "ERROR" >&2; usagedoc; exit -1; fi
fi
	
## Common
if [[ ! -e $genomeIndex ]]; then log "The genome index provided does not exist. Mandatory argument -g|--genome-index\n" "ERROR" >&2; usagedoc; exit -1; fi
if [[ ! -e $annot ]]; then log "The annotation provided does not exist. Mandatory argument -a|--annotation\n" "ERROR" >&2; usagedoc; exit -1; fi
if [[ "$lid" == "" ]]; then log "Please provide a sample identifier. Mandatory argument --sample-id\n" "ERROR" >&2; usagedoc; exit -1; fi


## Optional arguments
## ~~~~~~~~~~~~~~~~~~

# General
# ~~~~~~~

# Log level
if [[ "$logLevel" == "" ]]; 
then 
	logLevel='warn'; 
else	
	if [[ "$logLevel" != @(error|warn|info|debug) ]];
	then
		log "Please specify a proper log status [error||warn||info||debug]. Option -l|--log\n" "ERROR" >&2;
		usagedoc;
		exit -1; 
	fi
fi

# Number of threads
if [[ "$threads" == "" ]]; 
then 
	threads='1'; 
else
	if [[ ! "$threads" =~ ^[0-9]+$ ]]; 
	then
		log "Please specify a proper threading value. Option -t|--threads\n" "ERROR" >&2;
		usagedoc;
		exit -1; 
	fi
fi

if [[ "$threads" == "1" ]]; 
then 
	hthreads='1'; 
else 
	hthreads=$((threads/2)); 
fi	

# Output directory
if [[ "$outDir" == "" ]]; 
then 
	outDir=${SGE_O_WORKDIR-$PWD};
else
	if [[ ! -e "$outDir" ]]; 
	then
		log "Your output directory does not exist. Option -o|--output-dir\n" "ERROR" >&2;
		usagedoc; 
		exit -1; 
	fi	
fi

# Temporary directory
if [[ "$TMPDIR" == "" ]]; 
then 
	TMPDIR='/tmp'; 
else	
	if [[ ! -e "$TMPDIR" ]]; 
	then
		log "Your temporary directory does not exist. Option --tmp-dir\n" "ERROR" >&2;
		usagedoc; 
		exit -1; 
	fi
fi

# Clean up
if [[ "$cleanup" != "FALSE" ]]; 
then 
    cleanup='TRUE'; 
fi	

# Reads information:
# ~~~~~~~~~~~~~~~~~~
# Maximum read length

if [[ "$maxReadLength" == "" ]]; 
then 
    maxReadLength='150'; 
else
    if [[ ! "$maxReadLength" =~ ^[0-9]+$ ]]; 
    then
		log "Please specify a proper maximum read length value for mapping. Option --max-read-length\n" "ERROR" >&2;
		usagelongdoc;
	exit -1; 
    fi
fi

# Sequencing library type
if [[ "$readDirectionality" != "" ]];
then
    if [[ "$readDirectionality" == @(MATE1_SENSE|MATE2_SENSE) ]];
    then
		stranded=1;
    elif [[ "$readDirectionality" == "UNSTRANDED" ]];
    then
		stranded=0;
    else
		log "Please specify a proper sequencing library [UNSTRANDED|MATE1_SENSE|MATE2_SENSE]\n" "ERROR" >&2;
		usagedoc; 
	exit -1;	
    fi
else
    readDirectionality="UNKNOWN"
fi 	

# First mapping parameters:
# ~~~~~~~~~~~~~~~~~~~~~~~~~

# Consensus splice sites for the segmental mapping
if [[ "$spliceSitesFM" == "" ]]; 
then 
    spliceSitesFM="GT+AG,GC+AG,ATATC+A.,GTATC+AT"; 
else			
    if [[ ! "$spliceSitesFM" =~ ^([ACGT.]+\+[ACGT.]+,)*([ACGT.]+\+[ACGT.]+)$ ]];
    then
	log "Please specify a proper consensus splice site sequence for the first segmental mapping. Option -C|--consensus-ss-fm\n" "ERROR" >&2;
	usagelongdoc;
	exit -1; 
    fi
fi

# Minimum split size for the segmental mapping
if [[ "$splitSizeFM" == "" ]];
then 
    splitSizeFM='15'; 
else
    if [[ ! "$splitSizeFM" =~ ^[0-9]+$ ]]; 
    then
	log "Please specify a proper minimum split size for the first segmental mapping step. Option -S|--min-split-size-fm\n" "ERROR" >&2;
	usagelongdoc; 
	exit -1; 
    fi
fi

# Refinement size for the segmental mapping
if [[ "$refinementFM" == "" ]];
then 
    refinementFM='2'; 
else
    if [[ ! "$refinementFM" =~ ^[0-9]+$ ]]; 
    then
	log "Please specify a proper refinement size for the first segmental mapping step. Option --refinement-step-size-fm\n" "ERROR" >&2;
	usagelongdoc; 
	exit -1; 
    fi
fi

# First mapping statistics
if [[ "$mapStats" == "FALSE" ]]; 
then 
    stats="--no-stats"; 
else
	mapStats="TRUE";
fi

# Second mapping parameters:
# ~~~~~~~~~~~~~~~~~~~~~~~~~~


# Consensus splice sites for the segmental mapping
if [[ "$spliceSitesSM" == "" ]]; 
then 
    spliceSitesSM="GT+AG"; 
else			
    if [[ ! "$spliceSitesSM" =~ ^([ACGT.]+\+[ACGT.]+,)*([ACGT.]+\+[ACGT.]+)$ ]];
    then
	log "Please specify a proper consensus splice site sequence for the second segmental mapping. Option -c|--consensus-ss-sm\n" "ERROR" >&2;
	usagelongdoc; 
	exit -1; 
    fi
fi

# Minimum split size for the segmental mapping
if [[ "$splitSizeSM" == "" ]];
then 
    splitSizeSM='15'; 
else
    if [[ ! "$splitSizeSM" =~ ^[0-9]+$ ]]; 
    then
	log "Please specify a proper minimum split size for the second segmental mapping step. Option -s|--min-split-size-sm\n" "ERROR" >&2;
	usagelongdoc; 
	exit -1; 
    fi
fi

# Refinement size for the segmental mapping
if [[ "$refinementSM" == "" ]];
then 
    refinementSM='2'; 
else
    if [[ ! "$refinementSM" =~ ^[0-9]+$ ]]; 
    then
	log "Please specify a proper refinement size for the second segmental mapping step. Option --refinement-step-size-sm\n" "ERROR" >&2;
	usagelongdoc; 
	exit -1; 
    fi
fi

# Chimera detection phase parameters:
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Filtering module configuration	
if [[ "$filterConf" == "" ]]; 
then 			
    filterConf="5,0,80,30;1,1,80,30;";		# Default
else
    if [[ ! "$filterConf" =~ ^([0-9]+,[0-9]+,[0-9]{,3},[0-9]+;){1,2}$ ]]; 
    then
	log "Please check your filtering module configuration. Option --filter-chimeras\n" "ERROR" >&2; 
	usagelongdoc; 
	exit -1;
    fi
fi

# Similarity between gene pairs file
if [[ "$simGnPairs" == "" ]]
then
    simGnPairs="NOT PROVIDED";
elif [ ! -s "$simGnPairs" ]
then 
    log "Your text file containing similarity information between gene pairs in the annotation does not exist. Option --similarity-gene-pairs\n" "ERROR" >&2; 
    usagelongdoc; 
    exit -1; 
fi


# 4. Directories
################
## binaries and scripts
binDir=$rootDir/bin
awkDir=$rootDir/src/awk
bashDir=$rootDir/src/bash

## Output files directories
# 1. Mapping phase
mappingPhaseDir=$outDir/MappingPhase
firstMappingDir=$mappingPhaseDir/FirstMapping
secondMappingDir=$mappingPhaseDir/SecondMapping

# 2. Chimera detection phase
chimeraDetPhaseDir=$outDir/ChimeraDetectionPhase
splicedReadsGFFDir=$chimeraDetPhaseDir/ReadsSpanningSpliceJunctions
chimJuncDir=$chimeraDetPhaseDir/ChimericSpliceJunctions
PEsupportDir=$chimeraDetPhaseDir/PEsupport
genePairSimDir=$chimeraDetPhaseDir/genePairSim

# The temporary directory will be exported as an environmental variable since it will 
# be used by every ChimPipe's scripts 
export TMPDIR=$TMPDIR

# 5. Programs/Scripts
#####################
# Bash 
qual=$bashDir/detect.fq.qual.sh
addXS=$bashDir/sam2cufflinks.sh
infer_library=$bashDir/infer_library_type.sh
chim1=$bashDir/find_exon_exon_connections_from_splitmappings.sh
chim2=$bashDir/find_chimeric_junctions_from_exon_to_exon_connections.sh
findGeneConnections=$bashDir/find_gene_to_gene_connections_from_pe_rnaseq.sh
sim=$bashDir/similarity_bt_gnpairs.sh

# Bin 
gemtools=$binDir/gemtools-1.7.1-i3/gemtools
gemrnatools=$binDir/gemtools-1.7.1-i3/gem-rna-tools
gtFilterRemove=$binDir/gemtools-1.7.1-i3/gt.filter.remove
gem2sam=$binDir/gemtools-1.7.1-i3/gem-2-sam
pigz=$binDir/pigz

# Awk 
addMateInfoSam=$awkDir/add_mateInfo_SAM.awk
gff2Gff=$awkDir/gff2gff.awk
SAMfilter=$awkDir/SAMfilter.awk
bed2bedPE=$awkDir/bed2bedPE.awk
bedPECorrectStrand=$awkDir/bedPECorrectStrand.awk
bedPE2gff=$awkDir/bedPE2gff.awk
gemCorrectStrand=$awkDir/gemCorrectStrand.awk
gemToGff=$awkDir/gemsplit2gff_unique.awk
addPEinfo=$awkDir/add_PE_info.awk
AddSimGnPairs=$awkDir/add_sim_bt_gnPairs.awk
juncFilter=$awkDir/chimjunc_filter.awk


## DISPLAY PIPELINE CONFIGURATION  
##################################
printf "\n"
header="PIPELINE CONFIGURATION FOR $lid"
echo $header
eval "for i in {1..${#header}};do printf \"-\";done"
printf "\n\n"
printf "  %-34s %s\n\n" "ChimPipe Version $version"
printf "  %-34s %s\n" "***** MANDATORY ARGUMENTS *****"

if [[ "$bamAsInput" == "FALSE" ]];
then
	## A) FASTQ as input
	printf "  %-34s %s\n" "fastq_1:" "$fastq1"
	printf "  %-34s %s\n" "fastq_2:" "$fastq2"
	printf "  %-34s %s\n" "genome-index:" "$genomeIndex"
	printf "  %-34s %s\n" "annotation:" "$annot"
	printf "  %-34s %s\n" "transcriptome-index:" "$transcriptomeIndex"
	printf "  %-34s %s\n" "transcriptome-keys:" "$transcriptomeKeys"
	printf "  %-34s %s\n\n" "sample-id:" "$lid"

	printf "  %-34s %s\n" "** Reads information **"
	printf "  %-34s %s\n" "seq-library:" "$readDirectionality"
	printf "  %-34s %s\n\n" "max-read-length:" "$maxReadLength"

	printf "  %-34s %s\n" "***** MAPPING PHASE *****"
	printf "  %-34s %s\n" "** 1st mapping **"
	printf "  %-34s %s\n" "consensus-ss-fm:" "$spliceSitesFM"
	printf "  %-34s %s\n" "min-split-size-fm:" "$splitSizeFM"
	printf "  %-34s %s\n" "refinement-step-size-fm (0:disabled):" "$refinementFM"
	printf "  %-34s %s\n\n" "stats:" "$mapStats"
else
	## B) BAM as input
	printf "  %-34s %s\n" "bam:" "$bamFirstMap"
	printf "  %-34s %s\n" "genome-index:" "$genomeIndex"
	printf "  %-34s %s\n" "annotation:" "$annot"
	printf "  %-34s %s\n\n" "sample-id:" "$lid"

	printf "  %-34s %s\n" "** Reads information **"
	printf "  %-34s %s\n" "seq-library:" "$readDirectionality"
	printf "  %-34s %s\n\n" "max-read-length:" "$maxReadLength"
	
	printf "  %-34s %s\n" "***** MAPPING PHASE *****"
fi

printf "  %-34s %s\n" "** 2nd mapping **"
printf "  %-34s %s\n" "consensus-ss-fm:" "$spliceSitesSM"
printf "  %-34s %s\n" "min-split-size-fm:" "$splitSizeSM"
printf "  %-34s %s\n\n" "refinement-step-size-fm (0:disabled):" "$refinementSM"

printf "  %-34s %s\n" "***** CHIMERA DETECTION PHASE *****"
printf "  %-34s %s\n\n" "similarity-gene-pairs:" "$simGnPairs"

printf "  %-34s %s\n" "***** GENERAL *****"
printf "  %-34s %s\n" "output-dir:" "$outDir"
printf "  %-34s %s\n" "tmp-dir:" "$TMPDIR"
printf "  %-34s %s\n" "threads:" "$threads"
printf "  %-34s %s\n" "log:" "$logLevel"
printf "  %-34s %s\n\n" "no-cleanup:" "$cleanup"



###################
## START CHIMPIPE #
###################
header="Executing ChimPipe $version for $lid"
echo $header
eval "for i in {1..${#header}};do printf \"-\";done"
printf "\n\n"
pipelineStart=$(date +%s)

#######################    	
# 0) PRELIMINAR STEPS #
#######################

## Make directories
# 1. Mapping phase
if [[ ! -d $mappingPhaseDir ]]; then mkdir $mappingPhaseDir; fi
if [ ! -d $firstMappingDir ]; then mkdir $firstMappingDir; fi
if [[ ! -d $secondMappingDir ]]; then mkdir $secondMappingDir; fi

# 2. Chimera detection phase
if [[ ! -d $chimeraDetPhaseDir ]]; then mkdir $chimeraDetPhaseDir; fi
if [[ ! -d $splicedReadsGFFDir ]]; then mkdir $splicedReadsGFFDir; fi
if [[ ! -d $chimJuncDir ]]; then mkdir $chimJuncDir; fi
if [[ ! -d $PEsupportDir ]]; then mkdir $PEsupportDir; fi

## Check quality offset if FASTQ as input
if [[ "$bamAsInput" == "FALSE" ]];
then
	step="PRELIM"
	log "Determining the offset quality of the reads for ${lid}..." $step
	run "quality=\`$qual $fastq1 | awk '{print \$2}'\`" "$ECHO" 
	log " The read quality is $quality\n"
	log "done\n"
else
	quality="33"
fi

## Define variable with annotation name
b=`basename $annot`
b2tmp=${b%.gtf}
b2=${b2tmp%.gff}
    	
    	
####################    	
# 1) MAPPING PHASE #
####################
 	
# 1.1) First mapping step (skipped if BAM as input). Map all the reads to the genome, to the transcriptome and de-novo, using the 
#################################################################################################
# gemtools RNA-Seq pipeline but with max intron size larger than the biggest chromosome, and with 
##################################################################################################  
# a number of mismatches of round(read_length/6) an edit distance of round(read_length/20) 
##########################################################################################
# outputs are: 
##############
# - $outDir/${lid}.map.gz 
# - $outDir/${lid}_raw_chrSorted.bam


if [[ "$bamAsInput" == "FALSE" ]];
then
	gemFirstMap=$firstMappingDir/${lid}_firstMap.map.gz
	bamFirstMap=$firstMappingDir/${lid}_firstMap.bam
	
	if [ ! -s $bamFirstMap ]; 
	then

		firstMapping_FASTQinput		## Call function to run the gemtools rna-pipeline
	else
		printHeader "First mapping BAM file already exists... skipping first mapping step";
	fi
else
	printHeader "BAM file provided as input... skipping first mapping step";
fi


# 1.2) Extract first mapping unmapped reads for a second split-mapping
##########################################################################
# attemp allowing split-mappings in different chromosomes, strands 
######################################################################
# and non genomic order. Produce a FASTQ file with them. 
########################################################
# output is: 
############
# - $outDir/${lid}_reads2remap.fastq

## Comment: samtools view -f 4  ** extract unmapped reads  

reads2remap=$secondMappingDir/${lid}_reads2remap.fastq


if [ ! -s $reads2remap ]; 
then
	step="READS2REMAP"
	startTime=$(date +%s)
	printHeader "Executing extract reads to remap step" 
	run "samtools view -h -f 4 -@ $threads $bamFirstMap | awk -v OFS="'\\\t'" -f $addMateInfoSam | samtools view -@ $threads -bS - | bedtools bamtofastq -i - -fq $reads2remap >> $secondMappingDir/${lid}_reads2remap.log 2>&1" "$ECHO"	

    if [ -s $reads2remap ]; 
    then
        endTime=$(date +%s)
		printHeader "Extracting reads completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
    else	    
        log "Error extracting the reads\n" "ERROR" 
        exit -1
	fi
else
    printHeader "FASTQ file with reads to remap already exists... skipping extracting reads to remap step"
fi

# 1.3) Second split-mapping attemp. Remap the extracted reads allowing reads 
###########################################################################
# to split in different chromosomes, strands and non genomic order.
###################################################################
# output is: 
############
# - $outDir/SecondMapping/${lid}.remapped.map

gemSecondMap=$secondMappingDir/${lid}_secondMap.map

if [ ! -s $gemSecondMap ];
then
	step="SECOND-MAP"
	startTime=$(date +%s)
	printHeader "Executing second split-mapping step"
	log "Remapping reads allowing them to split-map in different chromosomes, strand and non genomic order..." $step	
	run "$gemrnatools split-mapper -I $genomeIndex -i $reads2remap -q 'offset-33' -o ${gemSecondMap%.map} -t 10 -T $threads --min-split-size $splitSizeSM --refinement-step-size $refinementSM --splice-consensus $spliceSitesSM  >> $secondMappingDir/${lid}_secondMap.log 2>&1" "$ECHO"
	
	if [ ! -s $gemSecondMap ]; 
	then
        log "Error in the second mapping\n" "ERROR" 
        exit -1
    fi
    endTime=$(date +%s)
	printHeader "Unmapped reads mapping step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "Second mapping GEM file already exists... skipping extracting second mapping step"
fi
	

# 1.4) Infer the sequencing library protocol used (UNSTRANDED, MATE2_SENSE OR MATE1_SENSE) 
########################################################################################
# from a subset with the 1% of the mapped reads. 
#################################################
# Outputs are: 
##############
# - variables $readDirectionality and $stranded

if [[ "$readDirectionality" == "UNKNOWN" ]]; 
then 
    step="INFER-LIBRARY"
    startTimeLibrary=$(date +%s)
    printHeader "Executing infer library type step" 
    log "Infering the sequencing library protocol from a random subset with 1 percent of the mapped reads..." $step
    read fraction1 fraction2 other <<<$(bash $infer_library $bamFirstMap $annot)
    log "done\n"
    log "Fraction of reads explained by 1++,1--,2+-,2-+: $fraction1\n" $step
    log "Fraction of reads explained by 1+-,1-+,2++,2--: $fraction2\n" $step
    log "Fraction of reads explained by other combinations: $other\n" $step 
    
    # Turn the percentages into integers
    fraction1_int=${fraction1/\.*};
    fraction2_int=${fraction2/\.*};
    other_int=${other/\.*};
    
    # Infer the sequencing library from the mapping distribution. 
    if [ "$fraction1_int" -ge 70 ]; # MATE1_SENSE protocol
    then 
		readDirectionality="MATE1_SENSE";
		stranded=1;
		echo $readDirectionality;	
    elif [ "$fraction2_int" -ge 70 ];
    then	
		readDirectionality="MATE2_SENSE"; # MATE2_SENSE protocol
		stranded=1;
    elif [ "$fraction1_int" -ge 40 ] && [ "$fraction1_int" -le 60 ];
    then
		if [ "$fraction2_int" -ge 40 ] && [ "$fraction2_int" -le 60 ]; # UNSTRANDED prototol
		then
	    	readDirectionality="UNSTRANDED";
	    	stranded=0;
		else
	    	log "ChimPipe is not able to determine the library type. Ask your data provider and use the option -l|--seq-library\n" "ERROR" >&2;
	    	usagelongdoc
	    	exit -1	
		fi
    else
		log "ChimPipe is not able to determine the library type. Ask your data provider and use the option -l|--seq-library\n" "ERROR" >&2;
		usagelongdoc
		exit -1	
    fi
    log "Sequencing library type: $readDirectionality\n" $step 
    log "Strand aware protocol (1: yes, 0: no): $stranded\n" $step 
    endTimeLibrary=$(date +%s)
    printHeader "Sequencing library inference for $lid completed in $(echo "($endTimeLibrary-$startTimeLibrary)/60" | bc -l | xargs printf "%.2f\n") min"
else
    printHeader "Sequencing library type provided by the user...skipping library inference step"
fi

##############################    	
# 2) CHIMERA DETECTION PHASE #
##############################

# 2.1 filter out multimapped reads in the BAM file and produce a filtered BAM file 
###################################################################################
# containing uniquely mapped reads for chimera detection
#########################################################
# - $outDir/FromFirstBam/${lid}_splitmappings_2blocks_firstMap.gff.gz

filteredBamFirstMap=$firstMappingDir/${lid}_firstMap_filtered.bam

### Check in which field is the number of mappings
NHfield=`samtools view -F 4 $bamFirstMap | head -1 | awk 'BEGIN{field=1;}{while(field<=NF){ if ($field ~ "NH:i:"){print field;} field++}}'`

if [ ! -s $filteredBamFirstMap ]; 
then
	step="UNIQUE-BAM"
	startTime=$(date +%s)
	printHeader "Executing make BAM with unambiguosly mapped reads step"
	log "Generating a BAM file containing only unambiguously mapped reads for chimera detection..." $step
	run "samtools view -h $bamFirstMap | awk -v OFS="'\\\t'" -v unique="1" -v NHfield=$NHfield -f $SAMfilter | samtools view -@ $threads -bS - > $filteredBamFirstMap 2> $firstMappingDir/${lid}_bamFiltering.log" "$ECHO"
	
	if [ ! -s $filteredBamFirstMap ]; 
	then
        log "Error Generating the filtered BAM file\n" "ERROR" 
        exit -1
    fi
	endTime=$(date +%s)
	printHeader "Step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "filtered BAM file already exists... skipping filtering step"
fi

	
# 2.2) extract the reads spanning splice junctions from the filtered first mapping 
##########################################################################################
# bam file and convert in gff.gz
##################################
# output is: 
############
# - $outDir/FromFirstBam/${lid}_readsSpanningSpliceJunctions_firstMap.gff.gz

gffFromBam=$splicedReadsGFFDir/${lid}_readsSpanningSpliceJunctions_firstMap.gff.gz

if [ ! -s $gffFromBam ]; 
then
	step="SPLICED-READS1"
	startTime=$(date +%s)
	printHeader "Extract unambiguously spliced mapped reads from first mapping BAM step"
	log "Generating a GFF file with the aligment information of the reads spanning splice junctions..." $step
	bedtools bamtobed -i $filteredBamFirstMap -bed12 | awk '$10==2' | awk -v rev='1' -f $bed2bedPE | awk -v readDirectionality=$readDirectionality  -f $bedPECorrectStrand | awk -f $bedPE2gff | awk -f $gff2Gff | gzip > $gffFromBam 
	
	if [ ! -s $gffFromBam ]; 
	then
        log "Error Generating the gff file\n" "ERROR" 
        exit -1
    fi
	endTime=$(date +%s)
	printHeader "Step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "GFF from first mapping BAM file already exists... skipping extract reads spanning splice junctions step"
fi

# 2.3) extract the reads spanning splice junctions from the second mapping 
#################################################################################
# map file and convert in gff.gz
##################################
# output is: 
############
# - $outDir/FromSecondMapping/${lid}_splitmappings_2blocks_secondMap.gff.gz

gffFromMap=$splicedReadsGFFDir/${lid}_readsSpanningSpliceJunctions_secondMap.gff.gz

if [ ! -s $gffFromMap ]; 
then
	step="SPLICED-READS2"
	startTime=$(date +%s)
	printHeader "Extract unambiguously spliced mapped reads from second mapping filtered BAM step"
	log "Generating a GFF file with the aligment information of the reads spanning splice junctions..." $step	
	run "awk -v readDirectionality=$readDirectionality -f $gemCorrectStrand $gemSecondMap | awk -v rev="0" -f $gemToGff | awk -f $gff2Gff | gzip > $gffFromMap" "$ECHO"
	
	if [ ! -s $gffFromMap ]; 
	then
        log "Error Generating the GFF file\n" "ERROR" 
        exit -1
    fi
    endTime=$(date +%s)
	printHeader "Step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "GFF from second mapping GEM file already exists... skipping extract reads spanning splice junctions step"
fi


# 2.4) put the path to the first and second mapping spliced mapped reads gff.gz files in a same txt file for chimsplice 
########################################################################################################################

paths2chimsplice=$splicedReadsGFFDir/split_mapping_file_sample_$lid.txt

run "echo $gffFromBam > $paths2chimsplice" "$ECHO"
run "echo $gffFromMap >> $paths2chimsplice" "$ECHO"

# 2.5) run chimsplice on ..) and ..) 
###############################
# - $outDir/Chimsplice/chimeric_junctions_report_$lid.txt
# - $outDir/Chimsplice/distinct_junctions_nbstaggered_nbtotalsplimappings_withmaxbegandend_samechrstr_okgxorder_dist_ss1_ss2_gnlist1_gnlist2_gnname1_gnname2_bt1_bt2_from_split_mappings_part1overA_part2overB_only_A_B_indiffgn_and_inonegn.txt
# - $outDir/Chimsplice/distinct_junctions_nbstaggered_nbtotalsplimappings_withmaxbegandend_samechrstr_okgxorder_dist_ss1_ss2_gnlist1_gnlist2_gnname1_gnname2_bt1_bt2_from_split_mappings_part1overA_part2overB_only_A_B_indiffgn_and_inonegn_morethan10staggered.txt

exonConnections1=$chimJuncDir/exonA_exonB_with_splitmapping_part1overA_part2overB_readlist_sm1list_sm2list_staggeredlist_totalist_${lid}_readsSpanningSpliceJunctions_firstMap.txt.gz

exonConnections2=$chimJuncDir/exonA_exonB_with_splitmapping_part1overA_part2overB_readlist_sm1list_sm2list_staggeredlist_totalist_${lid}_readsSpanningSpliceJunctions_secondMap.txt.gz


printHeader "Executing Chimsplice step"
if [ ! -s $exonConnections1 ] || [ ! -s $exonConnections2 ]; 
then
	step="CHIMSPLICE"
	startTime=$(date +%s)
	log "Finding exon to exon connections from the GFF files containing the "normal" and "atypical" mappings..." $step
	run "$chim1 $paths2chimsplice $annot $chimJuncDir $stranded >> $chimJuncDir/find_exon_to_exon_connections_from_split-mapped_reads_$lid.err 2>&1" "$ECHO"
	
	if [ ! -s $exonConnections1 ] || [ ! -s $exonConnections2 ]; 
	then
        log "Error running chimsplice\n" "ERROR" 
        exit -1
    fi
    endTime=$(date +%s)
	printHeader "Find exon to exon connections step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "Exon to exon connections file already exists... skipping step"
fi

chimJunctions=$chimJuncDir/distinct_junctions_nbstaggered_nbtotalsplimappings_withmaxbegandend_samechrstr_okgxorder_dist_ss1_ss2_gnlist1_gnlist2_gnname1_gnname2_bt1_bt2_from_split_mappings_part1overA_part2overB_only_A_B_indiffgn_and_inonegn.txt

if [ ! -s $chimJunctions ]; 
then
	step="CHIMSPLICE"
	startTime=$(date +%s)
	log "Finding chimeric junctions from exon to exon connections..." $step
	run "$chim2 $paths2chimsplice $genomeIndex $annot $chimJuncDir $stranded $spliceSitesFM > $chimJuncDir/chimeric_junctions_report_$lid.txt 2> $chimJuncDir/find_chimeric_junctions_from_exon_to_exon_connections_$lid.err" "$ECHO"
	
	if [ ! -s $chimJunctions ]; 
	then
        log "Error running chimsplice\n" "ERROR" 
        exit -1
    fi
    endTime=$(date +%s)
	printHeader "Find chimeric junctions step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "Chimeric Junctions file already exists... skipping step"
fi

# 2.6) Find gene to gene connections supported by paired-end mappings from the bam file of "normal" mappings with the number of mappings supporting the connection.  
#################################################################################################################################################################
# For a connection g1 to g2 to exist there must be at least one mapping where the first mate is strandedly (if data is stranded) overlapping with an exon 
#########################################################################################################################################################
# of g1 and the second mate is (strandedly if data is stranded) overlapping with an exon of g2
##############################################################################################
# - $outDir/PE/readid_gnlist_whoseexoverread_noredund.txt.gz
# - $outDir/PE/readid_twomateswithgnlist_alldiffgnpairs_where_1stassociatedto1stmate_and2ndto2ndmate.txt.gz
# - $outDir/PE/pairs_of_diff_gn_supported_by_pereads_nbpereads.txt

PEsupport=$PEsupportDir/pairs_of_diff_gn_supported_by_pereads_nbpereads.txt


printHeader "Executing find gene to gene connections from PE mappings step"
if [ ! -s $PEsupport ];
then
	step="PAIRED-END"
	startTime=$(date +%s)
	log "Finding gene to gene connections supported by paired-end mappings from the BAM containing reads mapping in a unique and continuous way..." $step
	run "$findGeneConnections $filteredBamFirstMap $annot $PEsupportDir $readDirectionality" "$ECHO"
	
	if [ ! -s $PEsupport ]; 
	then
        log "Error finding gene to gene connections\n" "ERROR" 
        exit -1
    fi
    endTime=$(date +%s)
	printHeader "Find gene to gene connections from PE mappings step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "Gene to gene connections file already exists... skipping step"
fi


# 2.7) Add gene to gene connections information to chimeric junctions matrix
##########################################################################
# - $outDir/distinct_junctions_nbstaggered_nbtotalsplimappings_withmaxbegandend_samechrstr_okgxorder_dist_ss1_ss2_gnlist1_gnlist2_gnname1_gnname2_bt1_bt2_PEinfo_from_split_mappings_part1overA_part2overB_only_A_B_indiffgn_and_inonegn.txt

chimJuncPEsupport=$chimeraDetPhaseDir/distinct_junctions_nbstaggered_nbtotalsplimappings_withmaxbegandend_samechrstr_okgxorder_dist_ss1_ss2_gnlist1_gnlist2_gnname1_gnname2_bt1_bt2_PEinfo_from_split_mappings_part1overA_part2overB_only_A_B_indiffgn_and_inonegn.txt


if [ ! -s $chimJuncPEsupport ];
then
	step="PAIRED-END"
	startTime=$(date +%s)
	log "Adding PE information to the matrix containing chimeric junction candidates..." $step
	run "awk -v fileRef=$PEsupport -f $addPEinfo $chimJunctions 1> $chimJuncPEsupport" "$ECHO"
	
	if [ ! -s $chimJuncPEsupport ]; then
        log "Error adding PE information\n" "ERROR" 
        exit -1
    fi
    endTime=$(date +%s)
	printHeader "Add PE information step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else
	printHeader "Chimeric junction matrix with PE information already exists... skipping step"
fi

# 2.8) Compute the gene similarity matrix in case the user does not provide it
############################################################################

if [ ! -e "$simGnPairs" ]
then
    if [[ ! -d $genePairSimDir ]]; then mkdir $genePairSimDir; fi
    cd $genePairSimDir
    step="PRE-SIM"
    startTime=$(date +%s)
    log "Computing similarity between annotated genes..." $step
    run "$sim $annot $genomeIndex" "$ECHO"
    	
    endTime=$(date +%s)
    simGnPairs=$genePairSimDir/$b2\_gene1_gene2_alphaorder_pcentsim_lgalign_trpair.txt
    cd $outDir
    printHeader "Computing similarity between annotated gene step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
fi

# 2.9) Add information regarding the sequence similarity between connected genes
##############################################################################
# - $outDir/distinct_junctions_nbstaggered_nbtotalsplimappings_withmaxbegandend_samechrstr_okgxorder_dist_ss1_ss2_gnlist1_gnlist2_gnname1_gnname2_bt1_bt2_PEinfo_maxLgalSim_maxLgal_from_split_mappings_part1overA_part2overB_only_A_B_indiffgn_and_inonegn.txt

chimJunctionsSim=$chimeraDetPhaseDir/distinct_junctions_nbstaggered_nbtotalsplimappings_withmaxbegandend_samechrstr_okgxorder_dist_ss1_ss2_gnlist1_gnlist2_gnname1_gnname2_bt1_bt2_PEinfo_maxLgalSim_maxLgal_from_split_mappings_part1overA_part2overB_only_A_B_indiffgn_and_inonegn.txt

if [  ! -e "$chimJunctionsSim" ]
then		
    if [ -e "$simGnPairs" ]
    then
	step="SIM"
	startTime=$(date +%s)
	log "Adding sequence similarity between connected genes information to the chimeric junction matrix..." $step
	run "awk -v fileRef=$simGnPairs -f $AddSimGnPairs $chimJuncPEsupport > $chimJunctionsSim" "$ECHO"
	
	if [ ! -s $chimJunctionsSim ]
	then
	    log "Error adding similarity information, file is empty\n" "ERROR" 
	    exit -1
	fi
	endTime=$(date +%s)
	printHeader "Add sequence similarity information step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
    else 
	printHeader "Similarity information between the gene pairs in the annotation is not provided... skipping step"
    fi
else
    printHeader "Chimeric junction matrix with similarity information already exists... skipping step"
fi


# 2.10) Produce a matrix containing chimeric junction candidates with a header in the first row
#############################################################################################
# - $outDir/chimeric_junctions_candidates.txt

chimJunctionsCandidates=$outDir/chimeric_junctions_candidates_${lid}.txt

if [ ! -s "$chimJunctionsCandidates" ]
then		
    step="HEADER"
    log "Adding a header to the matrix containing the chimeric junction candidates..." $step
    if [ -s "$chimJunctionsSim" ]
    then		
		run "awk 'BEGIN{print \"juncId\", \"nbstag\", \"nbtotal\", \"maxbeg\", \"maxEnd\", \"samechr\", \"samestr\", \"dist\", \"ss1\", \"ss2\", \"gnlist1\", \"gnlist2\", \"gnname1\", \"gnname2\", \"bt1\", \"bt2\", \"PEsupport\", \"maxSim\", \"maxLgal\";}{print \$0;}' $chimJunctionsSim 1> $chimJunctionsCandidates" "$ECHO"
	log "done\n"
    else
		if [ -s "$chimJunctionsPE" ]
		then
	   		run "awk 'BEGIN{print \"juncId\", \"nbstag\", \"nbtotal\", \"maxbeg\", \"maxEnd\", \"samechr\", \"samestr\", \"dist\", \"ss1\", \"ss2\", \"gnlist1\", \"gnlist2\", \"gnname1\", \"gnname2\", \"bt1\", \"bt2\", \"PEsupport\";}{print \$0;}' $chimJunctionsPE 1> $chimJunctionsCandidates" "$ECHO"
	    	log "done\n" 	
		else
	    	log "Error, intermediate file: $chimJunctionsSim or $chimJunctionsPE is missing\n" "ERROR" 
	    exit -1			
		fi
    fi 
else
    printHeader "Header already already added... skipping step"
fi

# 2.11) Filter out chimera candidates to produce a final set of chimeric junctions
################################################################################
# - $outDir/chimeric_junctions.txt

chimJunctions=$outDir/chimeric_junctions_${lid}.txt

if [ ! -s "$chimJunctions" ]; 
then
	step="FILTERING MODULE"
	startTime=$(date +%s)
	log "Filtering out chimera candidates to produce a final set of chimeric junctions..." $step
	awk -v filterConf=$filterConf -f $juncFilter $chimJunctionsCandidates > $chimJunctions
	
	if [ ! -s $chimJunction ]; 
	then
		log "Error filtering chimeric junction candidates\n" "ERROR" 
    	exit -1
	fi
	
	endTime=$(date +%s)
	printHeader "Filtering module step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else 
	printHeader "Chimeric junction candidates already filtered... skipping step"
fi

######################
# 3) CLEANUP AND END #
######################

rm $filteredBamFirstMap

if [[ "$cleanup" == "TRUE" ]]; 
then 
	step="CLEAN-UP"
	startTime=$(date +%s)
	log "Removing intermediate files..." $step
	rm -r $splicedReadsGFFDir $chimeraDetPhaseDir $firstMappingDir/*firstMap.map* $firstMappingDir/*filtered_firstMap.bam* $firstMappingDir/${lid}_map2bam_conversion.log $secondMappingDir/*reads2remap* $chimJunctionsSim $chimJunctionsCandidates
	log "done\n" 
	endTime=$(date +%s)
	printHeader "Clean up step completed in $(echo "($endTime-$startTime)/60" | bc -l | xargs printf "%.2f\n") min"
else 
	printHeader "No clean up mode... skipping step"
fi	


pipelineEnd=$(date +%s)
printHeader "Chimera Mapping pipeline for $lid completed in $(echo "($pipelineEnd-$pipelineStart)/60" | bc -l | xargs printf "%.2f\n") min "

# disable extglob
shopt -u extglob

exit 0

