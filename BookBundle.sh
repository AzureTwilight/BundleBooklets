#! /usr/bin/zsh
#--------------
# TERMNOLOGY
# Booklet: Sub-bundle for the whole bookbundle
# Paper: Actual (Physical) Paper
# Page:  PDF Page

function usage(){echo "BookletBundle"}

# Assign Default Value
PAPER_NUM_EACH_BOOKLET=5
VERBOSE="yes"
DEBUG="n"
EXTRA_BOOKLET='y'
KEEP_BOOKLET_FLG='n'

while getopts ":s:p:o:vk" arg; do
    case "${arg}" in
        s)
            ((s == 45 || s == 90)) || usage
            ;;
        p)
            PAPER_NUM_EACH_BOOKLET=${OPTARG}
            ;;
	o)
	    OUTPUT_FILE=${OPTARG}
	    ;;
	v)  VERBOSE="y"
	    ;;
	k)
	    KEEP_BOOKLET_FLG='y'
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

INPUT_FILE="$@"
totalPDFPageNum=$(pdftk "${INPUT_FILE}" dump_data | grep NumberOfPages | awk '{print $NF}')
[ $DEBUG = "y" ] && echo "DEBUG: total PDF Page # = $totalPDFPageNum "
pdfPageDimension=$(pdftk ${INPUT_FILE} dump_data | grep PageMediaDimensions | awk -F ': ' '{print $NF}' | tail -n 1 | tr ' ' 'x' )
[ $DEBUG = "y" ] && echo "DEBUG: PDF Page Dim = $pdfPageDimension "

if [ -n $totalPDFPageNum -o -n $pdfPageDimension ]; then
else
    echo "ERROR: Couldn't obtain PDF Metainfo"
    exit 1
fi

bookletTotalPageNum=$(( ${PAPER_NUM_EACH_BOOKLET} * 4))
bookletHalfPageNum=$(( $bookletTotalPageNum / 2))
[ $DEBUG = "y" ] && echo "DEBUG: Booklet Total Pageg # = ${bookletTotalPageNum} "

# Calculate Number of Booklets Required
numberOfBooklets=$(( $totalPDFPageNum / $bookletTotalPageNum ))
[ $DEBUG = "y" ] && echo "DEBUG: Booklets # = ${numberOfBooklets} "
pageRemainder=$(( $totalPDFPageNum % $bookletTotalPageNum ))
[ $DEBUG = "y" ] && echo "DEBUG: Page Remainder # = ${pageRemainder}"

if [ $pageRemainder -eq 0 ]; then
    EXTRA_BOOKLET='n' # Extra Booklet refer to the booklet for all remaining pages.
    totalBookletNumber=$numberOfBooklets
    [ $VERBOSE = 'y' ] &&  echo "PDF Page # is Divisible by Booklet Page #"
    echo "Total Number of Booklets = ${numberOfBooklets}"
    # Check if need to add Cover and Bottom
else
    EXTRA_BOOKLET='y'
    totalBookletNumber=$(( $numberOfBooklets + 1 ))
    echo "Total Number of Booklets = ${numberOfBooklets} + 1"
    [ -n $VERBOSE ] && echo "Inserting Blank Page to the End."
    numberOfBlankPages=$(( 4 - $pageRemainder % 4 ))
    [ $DEBUG = "y" ] && echo "DEBUG: Blank Page # = ${numberOfBlankPages}"

    # Create Blank PDF
    XC_NONE_STR=""
    for i in `seq 2 $numberOfBlankPages`; do
	XC_NONE_STR=${XC_NONE_STR}"xc:none "
    done
    XC_NONE_STR=${XC_NONE_STR}"xc:none"

    CONVERT_CMD="convert $XC_NONE_STR -page $pdfPageDimension tmp_Blank.pdf"
    bash -c "$CONVERT_CMD"


    pdftk A="$INPUT_FILE" B=tmp_Blank.pdf cat A B output "modified_${INPUT_FILE}"
    INPUT_FILE="modified_${INPUT_FILE}"
fi

# Output Basic Info
echo "Total Number of Book PDF Pages: " $(( (${totalPDFPageNum} + ${numberOfBlankPages}) / 2 ))
echo "Total Print Papers Required:    " $(( (${totalPDFPageNum} + ${numberOfBlankPages}) / 4 ))
echo "Total Number of Booklets:       " ${totalBookletNumber}

# Split PDF into Booklets
startPDFPageNum=1
endPDFPageNum=${bookletTotalPageNum}

PDFTK_CMD="pdftk"
for i in `seq 1 $numberOfBooklets`; do
    echo -n "Converting $i Booklets..."
    # Split PDF into Odd Even parts
    pdftk "$INPUT_FILE" cat ${startPDFPageNum}-${endPDFPageNum}odd output tmp_OddPart.pdf
    pdftk "$INPUT_FILE" cat ${startPDFPageNum}-${endPDFPageNum}even output tmp_EvenPart.pdf

    # Form Odd and Even Booklet
    pdftk A=tmp_OddPart.pdf B=tmp_EvenPart.pdf shuffle Bend-$(( $PAPER_NUM_EACH_BOOKLET + 1)) A1-${PAPER_NUM_EACH_BOOKLET} output tmp_OddBooklet.pdf
    pdftk A=tmp_OddPart.pdf B=tmp_EvenPart.pdf shuffle B1-$PAPER_NUM_EACH_BOOKLET Aend-$(( ${PAPER_NUM_EACH_BOOKLET} + 1 )) output tmp_EvenBooklet.pdf

    # Form them into Booklet
    pdfjam -q tmp_OddBooklet.pdf --nup 2x1 --landscape -o tmp_OddPart.pdf
    pdfjam -q tmp_EvenBooklet.pdf --nup 2x1 --landscape -o tmp_EvenPart.pdf

    pdftk A=tmp_OddPart.pdf B=tmp_EvenPart.pdf shuffle A B output Booklet_$i.pdf 
    
    startPDFPageNum=$(( ${startPDFPageNum} + ${bookletTotalPageNum} ))
    endPDFPageNum=$(( ${endPDFPageNum} + ${bookletTotalPageNum} ))

    PDFTK_CMD=${PDFTK_CMD}" Booklet_$i.pdf"
    echo "Done."
done

if [ $EXTRA_BOOKLET = 'y' ];then
    PAPER_NUM_EACH_BOOKLET=$(( ${numberOfBlankPages} + ${totalPDFPageNum} - $i * ${bookletTotalPageNum} ))
    PAPER_NUM_EACH_BOOKLET=$(( $PAPER_NUM_EACH_BOOKLET / 4 ))
    i=$i+1
    echo -n "Converting $i Booklets..."

    pdftk "$INPUT_FILE" cat ${startPDFPageNum}-endodd output tmp_OddPart.pdf
    pdftk "$INPUT_FILE" cat ${startPDFPageNum}-endeven output tmp_EvenPart.pdf

    # Form Odd and Even Booklet
    pdftk A=tmp_OddPart.pdf B=tmp_EvenPart.pdf shuffle Bend-$(( $PAPER_NUM_EACH_BOOKLET + 1)) A1-${PAPER_NUM_EACH_BOOKLET} output tmp_OddBooklet.pdf
    pdftk A=tmp_OddPart.pdf B=tmp_EvenPart.pdf shuffle B1-$PAPER_NUM_EACH_BOOKLET Aend-$(( ${PAPER_NUM_EACH_BOOKLET} + 1 )) output tmp_EvenBooklet.pdf

    # Form them into Booklet
    pdfjam -q tmp_OddBooklet.pdf --nup 2x1 --landscape -o tmp_OddPart.pdf
    pdfjam -q tmp_EvenBooklet.pdf --nup 2x1 --landscape -o tmp_EvenPart.pdf

    pdftk A=tmp_OddPart.pdf B=tmp_EvenPart.pdf shuffle A B output Booklet_$i.pdf 
    PDFTK_CMD=${PDFTK_CMD}" Booklet_$i.pdf"
    echo "Done.."
fi

PDFTK_CMD=${PDFTK_CMD}" cat output \"BookBundle_${INPUT_FILE}\""
#echo $PDFTK_CMD
bash -c $PDFTK_CMD

rm tmp_*

if [ $KEEP_BOOKLET_FLG = 'y' ]; then
    echo "All Booklets Files are deleted. To keep those files, pass -k options."
else
    rm Booklet_*.pdf
fi
