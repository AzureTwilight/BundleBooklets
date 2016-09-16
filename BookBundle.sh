#!/usr/bin/zsh

function help(){
    echo "BookletBundle"
}


input_pdf="auctex.pdf"

pdftk sample.pdf burst output page_%d.pdf

bundle_page_sum=9
bundle_half_page_num=4

# The odd page should be at right side
for i in `seq 1 2 $bundle_half_page_num`; do
   left_page_num=$(($bundle_page_sum - $i))
   pdfjam -q page_${left_page_num}.pdf page_${i}.pdf --nup 2x1 --landscape --outfile newpage_$i.pdf
   # pdfjam Page1.pdf Page2.pdf --nup 2x1 --landscape --outfile Page1+2.pdf 
done

# The Even Page should be at right side
for i in `seq 2 2 $bundle_half_page_num`; do
   right_page_num=$(($bundle_page_sum - $i))
   pdfjam -q page_${i}.pdf page_${right_page_num}.pdf --nup 2x1 --landscape --outfile newpage_$i.pdf
   # pdfjam Page1.pdf Page2.pdf --nup 2x1 --landscape --outfile Page1+2.pdf 
done


# Cat All the New Pages Togather
pdftk newpage*.pdf cat output BookletBundle.pdf
