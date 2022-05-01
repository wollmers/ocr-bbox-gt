use strict;
use warnings;
use utf8;

use lib qw(
  /Users/helmut/github/ocr-hw/hOCR-Parse/lib
  /Users/helmut/github/ocr-hw/OCR-Font/lib
  /Users/helmut/github/ocr-hw/OCR-Tesseract-Files/lib
  /Users/helmut/github/ocr-hw/hOCR-Parse/lib
  /Users/helmut/github/ocr-hw/OCR-Draw/lib
  /Users/helmut/github/ocr-hw/OCR-Geo/lib
  ../lib
);

use Image::Magick;

use Time::HiRes qw(time);

use Data::Dumper;

use OCR::Tesseract::Files::Box;
use hOCR::Parse;

use OCR::Image;
use OCR::Draw;

use OCR::Geo::SpaceIndex;

binmode(STDOUT,":encoding(UTF-8)");
binmode(STDERR,":encoding(UTF-8)");

my $WRITE_IMAGES = 1;
my $CREATE_HTML  = 1;
my $blob_glyphs  = 0;
my $dump_json    = 0;
my $VERBOSE      = 0;
my $block_limit  = 0;

my $image_quad_dim = 16;

#my $img_bits = Image::Bits->new();

my $page = {
	#'image_file' => '../isisvonoken1826oken_0007.tessinput.tif',
	#'image_file' => '../isisvonoken1826oken_0009.tessinput.tif',
	'image_file' => 'pr_3787.png',
	'image'		 => '',
	'columns'    => {},
	'rows'       => {},
	'width'		 => 0,
	'height'     => 0,
	'top'        => 0,
	'bottom'     => 0,
	'left'       => 0,
	'right'      => 0,
	'id'		 => '',
	'class'		 => '',
};

#my $basename   = 'pr_3787.psm6.png';
my $basename   = 'pr_3787.oem0.psm6.lat.png';
#$basename =~ s/\.png$//i;
my $boxfile    = $basename . '.box';
my $boxoutfile = $basename . '.box.png';
my $boxgtfile  = $basename . '.box.gt.png';
my $hocrfile   = $basename . '.hocr';

my ($html,$index) = hOCR::Parse->new()->parse($hocrfile);
# $index->{$element->{'att'}->{$attribute}} = $element_entry;

#my $boxes = OCR::Geo::SpaceIndex->new();

#$boxes->new_index($page, 10);

#for my $element_id (keys %$index) {
#	$boxes->add($index->{$element_id}->{'bbox'});
#}

#for my $charbox (@$charboxes) {
#	$boxes->add($charboxes->{$charbox}->{'bbox'});
#}

##############
my $start_page_blob = time;

print 'image_file: ',$page->{'image_file'},"\n" if ($VERBOSE >= 1);

my $ocr_image = OCR::Image->new();

$page->{'image'} = $ocr_image->blob_page($page->{'image_file'}, $page);
$ocr_image->page_metrics($page);

my $ocr_draw = OCR::Draw->new();

my $box_image = $page->{'image'}->Clone();
my $box_gt_image = $page->{'image'}->Clone();

if (1) {
	my $color 		= 'red'; # none red
	my $strokewidth = 1; # 0 1 2
	my $fill 		= 'none'; # none yellow

	#my $box_image = $page->{'image'}->Clone();

	ELEMENT: for my $element_id (keys %$index) {
    	if ( $element_id =~ m/^line/ ) {
    	    my $line_element = $index->{$element_id};

    	    unless (line_has_chars($line_element)) {
    	        print 'line without text: ', $element_id, ' text: ',line_has_chars($line_element),"\n";
    	        my $bbox     = $line_element->{'bbox'};
    	        $ocr_draw->draw_box($box_image, $bbox, 'blue', 1, 'none') if (0);
    	        next ELEMENT;
    	    }

    	    my $bbox     = $line_element->{'bbox'};
    	    my $baseline = $line_element->{'baseline'};
    		$ocr_draw->draw_box($box_image, $bbox, 'green', 1, 'none') if (0);

    		# baseline 0.019 -22; would stand for y = 0.019 x - 22

    		my $x1 = $bbox->{'left'};
    		my $x2 = $bbox->{'right'};
    		my $y1 = $bbox->{'bottom'} + $baseline->{'offset'};
    		# y1 = bottom - offset
    		my $y2 = $bbox->{'bottom'}
    			+ $baseline->{'skew'} * ( $bbox->{'right'} - $bbox->{'left'} )
    			+ $baseline->{'offset'};
    		# y2 = skew * (right - left)
    		my $points = "$x1,$y1 $x2,$y2";
    		$ocr_draw->draw_line($box_image, $x1, $y1, $x2, $y2, 'blue', 1, 'none') if (0);

    		# x_descenders
    		my $y1_descender = $y1 + $line_element->{'x_descenders'};
    		my $y2_descender = $y2 + $line_element->{'x_descenders'};
    		$points = "$x1,$y1_descender $x2,$y2_descender";
    		$ocr_draw->draw_line($box_image, $x1, $y1_descender, $x2, $y2_descender, 'blue', 1, 'none') if (0);

    		# x_size
    		my $y1_size = $y1 - $line_element->{'x_size'} + $line_element->{'x_ascenders'};
    		my $y2_size = $y2 - $line_element->{'x_size'} + $line_element->{'x_ascenders'};
    		$points = "$x1,$y1_size $x2,$y2_size";
    		$ocr_draw->draw_line($box_image, $x1, $y1_size, $x2, $y2_size, 'blue', 1, 'none') if (0);

    		# x_ascenders
    		my $y1_ascender = $y1_size + $line_element->{'x_ascenders'};
    		my $y2_ascender = $y2_size + $line_element->{'x_ascenders'};
    		$points = "$x1,$y1_ascender $x2,$y2_ascender";
    		$ocr_draw->draw_line($box_image, $x1, $y1_ascender, $x2, $y2_ascender, 'blue', 1, 'none') if (0);

    	}
	}
	#$box_image->Write($boxoutfile);
}

my $charboxes = OCR::Tesseract::Files::Box->new()->parse_file($boxfile, $page->{'bbox'}->{'bottom'});

my @sorted_word_keys
    = sort { $index->{$a}->{'sort_id'} <=>  $index->{$b}->{'sort_id'} }
    grep { m/^word/ } ( keys %$index );

#print join(' ', @sorted_word_keys),"\n";

my $char_index = 0;
for my $word_key (@sorted_word_keys) {
    my $word = $index->{$word_key}->{'text'};
    my @word_chars = split(//,$word);
    my $word_char_index = 0;
    #print "\n",$word,':';
    for my $char (@word_chars) {
        if ($word_char_index == 0) {
            $charboxes->[$char_index]->{'word_begin'} = 1;
            #print ' ',$charboxes->[$char_index]->{'char'};
        }
        else {
            $charboxes->[$char_index]->{'word_begin'} = 0;
            #print $charboxes->[$char_index]->{'char'};
        }
        $word_char_index++;
        $char_index++;
    }
}

#print "\n",'$char_index:',$char_index,"\n";


#exit;

if (1) {

    my $char_widths  = {};
    my $char_heights = {};

    for my $charbox (@$charboxes) {
        my $width  = $charbox->{'bbox'}->{'width'};
        my $height = $charbox->{'bbox'}->{'height'};
        my $char  = $charbox->{'char'};
        $char_widths->{$char}->{$width}++;
        $char_heights->{$char}->{$height}++;
    }

    my $best_widths = {};

    print "\n",'char widths',"\n";
    for my $char (sort keys %{$char_widths}) {
        print $char;
        my $widths = $char_widths->{$char};
        my ($best_width) = (sort {$widths->{$b} <=> $widths->{$a}} keys %{$widths} );
        $best_widths->{$char} = $best_width;
        for my $width (sort {$widths->{$b} <=> $widths->{$a}} keys %{$widths} ) {
            print ' ', $width, ': ',$widths->{$width},', ';
        }
        print "\n";
    }

    print "\n",'best widths',"\n";
    for my $char (sort keys %{$best_widths}) {
        print $char, ': ',$best_widths->{$char},"\n";
    }

    my $best_heights = {};

    print "\n",'char heights',"\n";
    for my $char (sort keys %{$char_heights}) {
        print $char;
        my $heights = $char_heights->{$char};
        my ($best_height) = (sort {$heights->{$b} <=> $heights->{$a}} keys %{$heights} );
        $best_heights->{$char} = $best_height;
        for my $height (sort {$heights->{$b} <=> $heights->{$a}} keys %{$heights} ) {
            print ' ', $height, ': ',$heights->{$height},', ';
        }
        print "\n";
    }

    print "\n",'best heights',"\n";
    for my $char (sort keys %{$best_heights}) {
        print $char, ': ',$best_heights->{$char},"\n";
    }

	my $color 		= 'red'; # none red
	my $strokewidth = 1; # 0 1 2
	my $fill 		= 'none'; # none yellow

	#my $charboxes = OCR::Tesseract::Files::Box->new()->parse_file($boxfile, $page->{'bbox'}->{'bottom'});

	print STDERR '@$charboxes: ',scalar(@$charboxes),"\n";
	print STDERR '$page->{bottom}: ',"$page->{'bottom'}","\n";
	print STDERR '$page->{bbox}->{bottom}: ',"$page->{'bbox'}->{'bottom'}","\n";

	#for my $charbox (@$charboxes) {
	#	$boxes->add($charboxes->{$charbox}->{'bbox'});
	#}

	#print Dumper($charboxes);

	my $width_errors = {
	    'exact' => 0,
	    'in'  => 0,
	    'out'    => 0,
	};

    my $last_x = 0;
    for my $charbox (@$charboxes) {
        my $char  = $charbox->{'char'};
        if ($charbox->{'word_begin'}) { $last_x = $charbox->{'bbox'}->{'left'}; }
        my $width = $charbox->{'bbox'}->{'width'};
        my $best_width = $best_widths->{$char};
        my $width_diff = abs($width - $best_width);
        my %bbox = %{$charbox->{'bbox'}};
        if ($width_diff == 0 && $charbox->{'bbox'}->{'left'} >= $last_x ) {
            $ocr_draw->draw_box($box_image, $charbox->{'bbox'}, 'green', 1, 'none' ) if (1);
            $ocr_draw->draw_box($box_gt_image, $charbox->{'bbox'}, 'green', 1, 'none' ) if (1);
            $last_x = $charbox->{'bbox'}->{'right'};
            $width_errors->{'exact'}++;
        }
        elsif ($width_diff <= 2) {
            $ocr_draw->draw_box($box_image, $charbox->{'bbox'}, 'orange', 1, 'none' ) if (1);
            if ( $charbox->{'bbox'}->{'left'} < $last_x ) {
                $bbox{'left'} = $last_x + 1;
                $bbox{'right'} = $last_x + $best_width + 1;
            }
            $ocr_draw->draw_box($box_gt_image, \%bbox, 'orange', 1, 'none' ) if (1);
            $last_x = $last_x + $best_width +1;
            $width_errors->{'in'}++;
        }
        else {
            $ocr_draw->draw_box($box_image, $charbox->{'bbox'}, 'red', 1, 'none' ) if (1);
            $bbox{'left'} = $last_x;
            $bbox{'right'} = $last_x + $best_width;
            $ocr_draw->draw_box($box_gt_image, \%bbox, 'red', 1, 'none' ) if (1);
            $last_x = $last_x + $best_width +1;
            $width_errors->{'out'}++;
        }
        #unless ($charbox->{'char'} eq '~') {
        	##$ocr_draw->draw_box($box_image, $charbox->{'bbox'}, $color, 1, 'none', $page) if (1);
        	#$ocr_draw->draw_box($box_image, $charbox->{'bbox'}, 'red', 1, 'none' ) if (1);
        #}
    }

    print 'width errors',"\n",
        '    exact: ',$width_errors->{'exact'},"\n",
        '    in   : ',$width_errors->{'in'},"\n",
        '    out  : ',$width_errors->{'out'},"\n";

}

if (0) {

    		my $x1 = 26;
    		my $x2 = 897;
    		my $y1 = 44;
    		# y1 = bottom - offset
    		my $y2 = 58;
    		my $points = "$x1,$y1 $x2,$y2";
    		$ocr_draw->draw_line($box_image, $x1, $y1, $x2, $y2, 'skyblue', 1, 'none') if (1);
}

my $font_metrics = {
    'base'      => -2,
    'x-height'  => 52, # top('x') + abs('base') = 50 + 2
    'ascender'  => 96 - 52, # 44
    'descender' => 23,
	'bottom' => [
	 	[ -31, '7' ],
	 	[ -28, '5' ],
	 	[ -27, '3' ],
	 	[ -26, '9' ],
	 	[ -25, ',' ],
	 	[ -21, 'P 4' ],
	 	[ -20, 'j F Y ;' ],
	 	[ -19, 'h q { }' ],
	 	[ -18, 'g p y z' ],
	 	[ -17, 'H [ ]' ],
	 	[ -16, 'J ( )' ],
	 	[ -15, ' x ß' ],
	 	[ -14, 'f ſ' ],
	 	[ -13,  'Z' ],
	 	[ -3, 'c l s K' ],
	 	[ -2, 'a b e i k m n r u v w B C D E G I L O Q R S T U V W X ä ü Ö Ü 0 ! % ? / . : Æ æ Œ'],
	 	[ -1, 'd o t A M N ö Ä 1 6 8 œ' ],
	 	[ -0, '2' ],
	 	[ 2, '+ < > » «' ],
	 	[ 18,  '= -' ],
	 	[ 33, '·' ],
	 	[ 35,  '" \'' ],
	 	[ 44, '*' ],
	 ],
	'top' => [
	 	[ 16, '.' ],
	 	[ 18, ',' ],
	 	[ 42, '= -' ],
	 	[ 48, 'm' ],
	 	[ 49, 'a c n q r u z ; :' ],
	 	[ 50, 'e g o x · æ œ' ],
	 	[ 52, 'w' ],
	 	[ 53, 'p 4' ],
	 	[ 54, 'v 3 9' ],
	 	[ 55, 'y 1' ],
	 	[ 56, '2 7' ],
	 	[ 57, '0' ],
	 	[ 58, 's + < > » «' ],
	 	[ 60, '5' ],
	 	[ 66, 'd t' ],
	 	[ 68, 'ä ö ü' ],
	 	[ 69, '! ?' ],
	 	[ 70, 'j ſ' ],
	 	[ 71, 'i { }' ],
	 	[ 72, 'b h k l' ],
	 	[ 73, 'f' ],
	 	[ 74, 'N' ],
	 	[ 75, 'M T X ß' ],
	 	[ 76, 'A C D E F G H I J K L P U V W Z Æ' ],
	 	[ 77, 'B R S' ],
	 	[ 78, '8 " \'' ],
	 	[ 79, 'O Y 6 Œ' ],
	 	[ 80, '%' ],
	 	[ 81, '/' ],
	 	[ 86, 'Q' ],
	 	[ 88, '( ) ]' ],
	 	[ 89, '[' ],
	 	[ 90, 'Ä Ü' ],
	 	[ 94, '*' ],
	 	[ 96, 'Ö' ],
	],
	'aspect' => [
	 	[ 0.4, '=' ],
	 	[ 0.6, 'Œ' ],
	 	[ 0.7, 'M Æ' ],
	 	[ 0.8, 'm W' ],
	 	[ 0.9, 'w D N Q S V œ' ],
	 	[ 1.0, 'B R 0 % * + . æ' ],
	 	[ 1.1, 'n E G K U X - ·' ],
	 	[ 1.2, 'u A C O < >' ],
	 	[ 1.3, 'a I P T Ü 2' ],
	 	[ 1.4, 'H Ä Ö 4 " /' ],
	 	[ 1.5, 'o r v J Y Z » «' ],
	 	[ 1.6, 'F ü' ],
	 	[ 1.7, 'c e s 8' ],
	 	[ 1.8, 'y L ä 1 6 9' ],
	 	[ 1.9, 'g x 5' ],
	 	[ 2.0, 'b d p q ö' ],
	 	[ 2.1, 'ß 3 7' ],
	 	[ 2.2, ',' ],
	 	[ 2.3, 'h ?' ],
	 	[ 2.4, 'k t' ],
	 	[ 2.9, 'z' ],
	 	[ 3.0, 'f' ],
	 	[ 3.1, ':' ],
	 	[ 3.2, 'i l' ],
	 	[ 3.5, '{ } \' ſ' ],
	 	[ 3.8, 'j ;' ],
	 	[ 4.2, '( )' ],
	 	[ 4.4, ']' ],
	 	[ 4.5, '[' ],
	 	[ 4.6, '!' ],
	],
};

my $font_chars = {};

font_init($font_metrics, $font_chars);

if (0) {

    my %baselinechars;
    ##map { $baselinechars{$_}++ } split('','abcdeilmnorstu');
	map { $baselinechars{$_}++ } split('','acdelmnorstu');

    my @points;

    for my $charbox (@$charboxes) {
    	if (exists $baselinechars{$charbox->{'char'}} ) {
    	    my $x = $charbox->{'bbox'}->{'left'};
    	    my $y = $charbox->{'bbox'}->{'bottom'};
    		push @points, "$x,$y";
    	}
    }
    my $poly_points = join(' ', @points);

    print STDERR '$poly_points: ',$poly_points,"\n";

    $ocr_draw->draw_polyline($box_image, $poly_points, 'blue', 1, 'none') if (1);
}

if (0) {

	my $linechars = {};

	my $wordtops = {};
	my $wordbottoms = {};

	for my $element_id (sort keys %$index) {

    	if ( $element_id =~ m/^word/ ) {
    		my $word = $index->{$element_id};
			$wordtops->{$word->{'bbox'}->{'top'}}++;
			$wordbottoms->{$word->{'bbox'}->{'bottom'}}++;
    	}
    }

	print '*** wordtops',"\n";
	for my $top (sort { $a <=> $b } keys %{$wordtops}) {
		print $top,' ',$wordtops->{$top},"\n";
	}

###----- top gaps ------
	# $word_top_gaps->{size}->{min} = max
	my $word_top_gaps = {};
	my $last_top;
	for my $top (sort { $a <=> $b } keys %{$wordtops}) {
	    print '$top: ',$top,"\n";
		if (!defined $last_top) {
			$last_top = $top * 1;
		}
		else {
			my $size = $top - $last_top;
			$word_top_gaps->{$size}->{$last_top} = $top;
			$last_top = $top;
		}
	}

	print '*** word_top_gaps',"\n";
	for my $gap (sort { $a <=> $b } keys %{$word_top_gaps}) {
		for my $min (sort { $a <=> $b } keys %{$word_top_gaps->{$gap}}) {
			print $gap,' ', $min, ' ', $word_top_gaps->{$gap}->{$min},"\n";
		}
	}

###------

	print '*** wordbottoms',"\n";
	for my $bottom (sort { $a <=> $b } keys %{$wordbottoms}) {
		print $bottom,' ',$wordbottoms->{$bottom},"\n";
	}

###----- bottom gaps ------
	# $word_bottom_gaps->{size}->{min} = max
	my $word_bottom_gaps = {};
	my $last_bottom;
	for my $bottom (sort { $a <=> $b } keys %{$wordbottoms}) {
	    print '$top: ',$bottom,"\n";
		if (!defined $last_bottom) {
			$last_bottom = $bottom * 1;
		}
		else {
			my $size = $bottom - $last_bottom;
			$word_bottom_gaps->{$size}->{$last_bottom} = $bottom;
			$last_bottom = $bottom;
		}
	}

	print '*** word_bottom_gaps',"\n";
	for my $gap (sort { $a <=> $b } keys %{$word_bottom_gaps}) {
		for my $min (sort { $a <=> $b } keys %{$word_bottom_gaps->{$gap}}) {
			print $gap,' ', $min, ' ', $word_bottom_gaps->{$gap}->{$min},"\n";
		}
	}


########
	my $chartops = {};
	my $charbottoms = {};

	for my $charbox (@$charboxes) {
		$chartops->{$charbox->{'bbox'}->{'top'}}++;
		$charbottoms->{$charbox->{'bbox'}->{'bottom'}}++;
	}

	print '*** chartops',"\n";
	for my $top (sort { $a <=> $b } keys %{$chartops}) {
		print $top,' ',$chartops->{$top},"\n";
	}

	print '*** charbottoms',"\n";
	for my $bottom (sort { $a <=> $b } keys %{$charbottoms}) {
		print $bottom,' ',$charbottoms->{$bottom},"\n";
	}

#######

	ELEMENT: for my $element_id (sort keys %$index) {
    	if ( $element_id =~ m/^line/ ) {
    	    my $line = $index->{$element_id};

    	    #unless (line_has_chars($line)) {
    	    #    next ELEMENT;
    	    #}
    		my @points;

    		for my $charbox (@$charboxes) {

    			if ( $charbox->{'bbox'}->{'top'} >= $line->{'bbox'}->{'top'}
    				&& $charbox->{'bbox'}->{'top'} <= $line->{'bbox'}->{'bottom'}
    			) {
    	    		my $x = $charbox->{'bbox'}->{'left'};
    	    		my $y = $charbox->{'bbox'}->{'bottom'};
    				push @points, "$x,$y";
    			}
    		}
    		my $poly_points = join(' ', @points);

    		print STDERR $element_id, ' $poly_points: ',$poly_points,"\n";

    		$ocr_draw->draw_polyline($box_image, $poly_points, 'blue', 1, 'none') if (1);

    		last ELEMENT;
		}
    }
}

$box_image->Write($boxoutfile);
$box_gt_image->Write($boxgtfile);
#exit;
##############

sub font_init {
    my ($font_metrics, $font_chars) = @_;

    for my $metric (qw(bottom top aspect)) {
    	for my $group ( @{$font_metrics->{$metric}} ) {
    		my $value = $group->[0];
    		for my $char ( split(/ /, $group->[1]) ) {
    		    $font_chars->{$char}->{$metric} = $value;
    		}
    	}
    }
}

sub line_has_chars {
    my ($line_element) = @_;

    my $line_text = '';

    #print Dumper($line_element);
    #exit;

    for my $child (@{$line_element->{'children'}}) {
        if ($child->{'id'} =~ 'word') {
            $line_text .= $child->{'text'};
        }
    }
    $line_text =~ s/\s+//g;
    return $line_text;
}

# https://legacy.imagemagick.org/discourse-server/viewtopic.php?t=17170
# https://legacy.imagemagick.org/Usage/draw/
# convert logo: -fill none -stroke black -strokewidth 3 -draw "rectangle 10,10 630,470" logo_rect.png

# https://imagemagick.org/script/perl-magick.php

# $p = $image->[1];
# $p->Draw(stroke=>'red', primitive=>'rectangle', points=>20,20 100,100');
# $q = $p->Montage();
# undef $image;
# $q->Write('x.miff');

##############
=pod

# time tesseract block_isis.png block_isis -l GT4Hist2M --psm 7 txt makebox hocr; cat block_isis.txt
Failed to load any lstm-specific dictionaries for lang GT4Hist2M!!
Tesseract Open Source OCR Engine v5.0.0-alpha-773-gd33ed with Leptonica
Warning: Invalid resolution 0 dpi. Using 70 instead.

real	0m0.202s
user	0m0.173s
sys	0m0.021s
J ſis.

=cut

#######################

=pod

sub similarity {
    my ($feature,$object1,$object2) = @_;

    if ($feature eq 'fingerprint') {
        return $img_bits->fp_similarity($object1->{'fingerprint'},$object2->{'fingerprint'});
    }
    else {
        return $img_bits->fp_similarity($object1->{$feature},$object2->{$feature});
    }
}

=cut


# red    #ffb3b3;
# orange #ffd9b4; 60%
# yellow #ffffB4; 70%
# green  #B4ffB4; 80%

# <td style="background-color: ;"


#################################
sub min { ($_[0] < $_[1]) ? $_[0] : $_[1]; }
sub max { ($_[0] > $_[1]) ? $_[0] : $_[1]; }

