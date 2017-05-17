#/usr/bin/env bash

for dir in `find . -type d -mindepth 1`; do 
    echo "Tokenising everything in $dir"
    for jack in `ls $dir/*.jack`; do
        echo "tokenising $jack"
        ./jcc.rb compile --tokenize_only $jack
    done
done

for f in `ls **/*T.xml`; do 
    tokenfile=${f/T\./\.jackTok\.}; 
    echo "Comparing $f with $tokenfile .. "; 
    ../../tools/TextComparer.sh $f $tokenfile ; 
done
