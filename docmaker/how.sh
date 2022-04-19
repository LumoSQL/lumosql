#short story how the mdbook is made

#get inside the repo
fossil clone https://lumosql.org/src/lumosql
cd lumosql 

mdbook init docmaker
cd docmaker/src
rm chapter_1.md SUMMARY.md

#linking files from existing folders to docmaker/src
#split top level README into two
ln  ../../*md .
cat README.md | sed -n '116,442p' >> quickstart.md
sed -i '/<b>/d' quickstart.md 
cat README.md | sed '116,442d' >> about.md
sed -i '/<b>/d' about.md 
rm README.md

ln  ../../doc/*.md .
ln  ../../doc/rfc/README.md ./lumion_intro.md

#RFC
#copy dont change the original, use .txt as a code block in .md
cp ../../doc/rfc/*.txt .
mv draft-shearer-desmet-calvelli-lumionsrfc-00.txt rfc.md
sed -i '1s/^/# Lumion RFC\n```\n/' rfc.md
echo '```'  >> rfc.md

ln  ../../new-doc/*.md .
ln -s  ../../new-doc/images .
ln ../../analysis/contrasts/doc/notes.md ./statistical_analysis.md
ln ../../references/lumosql-abe.bib .
ln  ../../LICENCES/*.md .
mv README.md licensing.md 

cd ..
mdbook serve --open 	#to preview in browser
mdbook build 		#to save output .html in book directory
