#!/bin/bash

eventsFile='/home/chris/downsampler/events.txt'

while read ln; do

    CHR=$(echo $ln | cut -d" " -f 1)
    START=$(echo $ln | cut -d" " -f 2)
    END=$(echo $ln | cut -d" " -f 3)
    EVENT=$(echo $ln | cut -d" " -f 4)

    nextflow run test_2.nf --chr $CHR --start $START --end $END --event $EVENT

done < "$eventsFile"
