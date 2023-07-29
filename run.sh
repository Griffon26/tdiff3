#!/bin/bash -v
REPO=~/git/tdiff3
#dub -- /home/griffon26/unison/projects/2014/tdiff3/small_base.txt /home/griffon26/unison/projects/2014/tdiff3/small_contrib1.txt /home/griffon26/unison/projects/2014/tdiff3/small_contrib2.txt -o /home/griffon26/unison/projects/2014/tdiff3/merged.txt
${REPO}/src/tdiff3 --infiles ${REPO}/in1.txt,${REPO}/in2.txt,${REPO}/in3.txt -o ${REPO}/out.txt
