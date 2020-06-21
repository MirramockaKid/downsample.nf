#!/usr/bin/env nextflow

params.eventsFile = '/home/chris/downsampler/events.txt'
params.bam = '/home/chris/downsampler/data/20M80816A_50ng_Aligned_sorted.bam'

READ_LENGTH=75
GTF_PATH='/home/chris/downsampler/caller/ref_annot_EGFRvIII_MET.gtf'
THREADS=4
RMATS_REF_SAMPLES='/home/chris/downsampler/caller/b2.txt'

Channel
    .fromPath(params.eventsFile)
    .splitCsv(header:true, sep:'\t')
    .map{ row-> tuple(row.CHR, row.START, row.END, row.EVENT) }
    .set { events_ch }

bam = Channel.fromPath(params.bam)
ds  = [ 0.8 ]
replicates=1


process samtools {

    input:
    set CHR, START, END, EVENT from events_ch

    output:
    set EVENT, file("${EVENT}.bam") into events_bam_ch

    script:
    """
    samtools view -bh ${params.bam} $CHR:$START-$END > ${EVENT}.bam
    """
}


process downsample {

    input:
    set event, file(bam) from events_bam_ch
    each ds from ds
    each rep from 1..replicates

    output:
    set event, ds, rep, file("${event}_${ds}_${rep}.bam") into picard_out 

    script:
    """
    picard DownsampleSam \
    	I=$bam \
        O="$event"_"$ds"_"$rep".bam \
        P=$ds \
        R=null
    """
}


process fusion_calling {
   conda '/home/chris/anaconda3/envs/rmats41'

   input:
   set event, ds, rep, file(bam) from picard_out

   output:
   set event, ds, file('./output/SE.MATS.JC.txt') into calling_out

   script:
   """

   echo $bam > query_sample.txt

   rmats.py \
      --b1 query_sample.txt \
      --b2 $RMATS_REF_SAMPLES \
      -t paired \
      --gtf $GTF_PATH \
      --readLength $READ_LENGTH \
      --od output \
      --tmp output \
      --nthread $THREADS

   """
}
