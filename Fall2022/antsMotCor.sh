#!/bin/bash

MOVING=""
REFERENCE=""
OUTPUT=""
LATEST_ANTS=0
ARGUMENTS=""
CONTAINERIZED=0
MASK=""
PERFORMANCE=0

while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--moving)
      MOVING="$2"
      shift # past argument
      shift # past value
      ;;
    -r|--reference)
      REFERENCE="$2"
      shift # past argument
      shift # past value
      ;;
    -x|--mask)
      MASK="$2"
      shift # past argument
      shift # past value
      ;;
    -o|--output)
      OUTPUT="$2"
      shift # past argument
      shift # past value
      ;;
    -l|--latest_ants)
      LATEST_ANTS=1
      shift # past argument
      ;;
    -c|--containerized)
      CONTAINERIZED=1
      shift # past argument
      ;;
    -p|--performance)
      PERFORMANCE=1
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      echo "Unknown argument $1"
      exit 1
      ;;
  esac
done

if [ "$MOVING" == "" ]; then
    echo Failed to provide a moving image
    exit 1
fi
if [ "$REFERENCE" == "" ]; then
    echo Failed to provide a reference image
    exit 1
fi
if [ "$MASK" == "" ]; then
    echo Failed to provide a mask image
    exit 1
fi
if [ "$OUTPUT" == "" ]; then
    echo Failed to provide an output folder
    exit 1
fi

# Define arguments for ANTs version 2.3.1
ARGUMENTS="-d 3 --n-images 10 -v 1 \
                --metric MI[ $REFERENCE , $MOVING, 1, 20, regular, 0.2 ] \
                --useFixedReferenceImage 1 \
                --useScalesEstimator 1 \
                --use-estimate-learning-rate-once 1 \
                --transform Rigid[ 0.25 ] \
                --iterations 50x20 \
                --smoothingSigmas 1x0 \
                --shrinkFactors 2x1 \
                -o [ $OUTPUT/motcorr, $OUTPUT/motcorr_warped.nii.gz, $OUTPUT/motcorr_avg.nii.gz ]"

# Reload ANTs if we are not running in a container
if [ $CONTAINERIZED == 0 ]; then 
  module unload ANTs # Unload ANTs
  if [ $LATEST_ANTS == 0 ]; then 
      module load ANTs/2.3.1 # Reload ANTs with expected version 
      if [ $? != 0 ]; then
          echo "Failed to load ANTs version 2.3.1"
          exit 1
      fi
      echo "Successfully loaded ANTs 2.3.1"
  else
      module load ANTs/2.4.0 # Reload ANTs with expected version 
      if [ $? != 0 ]; then
          echo "Failed to load ANTs version 2.4.0"
          exit 1
      fi
      echo "Successfully loaded ANTs 2.4.0"
      # Set arguments
      if [ $PERFORMANCE == 0 ]; then
          ARGUMENTS="-d 3 --n-images 10 -v 1 \
                    --metric  MI[ $REFERENCE, $MOVING, 1, 32, Regular, 0.25, 1 ] \
                    --useFixedReferenceImage 1 \
                    --useScalesEstimator \
                    --transform Rigid[0.1] \
                    --iterations 225x75x25 \
                    --shrinkFactors 3x2x1 \
                    --smoothingSigmas 0.24022448175728997x0.14710685100747165x0.0mm \
                    --output [ $OUTPUT/motcorr, $OUTPUT/motcorr_warped.nii.gz, $OUTPUT/motcorr_avg.nii.gz ]"
      else 
          ARGUMENTS="-d 3 --n-images 10 -v 1 \
                    --metric  MI[ $REFERENCE, $MOVING, 1, 32, Regular, 0.25, 1 ] \
                    --useFixedReferenceImage 1 \
                    --useScalesEstimator \
                    --transform Rigid[0.1] \
                    --iterations 50x20 \
                    --shrinkFactors 2x1 \
                    --smoothingSigmas 0.14710685100747165x0.0mm \
                    --output [ $OUTPUT/motcorr, $OUTPUT/motcorr_warped.nii.gz, $OUTPUT/motcorr_avg.nii.gz ]"
      fi
  fi
fi
START=`date +%s`
antsMotionCorr $ARGUMENTS
END=`date +%s`
EXECUTION_TIME=`expr $END - $START`
echo $EXECUTION_TIME s > $OUTPUT/execution_time.txt
# # Need to change motion corr stat call to calculate FD properly
antsMotionCorrStats -m $OUTPUT/motcorrMOCOparams.csv \
                    -o $OUTPUT/FD_calculations.csv \
                    -x $MASK \
                    -d $MOVING \
                    -s $OUTPUT/spacial_map.nii.gz \
                    -f 1 
