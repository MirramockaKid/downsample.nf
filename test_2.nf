#!/usr/bin/env nextflow

params.chr = ''
params.start= ''
params.end= ''
params.event= ''

READ_LENGTH=75
GTF_PATH='/home/chris/downsampler/caller/ref_annot_EGFRvIII_MET.gtf'
THREADS=1
RMATS_REF_SAMPLES='/home/chris/downsampler/caller/b2.txt'

params.replicates=3
params.bam = '/home/chris/downsampler/data/20M80816A_50ng_Aligned_sorted.bam'

events_ch = Channel.of(tuple([params.chr, params.start, params.end, params.event]))

feedback_ch = Channel.create()
downsample_ch = Channel.value(0.5)

feedback_event_ch = Channel.create()

bam = Channel.fromPath(params.bam)



process samtools {

    input:
    set CHR, START, END, EVENT from events_ch

    output:
    tuple EVENT, path("${EVENT}.bam") into events_bam_ch
    tuple EVENT, path("${EVENT}.bam") into bam_mem

    script:
    """
    samtools view -bh ${params.bam} $CHR:$START-$END > ${EVENT}.bam
    """
}


process downsample {

    input:
    tuple event, path(bam) from events_bam_ch.mix(feedback_event_ch)
    val ds from downsample_ch.mix(feedback_ch)
    each rep from 1..params.replicates

    output:
    tuple event, ds, rep, path("${event}_${ds}_${rep}.bam") into picard_out
    tuple event, path(bam) into mem_bam

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
   tuple event, ds, rep, path(bam) from picard_out
   tuple event_mem, path(bam_mem) from mem_bam

   output:
   val 0.8 into feedback_ch
   tuple event_mem, path(bam_mem) into feedback_event_ch
   tuple event, ds, file('./output/SE.MATS.JC.txt') into calling_out

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

calling_out.view{it}
