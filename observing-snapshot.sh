#!/usr/bin/env bash

# Observing Snapshot, https://github.com/whitinobservatory/observing-snapshot/
# 2023 Sep 18 - Jonathan Kemp, initial version, Whitin Observatory
# 2026 May 27 - Jonathan Kemp, release version, Whitin Observatory

# observing snapshot
# core bash script
# creates and distributes log, images, and video data products
# bash required environment
# tested with bash version 5.2.21
# rename required dependency, https://metacpan.org/dist/File-Rename
# tested with rename version 2.02
# uses rename's rename functionality
# gnuastro required dependency, https://www.gnu.org/software/gnuastro/
# tested with gnuastro version 0.22
# uses gnuastro's astfits and aststatistics functionality
# xvfb required dependency, https://x.org/releases/current/doc/man/man1/Xvfb.1.xhtml
# tested with xvfb version 21.1.12
# uses xvfb's xvfb-run functionality
# saoimage ds9 required dependency, https://sites.google.com/cfa.harvard.edu/saoimageds9
# tested with saoimageds9 version 8.5
# uses saoimageds9's ds9 functionality
# imagemagick required dependency, https://imagemagick.org/download/
# tested with imagemagick version 6.9.12
# uses imagemagick's convert and mogrify functionality
# ffmepg required dependency, https://ffmpeg.org/
# tested with ffmpeg 6.1.1
# uses ffmpeg's ffmpeg functionality

# note: ubuntu installation hint, root privileges, "apt install rename gnuastro xvfb saods9 imagemagick ffmpeg"
# note: windows installation hint to support ubuntu, admin privileges, "wsl --install"
# note: passwordless remote host login hint, use "ssh-keygen" and "ssh-copy-id" tools as appropriate

# user general settings for editting
#VERBOSE="no"
VERBOSE="yes"
DATANIGHT=`date -d '-16 hours' +'%Y-%m-%d'`
#DATANIGHT="0000-00-00"
DATAUPDATE=`date +'%Y-%m-%d %H:%M:%S %Z'`
DATARAW="/data/$DATANIGHT"
DATAHOME="/home/$USER"
DATAWORKING="observing-snapshot"
FITSINST="QHY"
#FITSINST="ZWO"
#FITSINST="FLI"
#FITSINST="SBIG"
FITSEXT="fit"
#FITSEXT="fts"
#FITSEXT="fits"
BIAS="bias"
#BIAS="zero"
DARK="dark"
FLAT="flat"
FLIP="no"
#FLIP="yes"
FLOP="no"
#FLOP="yes"
ROTATE="0"
#ROTATE="90"
#ROTATE="180"
#ROTATE="270"
#ROTATE="-90"
#ROTATE="-180"
#ROTATE="-270"
OBSNAME="Observing"
FONTDIR="/usr/share/fonts/truetype/ubuntu"
FONT="UbuntuMono-R.ttf"
FONTCOLOR="midnightblue"
BGCOLOR="gainsboro"
FONTREDUCE="16"
TNSCALE="12.5%"
VIDSCALE="75%"
#WEBNOW="no"
WEBNOW="yes"
#WEBARCHIVE="no"
WEBARCHIVE="yes"
REMOTEUSER="$USER"
REMOTEHOST="remotehost.remotedomain"
REMOTEDIR="/var/www/html/observing-snapshot"
WEBPROTOCOL="https"
WEBHOST="remotehost.remotedomain"
WEBDIR="/observing-snapshot"

# required dependencies check
if [ ! -x "$(command -v rename)" ] || [ ! -x "$(command -v astfits)" ] || [ ! -x "$(command -v aststatistics)" ]|| [ ! -x "$(command -v ds9)" ]|| [ ! -x "$(command -v xvfb-run)" ]|| [ ! -x "$(command -v convert)" ]|| [ ! -x "$(command -v mogrify)" ] || [ ! -x "$(command -v ffmpeg)" ] ; then
	echo "rename, gnuastro astfits/aststatistics, saods9 ds9, xvfb xvfb-run, imagemagick convert/mogrify, or ffmpeg unavailable"
	echo
	echo "exiting"
	exit
fi

# setup and configuration
mkdir -p $DATAHOME/$DATAWORKING
cd $DATAHOME/$DATAWORKING
mkdir -p save
if [ -e save/flag.txt ] ; then
	find save/flag.txt -mmin +1439 -delete
fi
if [ -e save/flag.txt ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "current ongoing processing flag exists"
		echo
		echo "exiting"
		echo
	fi
	exit
fi
touch save/flag.txt
if [ $VERBOSE == "yes" ] ; then
	echo
	echo "starting"
	echo
	echo "raw data directory: "$DATARAW
	echo "working data directory: "$DATAHOME/$DATAWORKING/data
fi
if [ ! -e save/datanow.txt ] ; then
	echo "0000-00-00" > save/datanow.txt
fi
mv -f save/datanow.txt save/datalast.txt
echo $DATANIGHT > save/datanow.txt
echo $DATAUPDATE > save/dataupdate.txt
if [ `cat save/datanow.txt` != `cat save/datalast.txt` ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "processing new night of data"
	fi
	rm -rf data images videos text html
	rm -rf save/fitsnow.txt
	rm -rf index.html
fi
if [ `cat save/datanow.txt` == `cat save/datalast.txt` ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "processing same night of data"
	fi
fi
touch save/fitsnow.txt
mv -f save/fitsnow.txt save/fitslast.txt
mkdir -p data images videos text html
if [ ! -e $DATARAW ] ; then
	rm -rf data images videos text html
	rm -rf save/fitsnow.txt
	rm -rf index.html
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "raw data directory does not exist"
		echo
		echo "exiting"
		echo
	fi
	rm -f save/flag.txt
	exit
fi
if [ `ls $DATARAW/ | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "raw data directory files do not exist"
		echo
		echo "exiting"
		echo
	fi
	rm -f save/flag.txt
	exit
fi
# synchronize data and perform data bookkeeping
if [ $VERBOSE == "yes" ] ; then
	echo "synchronizing recent data"
fi
rsync -qav --delete --include "*.$FITSEXT" --exclude "*" $DATARAW/ data/
rename -f 's/ /_/g' data/*$FITSEXT
ls -trd data/*$FITSEXT > save/fitssync.txt
cat save/fitssync.txt | sed 's#data/##' | sed "s#\.${FITSEXT}##" > save/fitsnow.txt
diff save/fitslast.txt save/fitsnow.txt | grep '^>' | cut -c 3- > save/fitsdiff.txt
if [ $VERBOSE == "yes" ] ; then
	echo
	echo "number of total data files: "`cat save/fitsnow.txt | wc -l`
	echo "number of previous data files: "`cat save/fitslast.txt | wc -l`
	echo "number of recent data files: "`cat save/fitsdiff.txt | wc -l`
fi
cat save/fitssync.txt | sed 's#data#images#' | sed "s#${FITSEXT}#png#" > text/images.txt
cat save/fitssync.txt | sed 's#data#videos#' | sed "s#${FITSEXT}#png#" > text/videos.txt
cat save/fitssync.txt | sed 's#data#file '\''../videos#' | sed "s#${FITSEXT}#png\'#" | grep -iv $BIAS | grep -iv $DARK | grep -iv $FLAT > text/list.txt
cat save/fitssync.txt | sed 's#data#images#' | sed "s#\.${FITSEXT}#-tn\.png#" > text/tn.txt

# extract metadata from data
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "not extracting metadata for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "extracting metadata for recent data"
	fi
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt                                                                        | sed 's#data/##' | sed "s#\.${FITSEXT}##" | sed 's/ /_/g' | awk '{printf "%-26s\n",$0}'                                                                                                  >> text/image.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l DATE-OBS",$1}'                 | bash | sed 's/\..*//'                                           | awk '{printf "%-23s\n",$0}'                                                                                                  >> text/date-obs.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l DATE-OBS",$1}'                 | bash | sed 's/T.*//' | sed 's/\..*//'                           | awk '{printf "%-12s\n",$0}'                                                                                                  >> text/date-obs-date.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l DATE-OBS",$1}'                 | bash | sed 's/.*T//' | sed 's/\..*//'                           | awk '{printf "%-10s\n",$0}'                                                                                                  >> text/date-obs-time.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l INSTRUME",$1}'                 | bash | sed 's/ /_/g' | sed "s/${FITSINST}.*/${FITSINST}/"       | awk '{printf "%-6s\n",$0}'                                                                                                   >> text/instrume.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l SET-TEMP",$1}'                 | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-+.1f\n",$0}' | awk '{printf "%-7s\n",$0}'                                         >> text/set-temp.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l CCD-TEMP",$1}'                 | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-+.1f\n",$0}' | awk '{printf "%-7s\n",$0}'                                         >> text/ccd-temp.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l NAXIS1",$1}'                   | bash                                                            | awk '{printf "%-6s\n",$0}'                                                                                                   >> text/width.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l NAXIS2",$1}'                   | bash                                                            | awk '{printf "%-6s\n",$0}'                                                                                                   >> text/height.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l XBINNING -l YBINNING",$1}'     | bash                                                            | awk '{printf "%-3s\n",0.5*($1+$2)}'                                                                                          >> text/binning.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l IMAGETYP",$1}'                 | bash | sed 's/ /_/g' | sed 's/_Frame//' | sed 's/_Field//'      | awk '{printf "%-12s\n",$0}'                                                                                                  >> text/imagetyp.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l OBJECT",$1}'                   | bash | sed 's/ /_/g'                                            | awk '{printf "%-17s\n",$0}'                                                                                                  >> text/object.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l FILTER",$1}'                   | bash | sed 's/ /_/g'                                            | awk '{printf "%-11s\n",$0}'                                                                                                  >> text/filter.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l EXPTIME",$1}'                  | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-.1f\n",$0}' | awk '{printf "%-7s\n",$0}'                                          >> text/exptime.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l AIRMASS",$1}'                  | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-.2f\n",$0}' | awk '{printf "%-6s\n",$0}'                                          >> text/airmass.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l PA",$1}'                       | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-.1f\n",$0}' | awk '{printf "%-7s\n",$0}'                                          >> text/pa.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l OBJCTHA",$1}'                  | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-+.2f\n",$0}' | awk '{printf "%-7s\n",$0}'                                         >> text/objctha.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l OBJCTRA",$1}'                  | bash | sed 's# #:#g' | sed 's/\..*//'                           | awk '{printf "%-10s\n",$0}'                                                                                                  >> text/objctra.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l OBJCTDEC",$1}'                 | bash | sed 's# #:#g' | sed 's/\..*//'                           | awk '{printf "%-11s\n",$0}'                                                                                                  >> text/objctdec.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l OBJCTALT",$1}'                 | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-.1f\n",$0}' | awk '{printf "%-6s\n",$0}'                                          >> text/objctalt.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l OBJCTAZ",$1}'                  | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-.1f\n",$0}' | awk '{printf "%-7s\n",$0}'                                          >> text/objctaz.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l FWHM",$1}'                     | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-.1f\n",$0}' | awk '{printf "%-5s\n",$0}'                                          >> text/fwhm.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l CDELT1 -l CDELT2",$1}'         | bash                                                            | awk '{if ($1=="n/a") print "n/a"; else printf "%-.2f\n",0.5*(sqrt($1*$1)+sqrt($2*$2))*3600}' | awk '{printf "%-6s\n",$0}'    >> text/cdelt.txt
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "astfits -q -h0 -l CDELT1 -l CDELT2 -l FWHM",$1}' | bash                                                            | awk '{if ($3=="n/a") print "n/a"; else printf "%-.1f\n",0.5*(sqrt($1*$1)+sqrt($2*$2))*3600*$3}' | awk '{printf "%-5s\n",$0}' >> text/fwhmcdelt.txt
fi

# calculating statistics from data
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not calculating statistics for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "calculating statistics for recent data"
	fi
	cat save/fitssync.txt | grep -iv -f save/fitslast.txt | awk '{print "aststatistics -q -h0 -m",$1}'                    | bash                                                            | awk '{if ($0=="n/a") print; else printf "%-5i\n",$0}'  | awk '{printf "%-7s\n",$0}' >> text/mean.txt
fi

# create data log
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not creating log for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "creating log for recent data"
	fi
	echo "IMAGE                     UTC-DATE    UTC-TIME  INST  SET    ACTUAL WIDTH HGHT  BN TYPE        OBJECT           FILTER     EXPT   AIRM  PA     HA     RA        DEC        ALT   AZ     FWHM SCALE SEE  MEAN   " > text/obslog.txt
	paste -d '' text/image.txt text/date-obs-date.txt text/date-obs-time.txt text/instrume.txt text/set-temp.txt text/ccd-temp.txt text/width.txt text/height.txt text/binning.txt text/imagetyp.txt text/object.txt text/filter.txt text/exptime.txt text/airmass.txt text/pa.txt text/objctha.txt text/objctra.txt text/objctdec.txt text/objctalt.txt text/objctaz.txt text/fwhm.txt text/cdelt.txt text/fwhmcdelt.txt text/mean.txt >> text/obslog.txt
	echo "IMAGE                     UTC-DATE    UTC-TIME  INST  SET    ACTUAL WIDTH HGHT  BN TYPE        OBJECT           FILTER     EXPT   AIRM  PA     HA     RA        DEC        ALT   AZ     FWHM SCALE SEE  MEAN   " >> text/obslog.txt
fi

# create full-size png images
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "not creating full-size png images for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "creating full-size png images for recent data"
	fi
	paste text/width.txt text/height.txt save/fitssync.txt text/images.txt | awk '{print "xvfb-run -a ds9 -iconify -squared -zscale -invert -width",$1,"-height",$2,$3,"-export",$4,"-exit"}' | grep -iv -f save/fitslast.txt | bash
fi

# flip full-size png images on y-axis
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not flipping orientation of full-size png images for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $FLIP == "no" ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo "not flipping orientation of full-size png images for recent data"
		fi
	fi
	if [ $FLIP == "yes" ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo "flipping orientation of full-size png images for recent data"
		fi
		paste text/images.txt | awk '{print "mogrify -quality 100% -flip",$1}' | grep -iv -f save/fitslast.txt | bash
	fi
fi

# flop full-size png images on x-axis
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not flopping orientation of full-size png images for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $FLOP == "no" ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo "not flopping orientation of full-size png images for recent data"
		fi
	fi
	if [ $FLOP == "yes" ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo "flopping orientation of full-size png images for recent data"
		fi
		paste text/images.txt | awk '{print "mogrify -quality 100% -flop",$1}' | grep -iv -f save/fitslast.txt | bash
	fi
fi

# rotate full-size png images
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not rotating orientation of full-size png images for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $ROTATE == "0" ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo "not rotating orientation of full-size png images for recent data"
		fi
	fi
	if [ $ROTATE == "90" ] || [ $ROTATE == "180" ] || [ $ROTATE == "270" ] || [ $ROTATE == "-90" ] || [ $ROTATE == "-180" ] || [ $ROTATE == "-270" ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo "rotating orientation of full-size png images for recent data"
		fi
		if [ $ROTATE == "90" ] || [ $ROTATE == "-270" ] ; then
			paste text/images.txt | awk '{print "mogrify -quality 100% -rotate 90",$1}' | grep -iv -f save/fitslast.txt | bash
		fi
		if [ $ROTATE == "180" ] || [ $ROTATE == "-180" ] ; then
			paste text/images.txt | awk '{print "mogrify -quality 100% -rotate 180",$1}' | grep -iv -f save/fitslast.txt | bash
		fi
		if [ $ROTATE == "270" ] || [ $ROTATE == "-90" ] ; then
			paste text/images.txt | awk '{print "mogrify -quality 100% -rotate 270",$1}' | grep -iv -f save/fitslast.txt | bash
		fi
	fi
fi

# create full-size png image annotations
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not annotating full-size png images for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ ! -e save/$FONT ] ; then
		if [ -e $FONTDIR/$FONT ] ; then
			cp $FONTDIR/$FONT save/$FONT
		fi
		if [ ! -e save/$FONT ] ; then
			FONTSTRING=""
		fi
	fi
	if [ -e save/$FONT ] ; then
		FONTSTRING="-font save/$FONT"
	fi
	if [ $VERBOSE == "yes" ] ; then
		echo "annotating full-size png images for recent data"
	fi
	FONTSIZE=`cat text/height.txt text/width.txt | awk -v fontreduce="$FONTREDUCE" '{ sum += $1 } END { print sum / NR / fontreduce }'`
	paste text/image.txt text/date-obs.txt text/images.txt | awk -v fontstring="$FONTSTRING" -v fontsize="$FONTSIZE" -v fontcolor="$FONTCOLOR" '{print "mogrify -quality 100%",fontstring,"-fill",fontcolor,"-pointsize",fontsize,"-gravity north -annotate 0",$1,"-gravity south -annotate 0",$2,$3}' | grep -iv -f save/fitslast.txt | bash
fi

# create thumbnail png images
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not creating thumbnail png images for recent data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "creating thumbnail png images for recent data"
	fi
	paste text/images.txt text/tn.txt | awk -v tnscale="$TNSCALE" '{print "convert -quality 100% -resize "tnscale"x"tnscale,$1,$2}' | grep -iv -f save/fitslast.txt | bash
fi

# create individual png images for mp4 video
if [ `cat text/list.txt | wc -l` == 0 ] || [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "not creating video png images for recent data"
	fi
fi
if [ `cat text/list.txt | wc -l` != 0 ] && [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "creating video png images for recent data"
	fi
	paste text/images.txt text/videos.txt | awk -v vidscale="$VIDSCALE" '{print "convert -quality 100% -resize "vidscale"x"vidscale,$1,$2}' | grep -iv $BIAS | grep -iv $DARK | grep -iv $FLAT | grep -iv -f save/fitslast.txt | bash
fi

# create mp4 video
if [ `cat text/list.txt | wc -l` == 0 ] || [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "not creating mp4 video for all data"
	fi
fi
if [ `cat text/list.txt | wc -l` != 0 ] && [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo "creating mp4 video for all data"
	fi
	ffmpeg -v quiet -y -r:v 12 -f concat -safe 0 -i text/list.txt -codec:v libx264 -preset veryslow -pix_fmt yuv420p -crf 0 -an -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" videos/$DATANIGHT.mp4
fi

# create html web page
if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "not creating html page for all data"
	fi
fi
if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "creating html page for all data"
	fi
	touch html/index.html
	echo -n "<html><title>"$OBSNAME" Snapshot</title>" > html/index.html
	echo -n "<link rel='preconnect' href='https://fonts.googleapis.com'>" >> html/index.html
	echo -n "<link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>" >> html/index.html
	echo -n "<link href='https://fonts.googleapis.com/css2?family=Ubuntu+Mono:ital,wght@0,400;0,700;1,400;1,700&family=Ubuntu:ital,wght@0,300;0,400;0,500;0,700;1,300;1,400;1,500;1,700&display=swap' rel='stylesheet'>" >> html/index.html
	echo -n "<style type='text/css'> body { font-family : 'Ubuntu', sans-serif; } pre { font-family : 'Ubuntu Mono', monospace; } h2, h3, h4 { margin : 0; }</style>" >> html/index.html
	echo -n "<body bgcolor="$BGCOLOR" text="$FONTCOLOR" link="$FONTCOLOR" alink="$FONTCOLOR" vlink="$FONTCOLOR">" >> html/index.html
	echo -n "<h2>"$OBSNAME" Snapshot &middot; " >> html/index.html
	cat save/datanow.txt | tr -d '\n' >> html/index.html
	echo -n "</h2>" >> html/index.html
	echo -n "<h3><a href='#log'>log</a> &middot; <a href='#images'>images</a> &middot; <a href='#video'>video</a> &middot; <a href='"$WEBDIR"/'>recent</a> &middot; <a href='"$WEBDIR"/archive/'>archive</a></h3>" >> html/index.html
	echo -n "<h4>last updated " >> html/index.html
	cat save/dataupdate.txt | tr -d '\n' >> html/index.html
	echo -n "</h4>" >> html/index.html
	echo "<hr><a name='log'><pre>" >> html/index.html
	cat text/obslog.txt | awk '{ if ($11 != old) print " \n"$0; if ($11 == old) print $0; old = $11; }' | sed '1d' >> html/index.html
	echo "</pre><hr><a name='images'>" >> html/index.html
	paste text/images.txt text/tn.txt | awk '{print "<a href='\''"$1"'\''><img src='\''"$2"'\''></a>"}' >> html/index.html
	echo "<hr><a name='video'>" >> html/index.html
	if [ -e videos/$DATANIGHT.mp4 ] ; then
		echo -n "<video src='videos/" >> html/index.html
		cat save/datanow.txt | tr -d '\n' >> html/index.html
		echo ".mp4' type='video/mp4' controls></video>" >> html/index.html
	fi
	echo -n "<hr>" >> html/index.html
	echo -n "<h2>"$OBSNAME" Snapshot &middot; " >> html/index.html
	cat save/datanow.txt | tr -d '\n' >> html/index.html
	echo -n "</h2>" >> html/index.html
	echo -n "<h3><a href='#log'>log</a> &middot; <a href='#images'>images</a> &middot; <a href='#video'>video</a> &middot; <a href='"$WEBDIR"/'>recent</a> &middot; <a href='"$WEBDIR"/archive/'>archive</a></h3>" >> html/index.html
	echo -n "<h4>last updated " >> html/index.html
	cat save/dataupdate.txt | tr -d '\n' >> html/index.html
	echo -n "</h4>" >> html/index.html
	echo -n "</body></html>" >> html/index.html
fi
touch images/index.html
touch videos/index.html
cp html/index.html index.html

# synchronize to remote server for current night page including html, png, and mp4 files
if [ $WEBARCHIVE == "no" ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "not synchronizing tonight's current html page for all data"
	fi
fi
if [ $WEBNOW == "yes" ] ; then
	if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo
			echo "not synchronizing tonight's current html page for all data"
		fi
	fi
	if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo
			echo "synchronizing tonight's current html page for all data"
			echo "write location: "$REMOTEUSER"@"$REMOTEHOST":"$REMOTEDIR"/"
			echo "read location: "$WEBPROTOCOL"://"$WEBHOST""$WEBDIR"/"
		fi
		ssh -q $REMOTEUSER@$REMOTEHOST mkdir -p $REMOTEDIR
		ssh -q $REMOTEUSER@$REMOTEHOST mkdir -p $REMOTEDIR/images
		if [ -e videos/$DATANIGHT.mp4 ] ; then
			ssh -q $REMOTEUSER@$REMOTEHOST mkdir -p $REMOTEDIR/videos
		fi
		rsync -qav --delete html/index.html $REMOTEUSER@$REMOTEHOST:$REMOTEDIR/index.html
		rsync -qav --delete --include "*.png" --exclude "*" images/ $REMOTEUSER@$REMOTEHOST:$REMOTEDIR/images/
		if [ -e videos/$DATANIGHT.mp4 ] ; then
			rsync -qav --delete --include "*.mp4" --exclude "*" videos/ $REMOTEUSER@$REMOTEHOST:$REMOTEDIR/videos/
		fi
	fi
fi

# synchronize to remote server for archival nights pages including html, png, and mp4 files
if [ $WEBARCHIVE == "no" ] ; then
	if [ $VERBOSE == "yes" ] ; then
		echo
		echo "not synchronizing tonight's archive html page for all data"
	fi
fi
if [ $WEBARCHIVE == "yes" ] ; then
	if [ `cat save/fitsdiff.txt | wc -l` == 0 ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo
			echo "not synchronizing tonight's archive html page for all data"
		fi
	fi
	if [ `cat save/fitsdiff.txt | wc -l` != 0 ] ; then
		if [ $VERBOSE == "yes" ] ; then
			echo
			echo "synchronizing tonight's archive html page for all data"
			echo "write location: "$REMOTEUSER"@"$REMOTEHOST":"$REMOTEDIR"/archive/"
			echo "read location: "$WEBPROTOCOL"://"$WEBHOST""$WEBDIR"/archive/"
		fi
		ssh -q $REMOTEUSER@$REMOTEHOST mkdir -p $REMOTEDIR/archive/$DATANIGHT
		ssh -q $REMOTEUSER@$REMOTEHOST mkdir -p $REMOTEDIR/archive/$DATANIGHT/images
		if [ -e videos/$DATANIGHT.mp4 ] ; then
			ssh -q $REMOTEUSER@$REMOTEHOST mkdir -p $REMOTEDIR/archive/$DATANIGHT/videos
		fi
		rsync -qav --delete html/index.html $REMOTEUSER@$REMOTEHOST:$REMOTEDIR/archive/$DATANIGHT/index.html
		rsync -qav --delete --include "*.png" --exclude "*" images/ $REMOTEUSER@$REMOTEHOST:$REMOTEDIR/archive/$DATANIGHT/images/
		if [ -e videos/$DATANIGHT.mp4 ] ; then
			rsync -qav --delete --include "*.mp4" --exclude "*" videos/ $REMOTEUSER@$REMOTEHOST:$REMOTEDIR/archive/$DATANIGHT/videos/
		fi
	fi
fi

# cleanup
rm -f save/flag.txt
if [ $VERBOSE == "yes" ] ; then
	echo
	echo ending
	echo
fi
