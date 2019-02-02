#!/usr/bin/perl -w

use Tk;
use Tk::Text;
use Tk::ROText;
use Tk::Frame;
use Tk::Label;
use Tk::Entry;
use Tk::JPEG;
#use Tk::Bitmap;
#use Tk::TIFF;
#use Tk::PNG;

@track_color = qw/red green blue pink yellow/;
$balsize = 5;
$time_interval = '30 sec';

$main = MainWindow->new(-title=>'cellSpeed - (C) matteo.ramazzotti@unifi.it 2018');

$f1 = $main->Frame->pack(-side=>'top', -fill=>'x');
$f2 = $main->Frame->pack(-side=>'top', -fill=>'x');
$f3 = $main->Frame->pack(-side=>'top', -fill=>'x');
#$f4 = $main->Frame->pack(-side=>'top', -fill=>'x');

$f2->Button(-text=>'Show paths', -command=>\&create_paths)->pack(-side=>'left');
$f2->Label(-text=>'Time interval')->pack(-side=>'left');
$f2->Entry(-width=>8, -textvariable=>\$time_interval)->pack(-side=>'left');
$f2->Button(-text=>'Compute speed', -command=>\&create_speed)->pack(-side=>'left');
$f2->Button(-text=>'Load', -command=>\&open_image)->pack(-side=>'right');
$f2->Button(-text=>'Save project', -command=>\&save_project)->pack(-side=>'right');
$f3->Label(-textvariable=>\$status)->pack(-side=>'left');
$f3->Label(-textvariable=>\$position)->pack(-side=>'right');

$main->bind( '<Prior>' => \&prev_image );
$main->bind( '<Up>'    => \&prev_image );
$main->bind( '<Left>'  => \&prev_image );
$main->bind( '<Next>'  => \&next_image );
$main->bind( '<Down>'  => \&next_image );
$main->bind( '<Right>' => \&next_image );
$main->bind( '<space>' => \&next_image );

$main->bind( '<KeyRelease-h>' => \&show_man );
$main->bind( '<KeyRelease-f>' => \&show_files );
$main->bind( '<KeyPress-Control_L>' => sub {$mode = 'del'});
$main->bind( '<KeyRelease-Control_L>' => sub {$mode = 'add'});
$main->bind( '<KeyPress-Control_R>' => sub {$mode = 'del'});
$main->bind( '<KeyRelease-Control_R>' => sub {$mode = 'add'});

$main->resizable('0','0');
$main->focus;

&open_image;

MainLoop;

sub initialize {
	%track_num = ();
	%X = ();
	%Y = ();
	$INDEX = 0;
	$status = '';
	$cursor = '';
	$startup = 1;
	$mode = 'add';
}

sub save_project {
	$file = $main->getSaveFile();
	return if (!$file);
	open(OUT,">$file");
	foreach $f (0..$#FILES) {
		print OUT $FILES[$f];
		foreach $t (0..$track_num{$INDEX}-1) {
			print OUT "\t",$t,",",$X{$t."@".$f},",",$Y{$t."@".$f} if ($X{$t."@".$f});
			print OUT "\t$t,X,X" if (!$X{$t."@".$f});
		}
		print OUT "\n";
	}
	close OUT;
}

sub load_project {
	my $pfile = shift;
	if (!$pfile) {
		$pfile = $main->getOpenFile();
		$pfile = @$pfile[0];
	}
	open(IN,$pfile);
	$cnt = -1;
	while($line = <IN>) {
		next if ($line =~ /^#/);
		chomp $line;
		$cnt++;
		@tmp = split (/\t/,$line);
		$FILES[$cnt] = shift @tmp;
		foreach $val (@tmp) {
			@tmp1 = split (/,/,$val);
#			print "$cnt:",join " ", @tmp1,"\n";
			next if ($tmp1[1] eq 'X');
			$X{$tmp1[0]."@".$cnt} = $tmp1[1];
			$Y{$tmp1[0]."@".$cnt} = $tmp1[2];
			$track_num{$cnt} = scalar @tmp;
		}
	}
	close IN;
	print STDERR "PROJECT NAME: $pfile\n";
	print STDERR "TOTAL IMAGES: ",scalar @FILES,"\n";
	print STDERR "TOTAL TRACKS: ",scalar @tmp,"\n";
	print STDERR "TOTAL POINTS: ",scalar keys %X,"\n";
	foreach my $f (0..$#FILES) {
		@tmp = split (/\//,$FILES[$f]);
		$fname[$f] = pop @tmp;
	}
	$startup = 0;
	show_image($INDEX);
} 

sub open_image {
	$files = $main->getOpenFile(-multiple=>1);
	return if (!$files);
	&initialize;
	@FILES = @$files;
	$project = 0;
	if ($FILES[0] =~ /\.cs$/) {
		my $pfile = $FILES[0];
		@FILES = ();
		$project = 1;
		load_project($pfile);
		return;
	}
	foreach my $f (0..$#FILES) {
		@tmp = split (/\//,$FILES[$f]);
		$fname[$f] = pop @tmp;
		$track_num{$f} = 0;
	}
	show_image($INDEX);
	$startup = 0;
}
sub next_image {
	my $tmp = $INDEX;
	$tmp++;
	return if ($tmp > $#FILES);
	$INDEX++;
	show_image($INDEX);
}
sub prev_image {
	my $tmp = $INDEX;
	$tmp--;
	return if ($tmp < 0);
	$INDEX--;
	show_image($INDEX);
}
sub show_image {
	my $ind = shift;
	my $file = $FILES[$ind];
	$file =~ /\.(\w\w\w)$/;
	my $format = lc($1);
	$format = 'jpeg' if ($format eq 'jpg');
	$format = 'tiff' if ($format eq 'tif');
	$file =~ /\/.+?$/;
	$fname = $1;
	my $image = $main->Photo(-'format'=>$format, -'file' => $file);
	my $imwidth = $image->width;
	my $imheight = $image->height;
	$canvas->packForget if ($canvas);
	$canvas = $f1->Canvas(-width=>$imwidth, -height=>$imheight, -cursor=>'crosshair')->pack(-side=>'left');
	$canvas->createImage(0,0, -image => $image, -anchor=>'nw');
	$canvas->CanvasBind("<Motion>", [\&follow, Ev('x'), Ev('y')]);
	$canvas->CanvasBind('<ButtonPress-1>', [\&track_add, Ev('x'), Ev('y')]);
	$canvas->CanvasBind('<Control-ButtonPress-1>', [\&track_del, Ev('x'), Ev('y')]);
	&update_track if (!$startup);
	$status = "Showing image ".($INDEX+1).": $fname[$INDEX]";
}

sub	update_track {
#	print "#FILES:\n",join "\n#",@FILES,"\n\n"; 
#	print STDERR "\nINDEX: $INDEX, trackpoints: $track_num{$INDEX}\n";
	return if ($track_num{$INDEX} == 0);
	foreach my $p (0..$track_num{$INDEX}-1) {
		next if (!$X{$p."@".$INDEX});
		my $x = $X{$p."@".$INDEX};
		my $y = $Y{$p."@".$INDEX};
		$canvas->createOval($x+$balsize,$y+$balsize,$x-$balsize,$y-$balsize, -fill => $track_color[$p], -tags=>'trackpoint'.$p);
#		print "Track point $p at $x, $y for image $INDEX\n"
	}
}

sub create_paths {
	foreach $a (0..$track_num{$INDEX}-1) {
		my @path = ();
		foreach $b (0..$#FILES) {
#			print STDERR "#Track $a: X ", $X{$a."@".$b}," - Y ",$Y{$a."@".$b},"\n";
			next if (!$X{$a."@".$b});
			push(@path,($X{$a."@".$b},$Y{$a."@".$b}));
		}
#		print STDERR join " ", @path,"\n";
		$canvas->createLine(@path, -fill => $track_color[$a], arrow=>'last');
	}
}

sub create_speed {
	$speed_out = '';
	foreach $a (0..$track_num{$INDEX}-1) {
		my @path = ();
		($time,$unit) = split (/ /,$time_interval);
		$speed_out .= " -- SPEED TEST FOR TRACK ".($a+1)." -- \nSTEP\tDIST\tTIME\tSPEED\n";
		my $dist_tot = 0;
		my $time_tot = 0;
		my $speed_tot = 0;
		my @speed = ();
		my $speed_sd = 0;
		my @valid = ();
		foreach my $f (0..$#FILES) {
			#this allow missing trackpoints in images.
#			print "$f: ",$X{$a."@".$f},"\n";
			push(@valid,$f) if ($X{$a."@".$f});
		}
		foreach $b (0..$#valid) {
			$c = $valid[$b]; # current value
			$o = $valid[$b-1]; # previous value
			if ($b > 0) {
				#print STDERR "abs(",$X{$a."@".$b},"-",$X{$a."@".($b-1)},") / abs(",$Y{$a."@".$b},"-",$Y{$a."@".($b-1)},")\n";
				$dist = sqrt((($X{$a."@".$c}-$X{$a."@".$o}))**2 + (($Y{$a."@".$c}-$Y{$a."@".$o}))**2);
				$timec = $time*($c-$o);
				$speed = $dist / $timec; # in cases where a trackpoint is missing in one image, the delta time must be changed 
				$speed_out .= "$b\t".sprintf("%.3f",$dist)."\t".sprintf("%.3f",$timec)."\t".sprintf("%.3f",$speed)."\n";
				$dist_tot += $dist;
				$time_tot += $timec;
				$speed_tot += $speed;
				push(@speed,$speed);
			}
		}
		$speed = $speed_tot/($#FILES-1);
		my $delta = 0;
		foreach $s (@speed) {
			$delta += ($s-$speed)**2;
		}
		$speed_sd = sqrt($delta/($#FILES-2)) if ($#FILES > 3);
		$speed_sd = sqrt($delta/($#FILES-1)) if ($#FILES <= 2);
		$speed_sd = sqrt($delta/$#FILES) if ($#FILES <= 1);
		$speed_out .= "TOTAL DIST:\t$dist_tot (px)\nTOTAL TIME:\t$time_tot ($unit)\nAVG SPEED:\t$speed +- $speed_sd (px/$unit)\n\n";
	}
	$main = MainWindow->new(-title=>'cellSpeed - (C) matteo.ramazzotti@unifi.it 2014');
	$text = $main->Scrolled('Text', -width=>70, height=>50, -scrollbars => 'osoe')->pack( -expand => 1, -fill => 'both', );
	$text->Contents($speed_out);
}

sub follow {
	($c,$x,$y) = @_;
	$position = "($x,$y)";
	my $color;
	$c->delete('follow');
	if ($mode eq 'add') {
		$curtrack = cur_track();
		$color = $track_color[$curtrack];
		$cursor = "Add track ".($curtrack+1)." in image ".($INDEX+1);
	}
	if ($mode eq 'del') {
		$c->addtag('torem','closest', $x, $y);
		my @tags = $c->gettags("torem");
		$trackid = $tags[0];
		$c->dtag($trackid,'torem');
		if ($trackid =~ /trackpoint/) {
			$trackid =~ s/trackpoint//;
			$curtrack = $trackid;
			$color = $track_color[$curtrack];
			$cursor = "Delete track $curtrack from image ".($INDEX+1);
		} else {
			$color = 'white';
			$cursor = "Delete track --- from image ".($INDEX+1);
		}
	}
	$c->createText($x+10,$y+10,-text=>$cursor, -fill=>$color, -anchor=>'w', -tags=>'follow');
#	print "INDEX $INDEX has $track_num{$INDEX} tracks\n"; 
}

sub track_del {
	($c,$x,$y) = @_;
	$c->addtag('remove','closest', $x, $y);
	my @tags = $c->gettags("remove");
	$trackid = $tags[0];
#	print join " ", @tags,"\n",$trackid," -> ";
	$trackid =~ s/trackpoint//;
#	print $trackid, "\n";
	delete $X{$trackid."@".$INDEX};
	delete $Y{$trackid."@".$INDEX};
	$canvas->delete('remove');
	$status = "Track ".($track_num{$INDEX}+1)." in image ".($INDEX+1)." created";
}

sub track_add {
	($c,$x,$y) = @_;
	$curtrack = cur_track();
	$c->createOval($x+$balsize,$y+$balsize,$x-$balsize,$y-$balsize, -fill => $track_color[$curtrack], -tags=>'trackpoint'.$curtrack);
	$status = "Track ".($curtrack+1)." in image ".($INDEX+1)." created.";
	$X{$curtrack."@".$INDEX} = $x;
	$Y{$curtrack."@".$INDEX} = $y;
	$track_num{$INDEX}++ if ($curtrack > $track_num{$INDEX});
}

sub cur_track {
	foreach my $t (0..1000) {
		return $t if (!$X{$t."@".$INDEX});
	}
}

sub show_man {

$man = <<EOM;
cellSpeed commands:

- Left arrow  : next image
- Spacebar    : next image
- Right arrow : previous image

- Mouse click : add track point (see cursor label)
- Ctrl + Mouse click : delete track point

- The "Show paths" button displays connections between all track points.
- The "Compute speed" button performs the speed test.

- Time interval is the time separating each image (that must be equally spaced)
EOM
;

	$main = MainWindow->new(-title=>'cellSpeed - (C) matteo.ramazzotti@unifi.it 2014');
	$text = $main->Scrolled('ROText', -width=>100, height=>14, -scrollbars => 'osoe')->pack( -expand => 1, -fill => 'both', );
	$text->Contents($man);
}

sub show_files {

$man = <<EOT;
cellSpeed available images:

EOT
;

	$main = MainWindow->new(-title=>'cellSpeed - (C) matteo.ramazzotti@unifi.it 2014');
	$text = $main->Scrolled('ROText', -width=>100, height=>14, -scrollbars => 'osoe')->pack( -expand => 1, -fill => 'both', );
	$text->Contents(join "\n",@FILES);
}

