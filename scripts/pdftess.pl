#!perl

use strict;
use warnings;

use 5.010;

use utf8;

my $pdffile = 'deu.pdf';
my $basename = $pdffile;
$basename =~ s/\.pdf$//i;

pdf2text($pdffile);
pdf2png($pdffile);

  my $dir = './';
  my @files;
  opendir(my $dir_dh, "$dir") || die "Can't opendir $dir: $!";
  @files = grep { /^[^._]/ && /$basename[_]\d+\.png$/ && -f "$dir/$_" } readdir($dir_dh);
  closedir $dir_dh;

  for my $file (sort @files) {
    tesseract($file);
  }

sub pdf2text {
  my ($pdffile) = @_;

# pdftoppm -r 600 -png -sep _ -forcenum myfile.pdf myfile
# /usr/local/bin/pdftoppm

  my $command     = '/usr/local/bin/pdftotext';
  my $resolution  = '-r 600';
  #my $layout    = '-layout';
  my $layout    = '';
  my $basename    = '';

  $basename = $pdffile;
  $basename =~ s/\.pdf$//i;
  $basename .= '.gt.txt';

  my @command = ($command,$resolution,$layout,$pdffile,$basename);

  my $command_string = join(' ', @command);
  print STDERR $command_string, "\n";
  system($command_string);

  if ($? == -1) {
    #print STDERR "wget command failed: $!\n";
    #return 0;
    die "$command $pdffile failed: $!";
  }

  my $dir = './';
  my @files;
  opendir(my $dir_dh, "$dir") || die "Can't opendir $dir: $!";
  @files = grep { /^[^._]/ && /$basename\.gt\.txt$/ && -f "$dir/$_" } readdir($dir_dh);
  closedir $dir_dh;

  for my $file (sort @files) {

    $file =~ m/$$basename\.gt\.txt$/;
    my $number = $1;

    #my $new_name = $basename . '_' . sprintf("%04s",$number) . '.png';
    my $new_name = $basename;

    #say "  $file -> $new_name";

    # This is unsecure and can overwrite existing files with the same name
    # Also use File::Copy qw(move); would be more portable

    rename("$dir/$file","$dir/$new_name");
  }

}

sub pdf2png {
  my ($pdffile) = @_;

# pdftoppm -r 600 -png -sep _ -forcenum myfile.pdf myfile
# /usr/local/bin/pdftoppm

  my $command     = '/usr/local/bin/pdftoppm';
  my $resolution  = '-r 600';
  my $imageformat = '-png';
  my $seperator   = '-sep _';
  my $forcenum    = '-forcenum';
  my $basename    = '';

  $basename = $pdffile;
  $basename =~ s/\.pdf$//i;

  my @command = ($command,$resolution,$imageformat,$seperator,$forcenum,$pdffile,$basename);

  my $command_string = join(' ', @command);
  print STDERR $command_string, "\n";
  system($command_string);

  if ($? == -1) {
    #print STDERR "wget command failed: $!\n";
    #return 0;
    die "$command $pdffile failed: $!";
  }

  my $dir = './';
  my @files;
  opendir(my $dir_dh, "$dir") || die "Can't opendir $dir: $!";
  @files = grep { /^[^._]/ && /$basename[_]\d+\.png$/ && -f "$dir/$_" } readdir($dir_dh);
  closedir $dir_dh;

  for my $file (sort @files) {

    $file =~ m/$basename[_](\d+)\.png$/;
    my $number = $1;

    my $new_name = $basename . '_' . sprintf("%04s",$number) . '.png';

    #say "  $file -> $new_name";

    # This is unsecure and can overwrite existing files with the same name
    # Also use File::Copy qw(move); would be more portable

    rename("$dir/$file","$dir/$new_name");
  }

}

sub tesseract {
  my ($imagefile) = @_;
# tesseract  U0000_2.png U0000_2.png
# -c load_bigram_dawg=false -c load_freq_dawg=false -c load_system_dawg=false
# -c tessedit_write_images=true
# --oem 3
# makebox hocr txt

  my $command  = '/usr/local/bin/tesseract';
  my $basename = $imagefile;
  my $language = '-l deu';
  my $options  = '-c tessedit_write_images=true'; # writes tessinput.tif
  my $files    = 'makebox hocr txt'; # wites $base.box $base.hocr $base.txt

  $basename =~ s/\.(png|jpg|tif|gif)$//i;


  my @command = ($command, $imagefile, $basename, $language, $options, $files);

  #print STDERR join(' ',@command),"\n";

  my $command_string = join(' ', @command);
  print STDERR $command_string, "\n";
  system($command_string);

  if ($? == -1) {
    die "$command $imagefile failed: $!";
  }

  my $new_name = $basename . '.tessinput.tif';

  rename('tessinput.tif',"$new_name");
}

=pod

#!/bin/sh
#PAGES=46 # set to the number of pages in the PDF
SOURCE=mobot31753002852678.pdf # set to the file name of the PDF
OUTPUT=mobot31753002852678_test_lat_ # set to the final output file
#RESOLUTION=300 # set to the resolution the scanner used (the higher, the better)
RESOLUTION=72
#LANGFILE='deu-frak+deu'
LANGFILE='lat'

#xpdf-pdfinfo pamphlet-low.pdf | grep Pages: | awk '{print $2}' | tail -n 1
PAGES=$(pdfinfo $SOURCE | grep Pages: | awk '{print $2}')
#pdfinfo "${PDFFILE}" | grep Pages | sed 's/[^0-9]*//'

#touch $OUTPUT
for i in `seq 1 $PAGES`; do
#for i in `seq 1 2`; do
    convert -density $RESOLUTION -depth 8 $SOURCE\[$(($i - 1 ))\] $OUTPUT$i.png
# convert -density 600 foo.pdf foo-%02d.jpg
#    tesseract page$i.tif >> $OUTPUT
#    tesseract -l $LANGFILE hocr page$i.png $OUTPUT$i
     tesseract $OUTPUT$i.png $OUTPUT$i -l $LANGFILE -c tessedit_write_images=true makebox hocr txt
     mv tessinput.tif $OUTPUT$i.tif
     cat $OUTPUT$i.txt >> $OUTPUT.txt
done


=cut
