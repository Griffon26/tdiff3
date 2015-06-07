#!/bin/bash
plantuml -tsvg -o `pwd`/docs/uml source/*.d &&
sed -i -e 's/<a xlink:href/<a target="_top" xlink:href/g' -e 's/width:\(.*\)px;height:\(.*\)px;/width:\1;height:\2;/g'  docs/uml/*.svg &&
dub build --build=ddox

