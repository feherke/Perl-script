#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Image::Magick;

print "AstroCal FontSample   version 0.0   january 2012   written by Feherke\n";
print "graphical astrological calendar generator\n";
print "font sample generator utility\n";

### >>> hardcoded setting >>>

my $labelsize=10;

### <<<

my %sample=(
  'fox'=>['The quick brown fox jumps over the lazy dog'],
  'digit'=>['0123456789'],
  'astro'=>['astrological signs','☉ ☽☾○● ☿♀♁♂♃♄♅♆♇ ♈♉♊♋♌♍♎♏♐♑♒♓ ☌☍△□✱ ↑↓⤉⤈ ⚸'],
  'arrow'=>['cut arrows','⤉⤈⤒⤓'],
# UTF astrological sign characters generated with the following code :
# recode html..utf8 <<< '&#x2609; &#x263d;&#x263e;&#x25cb;&#x25cf; &#x263f;&#x2640;&#x2641;&#x2642;&#x2643;&#x2644;&#x2645;&#x2646;&#x2647; &#x2648;&#x2649;&#x264a;&#x264b;&#x264c;&#x264d;&#x264e;&#x264f;&#x2650;&#x2651;&#x2652;&#x2653; &#x260c;&#x260d;&#x25b3;&#x25a1;&#x2731; &#x2191;&#x2193&#x2909;&#x2908'
);

my $samplesize=24;
my $output='';
my $text='';
my $list=0;
my $ttf=0;
exit 1 unless GetOptions(
  'list'=>\$list,
  'ttf'=>\$ttf,
  'size=i'=>\$samplesize,
  'output=s'=>\$output,
  'version'=>sub { exit },
  'help|?'=>sub { pod2usage(1); exit },
  '<>'=>sub { $text.=($text?' ':'').$_[0] }
);

if ($list) {
  print "built-in sample texts :\n";
  foreach my $one (sort keys %sample) { print " - $one ( $sample{$one}[0] )\n" }
  exit;
}

if ($samplesize<-5 || $samplesize>50) {
  print "ERROR : invalid font size '$samplesize' ( keep it between 5 and 50 )\n";
  exit 1;
}

if ($text && exists $sample{$text}) {
  $output="astrocal-fontsample-$text.png" unless $output;
  $text=pop @{$sample{$text}};
}

$output='astrocal-fontsample.png' unless $output;

my $image=Image::Magick->new;
$image->Read('xc:white');

print 'loading font list... ';

my @fontlist;
if ($ttf) {
  open PRO,'-|',"locate -r '\.ttf\$'" or die $!;
  chomp (@fontlist=<PRO>);
  close PRO;
} else {
  @fontlist=$image->QueryFont();
}

unless (@fontlist) {
  print "ERROR : no font found\n";
  exit 1;
}

print "Ok ( $#fontlist )\n";

print 'measuring fonts... ';

my $width=0;
my $height=0;
foreach my $one (@fontlist) {
  my ($x,$y,$a,$d,$w,$h,$m)=$image->QueryFontMetrics(
    font=>'',
    pointsize=>$labelsize,
    text=>$one
  );
  $width=$w if $width<$w;
  $height+=$h;

  ($x,$y,$a,$d,$w,$h,$m)=$image->QueryFontMetrics(
    font=>$one,
    pointsize=>$samplesize,
    text=>$text||$one
  );
  $width=$w if $width<$w;
  $height+=$h;
}

undef $image;

print "Ok\n";

print 'generating image... ';

$image=Image::Magick->new(
  size=>"$width x $height"
);
$image->Read('xc:white');

my $pos=0;
foreach my $one (@fontlist) {

  $image->Annotate(
    x=>0,
    y=>$pos,
    gravity=>'NorthWest',
    font=>'',
    pointsize=>$labelsize,
    text=>$one
  );

  my ($x,$y,$a,$d,$w,$h,$m)=$image->QueryFontMetrics(
    font=>'',
    pointsize=>$labelsize,
    text=>$one
  );
  $pos+=$h;

  $image->Annotate(
    x=>0,
    y=>$pos,
    gravity=>'NorthWest',
    font=>$one,
    pointsize=>$samplesize,
    text=>$text||$one
  );

  ($x,$y,$a,$d,$w,$h,$m)=$image->QueryFontMetrics(
    font=>$one,
    pointsize=>$samplesize,
    text=>$text||$one
  );
  $pos+=$h;
}

print "Ok\n";

print 'saving image... ';

my $err=$image->Write(
  filename=>$output
);

if ($err=~m/\b420\b/) {
  $image->Write(
    filename=>"png:$output"
  );
}

print "Ok ( $output )\n";

#$image->Display();

undef $image;

=head1 NAME

astrocal-fontsample.pl - Font sample image generator.

=head1 SYNOPSIS

astrocal-fontsample.pl [B<-l>] [B<-t>] [B<-s> I<size>] [B<-o> I<file>] [I<sample>|I<text>]

=head1 DESCRIPTION

Just a simple utility of AstroCal, its only reason is to help answering a question :
"what font should I specify in the configuration file" ?

This utility creates an image, where outputs a sample text with each TrueType font found on the machine.

=head1 OPTIONS

=over 4

=item B<-l>

=item B<--list>

Prints the list of built-in sample texts.

=item B<-t>

=item B<--ttf>

Locate .ttf font files on the disk instead of using the internal list of known fonts.

=item B<-s> I<size>

=item B<--size>=I<size>

Sample font size to use. ( 24 )

=item B<-o> I<file>

=item B<--output>=I<file>

Generated output image file name. ( astrocal-fontsample-{SAMPLE}.png )

=item I<sample>

One of the available built-in sample text names.

=item I<text>

User defined text to print on the image. ( the paths themselves )

=back

=head1 SEE ALSO

locate(1)

=cut
