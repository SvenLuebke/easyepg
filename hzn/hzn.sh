#!/bin/bash

#      Copyright (C) 2019-2020 Jan-Luca Neumann
#      https://github.com/sunsettrack4/easyepg
#
#      Collaborators:
#      - DeBaschdi ( https://github.com/DeBaschdi )
#
#  This Program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3, or (at your option)
#  any later version.
#
#  This Program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with easyepg. If not, see <http://www.gnu.org/licenses/>.


# ################
# INITIALIZATION #
# ################

#
# SETUP ENVIRONMENT
#

PATH_TMP=/tmp
PATH_MANI=$PATH_TMP/mani
PATH_TMP_EPG=$PATH_TMP/epg

mkdir -p $PATH_MANI 2> /dev/null		# manifest files
mkdir -p $PATH_TMP_EPG 2> /dev/null		# manifest files

if grep -q "DE" init.json 2> /dev/null
then
	echo "+++ COUNTRY: GERMANY +++"
	COUNTRY=de
	eval $(jq --arg COUNTRY ${COUNTRY} -r 'select(.country==$COUNTRY) | to_entries[] | "\(.key)=\(.value)"' config.json)
	if [[ "$ProviderURL" == "" ]]; then
	  echo no ProviderURL found in config:  $ProviderURL
	  exit
	fi
	baseurl=$ProviderURL
	baseurl_sed='legacy-dynamic.oesp.horizon.tv\/oesp\/v2\/DE\/deu\/web'
	echo "baseurl = $baseurl"
elif grep -q "AT" init.json 2> /dev/null
then
	echo "+++ COUNTRY: AUSTRIA +++"
	baseurl='https://prod.oesp.magentatv.at/oesp/v2/AT/deu/web'
	baseurl_sed='prod.oesp.magentatv.at\/oesp\/v2\/AT\/deu\/web'
elif grep -q "CH" init.json 2> /dev/null
then
	echo "+++ COUNTRY: SWITZERLAND +++"
	baseurl='https://obo-prod.oesp.upctv.ch/oesp/v2/CH/deu/web'
	baseurl_sed='obo-prod.oesp.upctv.ch\/oesp\/v2\/CH\/deu\/web'
elif grep -q "NL" init.json 2> /dev/null
then
	echo "+++ COUNTRY: NETHERLANDS +++"
	baseurl='https://obo-prod.oesp.ziggogo.tv/oesp/v2/NL/nld/web'
	baseurl_sed='obo-prod.oesp.ziggogo.tv\/oesp\/v2\/NL\/nld\/web'
elif grep -q "PL" init.json 2> /dev/null
then
	echo "+++ COUNTRY: POLAND +++"
	baseurl='https://prod.oesp.upctv.pl/oesp/v2/PL/pol/web'
	baseurl_sed='prod.oesp.upctv.pl\/oesp\/v2\/PL\/pol\/web'
elif grep -q "IE" init.json 2> /dev/null
then
	echo "+++ COUNTRY: IRELAND +++"
	baseurl='https://prod.oesp.virginmediatv.ie/oesp/v2/IE/eng/web'
	baseurl_sed='prod.oesp.virginmediatv.ie\/oesp\/v2\/IE\/eng\/web'
elif grep -q "SK" init.json 2> /dev/null
then
	echo "+++ COUNTRY: SLOVAKIA +++"
	baseurl='https://legacy-dynamic.oesp.horizon.tv/oesp/v2/SK/slk/web'
	baseurl_sed='legacy-dynamic.oesp.horizon.tv\/oesp\/v2\/SK\/slk\/web'
elif grep -q "CZ" init.json 2> /dev/null
then
	echo "+++ COUNTRY: CZECH REPUBLIC +++"
	baseurl='https://legacy-dynamic.oesp.horizon.tv/oesp/v2/CZ/ces/web'
	baseurl_sed='legacy-dynamic.oesp.horizon.tv\/oesp\/v2\/CZ\/ces\/web'
elif grep -q "HU" init.json 2> /dev/null
then
	echo "+++ COUNTRY: HUNGARY +++"
	baseurl='https://legacy-dynamic.oesp.horizon.tv/oesp/v2/HU/hun/web'
	baseurl_sed='legacy-dynamic.oesp.horizon.tv\/oesp\/v2\/HU\/hun\/web'
elif grep -q "RO" init.json 2> /dev/null
then
	echo "+++ COUNTRY: ROMANIA +++"
	baseurl='https://legacy-dynamic.oesp.horizon.tv/oesp/v2/RO/ron/web'
	baseurl_sed='legacy-dynamic.oesp.horizon.tv\/oesp\/v2\/RO\/ron\/web'
else
	echo "[ FATAL ERROR ] WRONG INIT INPUT DETECTED - Stop."
	rm init.json 2> /dev/null
	exit 1
fi

if grep -q '"day": "0"' settings.json
then
	printf "EPG Grabber disabled!\n\n"
	exit 0
fi

date1=$(date '+%Y%m%d')

if ! curl --write-out %{http_code} --silent --output /dev/null $baseurl/programschedules/$date1/1 | grep -q "200"
then
	printf "Service provider unavailable!\n\n"
	exit 0
fi

printf "\n"


# ##################
# DOWNLOAD PROCESS #
# ##################

echo "- DOWNLOAD PROCESS -" && echo ""

#
# DELETE OLD FILES
#

printf "\rDeleting old files...                       "

rm $PATH_MANI/* 2> /dev/null

#
# LOADING MANIFEST FILES
#

printf "\rFetching channel list... "
curl -s $baseurl/channels > $PATH_TMP_EPG/chlist
jq '.' $PATH_TMP_EPG/chlist > $PATH_TMP_EPG/workfile

echo "###   Copying chlist to chlist_old    ####"
cp $PATH_TMP_EPG/chlist $PATH_TMP_EPG/chlist_old

printf "\rChecking manifest files... "
perl chlist_printer.pl > $PATH_TMP/compare.json
perl url_printer.pl 2>$PATH_TMP_EPG/errors.txt | sed '/DUMMY/d' > $PATH_MANI/common

printf "\n$(echo $(wc -l < $PATH_MANI/common)) manifest file(s) to be downloaded!\n\n"
if [ $(wc -l < $PATH_MANI/common) -ge 7 ]
then
	number=$(echo $(( $(wc -l < $PATH_MANI/common) / 7)))

	split --lines=$(( $number + 1 )) --numeric-suffixes $PATH_MANI/common $PATH_MANI/day

	rm $PATH_MANI/common 2> /dev/null
else
	mv $PATH_MANI/common $PATH_MANI/day00
fi


#
# CREATE STATUS BAR FOR MANIFEST FILE DOWNLOAD
#

x=$(wc -l < $PATH_MANI/day00)
y=20
h=40

if [ $x -gt $h ]
then
	z5=$(expr $x / $y)
	z10=$(expr $x / $y \* 2)
	z15=$(expr $x / $y \* 3)
	z20=$(expr $x / $y \* 4)
	z25=$(expr $x / $y \* 5)
	z30=$(expr $x / $y \* 6)
	z35=$(expr $x / $y \* 7)
	z40=$(expr $x / $y \* 8)
	z45=$(expr $x / $y \* 9)
	z50=$(expr $x / $y \* 10)
	z55=$(expr $x / $y \* 11)
	z60=$(expr $x / $y \* 12)
	z65=$(expr $x / $y \* 13)
	z70=$(expr $x / $y \* 14)
	z75=$(expr $x / $y \* 15)
	z80=$(expr $x / $y \* 16)
	z85=$(expr $x / $y \* 17)
	z90=$(expr $x / $y \* 18)
	z95=$(expr $x / $y \* 19)

	echo "#!/bin/bash" > $PATH_TMP_EPG/progressbar

	# START
	echo "sed -i '2i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [                    ]   0%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 5%
	echo "sed -i '$z5 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [#                   ]   5%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 10%
	echo "sed -i '$z10 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [##                  ]  10%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 15%
	echo "sed -i '$z15 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [###                 ]  15%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 20%
	echo "sed -i '$z20 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [####                ]  20%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 25%
	echo "sed -i '$z25 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [#####               ]  25%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 30%
	echo "sed -i '$z30 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [######              ]  30%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 35%
	echo "sed -i '$z35 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [#######             ]  35%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 40%
	echo "sed -i '$z40 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [########            ]  40%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 45%
	echo "sed -i '$z45 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [#########           ]  45%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 50%
	echo "sed -i '$z50 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [##########          ]  50%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 55%
	echo "sed -i '$z55 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [###########         ]  55%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 60%
	echo "sed -i '$z60 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [############        ]  60%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 65%
	echo "sed -i '$z65 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [#############       ]  65%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 70%
	echo "sed -i '$z70 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [##############      ]  70%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 75%
	echo "sed -i '$z75 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [###############     ]  75%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 80%
	echo "sed -i '$z80 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [################    ]  80%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 85%
	echo "sed -i '$z85 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [#################   ]  85%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 90%
	echo "sed -i '$z90 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [##################  ]  90%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 95%
	echo "sed -i '$z95 i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [################### ]  95%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	# 100%
	echo "sed -i '\$i\\" >> $PATH_TMP_EPG/progressbar
	echo "Progress [####################] 100%% ' $PATH_MANI/day00" >> $PATH_TMP_EPG/progressbar

	sed -i 's/ i/i/g' $PATH_TMP_EPG/progressbar
	bash $PATH_TMP_EPG/progressbar
	sed -i -e 's/Progress/printf "\\rProgress/g' -e '/Progress/s/.*/&"/g' $PATH_MANI/day00
	rm $PATH_TMP_EPG/progressbar
fi


#
# CREATE MANIFEST DOWNLOAD SCRIPTS
#

for time in {0..8..1}
do
	sed -i '1i#\!\/bin\/bash\n' $PATH_MANI/day0${time} 2> /dev/null
done


#
# COPY/PASTE EPG DETAILS
#

printf "\rLoading manifest files..."
echo ""

for a in {0..8..1}
do
	bash $PATH_MANI/day0${a} 2> /dev/null &
done
wait

rm $PATH_MANI/day0* 2> /dev/null

echo "DONE!" && printf "\n"


#
# CREATE EPG BROADCAST LIST
#

printf "\rCreating EPG manifest file... "

rm $PATH_TMP_EPG/manifile.json 2> /dev/null
cat $PATH_MANI/* > $PATH_TMP_EPG/manifile.json
sed -i 's/}\]}}/}]}/g' $PATH_TMP_EPG/manifile.json
jq -s '.' $PATH_TMP_EPG/manifile.json > $PATH_TMP_EPG/epg_workfile 2>>$PATH_TMP_EPG/errors.txt
sed -i '1s/\[/{ "attributes":[/g;$s/\]/&}/g' $PATH_TMP_EPG/epg_workfile

echo "DONE!" && printf "\n"


#
# SHOW ERROR MESSAGE + ABORT PROCESS IF CHANNEL IDs WERE CHANGED
#

sort -u $PATH_TMP_EPG/errors.txt > $PATH_TMP_EPG/errors_sorted.txt && mv $PATH_TMP_EPG/errors_sorted.txt $PATH_TMP_EPG/errors.txt

if [ -s $PATH_TMP_EPG/errors.txt ]
then
	echo "================= CHANNEL LIST: LOG ==================="
	echo ""

	input="$PATH_TMP_EPG/errors.txt"
	while IFS= read -r var
	do
		echo "$var"
	done < "$input"

	echo ""
	echo "======================================================="
	echo ""

	#cp $PATH_TMP_EPG/chlist $PATH_TMP_EPG/chlist_old
else
	rm $PATH_TMP_EPG/errors.txt 2> /dev/null
fi


# ###################
# CREATE XMLTV FILE #
# ###################

# WORK IN PROGRESS

echo "- FILE CREATION PROCESS -" && echo ""

rm $PATH_TMP_EPG/workfile $PATH_TMP_EPG/chlist 2> /dev/null


# DOWNLOAD CHANNEL LIST + RYTEC/EIT CONFIG FILES (JSON)
printf "\rRetrieving channel list and config files...          "
curl -s $baseurl/channels > $PATH_TMP_EPG/chlist
curl -s https://raw.githubusercontent.com/sunsettrack4/config_files/master/hzn_channels.json > $PATH_TMP_EPG/hzn_channels.json
curl -s https://raw.githubusercontent.com/sunsettrack4/config_files/master/hzn_genres.json > $PATH_TMP_EPG/hzn_genres.json

# CONVERT JSON INTO XML: CHANNELS
printf "\rConverting CHANNEL JSON file into XML format...      "
perl ch_json2xml.pl 2>$PATH_TMP_EPG/warnings.txt > $PATH_TMP_EPG/unsorted_horizon_channels
sort -u $PATH_TMP_EPG/unsorted_horizon_channels > $PATH_TMP_EPG/horizon_channels # && mv $PATH_TMP_EPG/horizon_channels $PATH_TMP_EPG/horizon_channels
sed -i 's/></>\n</g;s/<display-name/  &/g;s/<icon src/  &/g' $PATH_TMP_EPG/horizon_channels

# CREATE CHANNEL ID LIST AS JSON FILE
printf "\rRetrieving Channel IDs...                            "
perl cid_json.pl > $PATH_TMP_EPG/hzn_cid.json && rm $PATH_TMP_EPG/chlist

# CONVERT JSON INTO XML: EPG
printf "\rConverting EPG JSON file into XML format...          "
perl epg_json2xml.pl > $PATH_TMP_EPG/horizon_epg 2>$PATH_TMP_EPG/epg_warnings.txt && rm $PATH_TMP_EPG/epg_workfile 2> /dev/null
# COMBINE: CHANNELS + EPG
printf "\rCreating EPG XMLTV file...                           "
cat $PATH_TMP_EPG/horizon_epg >> $PATH_TMP_EPG/horizon_channels && mv $PATH_TMP_EPG/horizon_channels $PATH_TMP_EPG/horizon && rm $PATH_TMP_EPG/horizon_epg
sed -i '1i<?xml version="1.0" encoding="UTF-8" ?>\n<\!-- EPG XMLTV FILE CREATED BY THE EASYEPG PROJECT - (c) 2019-2020 Jan-Luca Neumann -->\n<tv>' $PATH_TMP_EPG/horizon
sed -i "s/<tv>/<\!-- created on $(date) -->\n&\n\n<!-- CHANNEL LIST -->\n/g" $PATH_TMP_EPG/horizon
sed -i '$s/.*/&\n\n<\/tv>/g' $PATH_TMP_EPG/horizon
mv $PATH_TMP_EPG/horizon $PATH_TMP_EPG/horizon.xml

# VALIDATING XML FILE
printf "\rValidating EPG XMLTV file..."
xmllint --noout $PATH_TMP_EPG/horizon.xml > $PATH_TMP_EPG/errorlog 2>&1

if grep -q "parser error" $PATH_TMP_EPG/errorlog
then
	printf " DONE!\n\n"
	mv $PATH_TMP_EPG/horizon.xml $PATH_TMP_EPG/horizon_ERROR.xml
	echo "[ EPG ERROR ] XMLTV FILE VALIDATION FAILED DUE TO THE FOLLOWING ERRORS:" >> $PATH_TMP_EPG/warnings.txt
	cat $PATH_TMP_EPG/errorlog >> $PATH_TMP_EPG/warnings.txt
else
	printf " DONE!\n\n"
	rm $PATH_TMP_EPG/horizon_ERROR.xml 2> /dev/null
	rm $PATH_TMP_EPG/errorlog 2> /dev/null

	if ! grep -q "<programme start=" $PATH_TMP_EPG/horizon.xml
	then
		echo "[ EPG ERROR ] XMLTV FILE DOES NOT CONTAIN ANY PROGRAMME DATA!" >> $PATH_TMP_EPG/errorlog
	fi

	if ! grep "<channel id=" $PATH_TMP_EPG/horizon.xml > $PATH_TMP_EPG/id_check
	then
		echo "[ EPG ERROR ] XMLTV FILE DOES NOT CONTAIN ANY CHANNEL DATA!" >> $PATH_TMP_EPG/errorlog
	fi

	uniq -d $PATH_TMP_EPG/id_check > $PATH_TMP_EPG/id_checked
	if [ -s $PATH_TMP_EPG/id_checked ]
	then
		echo "[ EPG ERROR ] XMLTV FILE CONTAINS DUPLICATED CHANNEL IDs!" >> $PATH_TMP_EPG/errorlog
		sed -i 's/.*/[ DUPLICATE ] &/g' $PATH_TMP_EPG/id_checked && cat $PATH_TMP_EPG/id_checked >> $PATH_TMP_EPG/errorlog
		rm $PATH_TMP_EPG/id_check $PATH_TMP_EPG/id_checked 2> /dev/null
	else
		rm $PATH_TMP_EPG/id_check $PATH_TMP_EPG/id_checked 2> /dev/null
	fi

	if [ -e $PATH_TMP_EPG/errorlog ]
	then
		mv $PATH_TMP_EPG/horizon.xml $PATH_TMP_EPG/horizon_ERROR.xml
		cat $PATH_TMP_EPG/errorlog >> $PATH_TMP_EPG/warnings.txt
	else
		rm $PATH_TMP_EPG/errorlog 2> /dev/null
	fi
fi

# SHOW WARNINGS
cat $PATH_TMP_EPG/epg_warnings.txt >> $PATH_TMP_EPG/warnings.txt && rm $PATH_TMP_EPG/epg_warnings.txt
sort -u $PATH_TMP_EPG/warnings.txt > $PATH_TMP_EPG/sorted_warnings.txt && mv $PATH_TMP_EPG/sorted_warnings.txt $PATH_TMP_EPG/warnings.txt
sed -i '/^$/d' $PATH_TMP_EPG/warnings.txt

if [ -s $PATH_TMP_EPG/warnings.txt ]
then
	echo "========== EPG CREATION: WARNING/ERROR LOG ============"
	echo ""

	input="$PATH_TMP_EPG/warnings.txt"
	while IFS= read -r var
	do
		echo "$var"
	done < "$input"

	echo ""
	echo "======================================================="
	echo ""
fi
