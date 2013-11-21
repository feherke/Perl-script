#!/usr/bin/perl

use 5.010;
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use File::Basename;
use File::Path;
use Time::Piece;
use Time::Seconds;

use Image::Magick;

use inifile;

use Dumpvalue;

print "AstroCal   version 0.0   january 2012   written by Feherke\n";
print "graphical astrological calendar generator\n";

my $dump=Dumpvalue->new;

sub error($$)
{
  my $exit=scalar @_>1?shift:1;
  print "ERROR : @_\n";
  exit $exit
}

sub expand($%)
{
  my $temp=shift;
  my $data=shift;

  my %data=ref($data) eq 'HASH'?%{$data}:();

  $temp=~s/\{(.+?)\}/$data{$1} if exists $data{$1}/ge;

  $temp
}

sub id($)
{
  my $t=shift;
  $t=~s/ //g;
  lc $t
}

sub AnnotateFit($%)
{
  my $image=shift;
  my %param=@_;
  my %fit=(width=>$param{sizeto}~~[qw{width both}],height=>$param{sizeto}~~[qw{height both}]);

    $param{pointsize}=100 unless exists $param{pointsize};
    my ($x_ppem,$y_ppem,$ascender,$descender,$width,$height,$max_advance)=$image->QueryFontMetrics(%param);

  if (($param{width} && $fit{width}) || ($param{height} && $fit{height})) {

#    $width=$param{width}?$param{pointsize}*$param{width}/$width:1000;
#    $height=$param{height}?$param{pointsize}*$param{height}/$height:1000;

    my $bywidth=$fit{width}?$param{pointsize}*$param{width}/$width:1000;
    my $byheight=$fit{height}?$param{pointsize}*$param{height}/$height:1000;
    $param{pointsize}=$bywidth<$byheight?$bywidth:$byheight;
  }

  if ($param{snapto}=~m/center/) {
    $param{x}=$param{x}+($param{width}-$width)/2;
  } elsif ($param{snapto}=~m/right/) {
    $param{x}=$param{x}+$param{width}-$width;
  }

  if ($param{snapto}=~m/middle/) {
    $param{y}=$param{y}+($param{height}-$height)/2;
  } elsif ($param{snapto}=~m/bottom/) {
    $param{y}=$param{y}+$param{height}-$height;
  }

  $image->Draw(
    primitive=>'rectangle',
    stroke=>'purple',
    fill=>'orchid',
    points=>"$param{x},$param{y} ${ \( $param{x}+($param{width} || 0) ) },${ \( $param{y}+($param{height} || 0) ) }"
  );

  $param{undercolor}='#3333666699996666';

  $image->Annotate(%param);
}

my $conf='';
my $lang='';
my $date='';
&error('incorrect syntax') unless GetOptions(
  'config|ini=s'=>\$conf,
  'language=s'=>\$lang,
  'version'=>sub { exit },
  'help|?'=>sub { pod2usage(1); exit },
  '<>'=>sub { $date.=($date?'-':'').$_[0] }
);

if ($date) {
  my ($year,$month);
  if ($date=~m/^(?:(\d{4})[-\/:.])?(\d{1,2})$/) {
    ($year,$month)=($1,$2);
  } elsif ($date=~m/^(\d{1,2})[-\/:.](\d{4})$/) {
    ($year,$month)=($2,$1);
  } else {
    &error("date $date not recognised");
  }
  $year=(localtime)[5]+1900 unless $year;
  if ($month<1 || $month>12) {
    &error("month $month in date $date is incorrect");
  }
  $date=sprintf '%04d-%02d',$year,$month;
} else {
  my $time=localtime;
  $date=sprintf '%04d-%02d',$time->[5]+1900,$time->[4]+1;
}
$date=Time::Piece->strptime("$date-01 12",'%Y-%m-%d %H');

my @date=($date-.5*ONE_MONTH,$date,$date+1.5*ONE_MONTH);

my ($APPFILE,$APPDIR,$APPEXT)=fileparse $0,qw{.pl};
$APPDIR=~s,/$,,;

$conf="$APPDIR/$APPFILE.ini" unless $conf;

my %conf=(
  image=>{
    width=>1400,
    height=>1000,
    density=>72,
  },
  file=>{
    output=>'cal-{YEAR}-{MONTH}.png',
    cache=>'{APPDIR}/cache/{TYPE}-{YEAR}-{MONTH}.txt',
    shift=>'{APPDIR}/astrocal-shift.txt',
    language=>'{APPDIR}/astrolog-lang-{LANG}.ini',
  },
  astrolog=>{
    path=>'/opt/bin/astrolog',
    data=>'{HOME}/.astrolog/astrolog.dat',
  },
  general=>{
    weekstart=>0,
  },
  layout=>{
    titleheight=>100,
    timeline=>'50%',
    timesize=>10,
  },
  font=>{
    month=>'LucidaTypewriter bold italic 72',
    week=>'georgia italic 32',
    day=>'luxi bold italic 175',
    hour=>'verdana.ttf 14',
    sign=>'DejaVuLGCSansCondensed 18',
    moon=>'DejaVuLGCSansCondensed 28',
    tale=>'DejaVuSerifCondensed 20',
    about=>'Vera 12',
  },
  color=>{
    back=>'white',
    month=>'gray silver',
    week=>'black',
    week0=>'red',
    week6=>'maroon',
    tale=>'black',
    day=>'gray silver',
    void=>'green',
    full=>'orange',
  },
  align=>{
    month=>'right',
    week=>'bottom',
    day=>'Middle Right',
  },
  restrict=>{
    object=>'Lilith',
    relation=>'',
  }
);

my %lang=(
  name=>{
    month=>'January February March April May June July August September October November December',
    week=>'Sunday Monday Tuesday Wednesday Thursday Friday Saturday',
  },
  phase=>{
    halfmoon=>'Half Moon',
    firstquarter=>'First Quarter',
    lastquarter=>'Last Quarter',
    fullmoon=>'Full Moon',
    newmoon=>'New Moon',
    vernalequinox=>'Vernal Equinox',
    summersolstice=>'Summer Solstice',
    autumnalequinox=>'Autumnal Equinox',
    wintersolstice=>'Winter Solstice',
  },
  format=>{
    date=>'{MONTH} {YEAR}',
    moonin=>'{MOON} in {SIGN}',
  },
  about=>{
    about=>"Based on Walter D. Pullen's calculations\nusing the Astrolog 5.40 program\nDrawn by Perl script\nwith the ImageMagick library's help",
  }
);

my @shift;

# work

print 'loading configuration... ';

unless (-f $conf) {
  print "WARNING : file $conf not found\n";
  print 'creating file with default configuration... ';

  &error("writing $conf failed") if &inifile::writeini($conf,\%conf,'AstroCal','configuration file created with default settings');

  print "Ok ( $conf )\n";
  print "Edit the newly created file as needed, then run me again.\n";
  exit 2;
}

&error("reading $conf failed") if &inifile::readini($conf,\%conf);

print "Ok ( $conf )\n";

print 'processing configuration [';

print '.'; # file section
$conf{file}{language}=&expand($conf{file}{language},{HOME=>$ENV{HOME},APPDIR=>$APPDIR,LANG=>$lang});
$conf{file}{shift}=&expand($conf{file}{shift},{HOME=>$ENV{HOME},APPDIR=>$APPDIR});
$conf{file}{output}=&expand($conf{file}{output},{HOME=>$ENV{HOME},APPDIR=>$APPDIR,YEAR=>$date->year,MONTH=>$date->strftime('%m'),LANG=>$lang});

$conf{file}{cache}.='{TYPE}' if index($conf{file}{cache},'{TYPE}')==-1;
%{$conf{file}{cache_file}}=();
foreach my $type ('aspect','riseset') {
  @{$conf{file}{cache_file}}{$type}=();
  foreach my $i (0..2) {
    $conf{file}{cache_file}{$type}[$i]=&expand($conf{file}{cache},{HOME=>$ENV{HOME},APPDIR=>$APPDIR,YEAR=>$date[$i]->year,MONTH=>$date[$i]->strftime('%m'),TYPE=>$type});
    next if -f $conf{file}{cache_file}{$type}[$i];

    my $path=dirname $conf{file}{cache_file}{$type}[$i];
    unless (-e $path) {
      &error("creating path $path failed") unless File::Path::make_path $path,{error=>my $null};
    }
  }
}

print '.'; # astrolog section
$conf{astrolog}{path}=&expand($conf{astrolog}{path},{HOME=>$ENV{HOME},APPDIR=>$APPDIR});
$conf{astrolog}{data}=&expand($conf{astrolog}{data},{HOME=>$ENV{HOME},APPDIR=>$APPDIR,ASTRODIR=>$conf{astrolog}{path}});

print '.'; # general section
$conf{general}{weekstart}=0 unless $conf{general}{weekstart}~~[0..6];

print '.'; # layout section
foreach my $one (keys %{$conf{layout}}) {
  my %layout=(offset=>0,unit=>'',value=>0);
  my $layout=delete $conf{layout}{$one};
  if ($layout=~m/^(\d+)(%)?$/) {
    $layout{offset}=$1;
    $layout{unit}=$2 || '';
  } else {
    # warn ?
  }
  %{$conf{layout}{$one}}=%layout;
}

print '.'; # font section
foreach my $one (keys %{$conf{font}}) {
  my %font=(name=>'',size=>12,bold=>100,italic=>'Normal');
  foreach my $font (split /\s+/,delete $conf{font}{$one}) {
    if (lc $font eq 'bold') {
      $font{bold}=551;
    } elsif (lc $font eq 'italic') {
      $font{italic}='italic';
    } elsif ($font=~/^(?:\d*\.)?\d+$/) {
      $font{size}=$font;
    } else {
      $font{name}=$font;
    }
  }
  %{$conf{font}{$one}}=%font;
}

print '.'; # color section
foreach my $one (keys %{$conf{color}}) {
  my %color=(color=>'black',border=>'');
  my @color=split /\s+/,delete $conf{color}{$one};
  $color{color}=$color[0] if scalar @color>=1;
#  $color{border}=scalar @color==2?$color[1]:$color{color};
  $color{border}=$color[1] if scalar @color>=2;
  %{$conf{color}{$one}}=%color;
}

print '.'; # align section
foreach my $one (keys %{$conf{align}}) {
  my %align=(horiz=>'left',vert=>'top',hoffset=>0,voffset=>0,hunit=>'',vunit=>'');
  foreach my $align (split /\s+/,delete $conf{align}{$one}) {
    $align=lc $align;
    if ($align=~m/^(left|center|right)(?:([+-]\d+)(%)?)?$/i) {
      $align{horiz}=$1;
      $align{hoffset}=$2 || 0;
      $align{hunit}=$3;
    } elsif ($align=~m/^(top|middle|bottom)(?:([+-]\d+)(%)?)?$/i) {
      $align{vert}=$1;
      $align{voffset}=$2 || 0;
      $align{vunit}=$3;
    } else {
      # warn ?
    }
  }
  %{$conf{align}{$one}}=%align;
}

print '.'; # restrict section
{
  my $tmp=delete $conf{restrict}{object};
  @{$conf{restrict}{object}}=split /\s+/,$tmp;
  $tmp=delete $conf{restrict}{aspect};
  @{$conf{restrict}{aspect}}=split /\s+/,$tmp;
}

print "] Ok\n";

#$dump->dumpValue(\%conf);

print 'loading language... ';

if ($lang) {

  unless (-f $conf{file}{language}) {
    print "WARNING : file $conf{file}{language} not found\n";
    print 'creating file with default configuration... ';

    &error("writing $conf{file}{language} failed") if &inifile::writeini($conf{file}{language},\%lang,'AstroCal','language file created with default settings');

    print "Ok ( $conf{file}{language} )\n";
    print "Edit the newly created file as needed, then run me again.\n";
    exit 2;
  }

  &error("reading $conf{file}{language} failed") if &inifile::readini($conf{file}{language},\%lang);

  print "Ok ( $conf{file}{language} )\n";

} else {
  print "skipped ( not specified )\n";
}

print 'processing language [';

print '.'; # name section
foreach my $one (keys %{$lang{name}}) {
  my @name=split /\s+/,delete $lang{name}{$one};
  @{$lang{name}{$one}}=@name;
}

print '.'; # about section
$lang{about}{about}=~s/\\n/\n/g;

print "] Ok\n";

print 'loading daytime saving... ';

if (-f $conf{file}{shift}) {

  open FIL,'<',$conf{file}{shift} or &error("reading $conf{file}{shift} failed");
  while (my $str=<FIL>) {
    chomp $str;
    next if ! $str || substr($str,0,1) eq '#';
    next unless $str=~m/^(?:(.*) )?[-\/:](?: (.*))?/;
    my $from=Time::Piece->strptime($1,'%Y-%m-%d %H:%M:%S') if $1;
    my $to=Time::Piece->strptime($2,'%Y-%m-%d %H:%M:%S') if $2;
    push @shift,[$from,$to];
  }
  close FIL;

  print "Ok ( $conf{file}{shift} ) \n";

} else {

  print "WARNING : file $conf{file}{shift} not found\n";

}

print 'generating data [';

foreach my $type ('aspect','riseset') {
  foreach my $i (0..2) {
    if (-f $conf{file}{cache_file}{$type}[$i]) {
      print '-';
      next;
    }

    my $command='';
    if ($type eq 'aspect') {
      $command="( cd $conf{astrolog}{path}; ./astrolog ${ \( $conf{astrolog}{data}?'-i '.$conf{astrolog}{data}:'' ) } -YQ 0 -qm ${ \$date[$i]->mon } ${ \$date[$i]->year } -dm ) >> $conf{file}{cache_file}{aspect}[$i]";
    } else {
      $command="( cd $conf{astrolog}{path}; for ((i=1;i<=${ \$date[$i]->month_last_day };i++)); do ./astrolog ${ \( $conf{astrolog}{data}?'-i '.$conf{astrolog}{data}:'' ) } -YQ 0 -qd ${ \$date[$i]->mon } \$i ${ \$date[$i]->year } -Zd -YRZ 0 1 0 1; done ) >> $conf{file}{cache_file}{riseset}[$i]";
#      $command="( cd $conf{astrolog}{path}; for ((i=1;i<=${ \$date[$i]->month_last_day };i++)); do ./astrolog ${ \( $conf{astrolog}{data}?'-i '.$conf{astrolog}{data}:'' ) } -YQ 0 -qd ${ \$date[$i]->mon } \$i ${ \$date[$i]->year } -Zd; done ) >> $conf{file}{cache_file}{riseset}[$i]";
    }
    &error("generating $type data in $conf{file}{cache_file}{$type}[$i] failed") if system $command;

    print '.';
  }

}

print "] Ok\n";

print 'loading data [';

my @aspect;
my @riseset;
for my $type ('aspect','riseset') {
  foreach my $i (0..2) {
    open FIL,'<',$conf{file}{cache_file}{$type}[$i] or &error("reading $conf{file}{cache_file}{$type}[$i] failed");
    if ($type eq 'aspect') {
      push @aspect,<FIL>;
    } else {
      push @riseset,<FIL>;
    }
    close FIL;

    print '.';
  }
}
chomp @aspect;
chomp @riseset;

print "] Ok\n";

#$dump->dumpValue(\@aspect);
#$dump->dumpValue(\@riseset);

print "processing data... ";

my @above; # moon aspect
my @below; # other planet aspect
my @blah; # bottom text information
my @full; # full moon's black period
my @void; # void of course moon period
my @moonin; # moon house per day
my $moonphase=''; # previous moon phase - to sort half moon in first quarter and last quarter
my %prevmoon; # previous moon major aspect == void moon period start
my %previn; # previous moon enter - to fill up stationary days
foreach my $one (@aspect) {

  my %match;
  my $type;
  if ($one=~m!^\([[:alpha:]]{3}\) +(?<day>[[:digit:]]{1,2})- ?(?<month>[[:digit:]]{1,2})-(?<year>[[:digit:]]{4}) +(?<hour>[[:digit:]]{1,2}):(?<minute>[[:digit:]]{2}) +(?<object>[[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] (?<status>[[:alpha:]]{3}) [(\[<][[:alpha:]]{3}[)\]>] (?<object2>[[:alpha:]]{3,7})(?: \((?<detail>(?:New|Half|Full) Moon)\))?$!) {
    $type=1;
# OLD   1          2  3  4             5         6     7
#       0  1  2    3  4  5             6         7     8
#       da mo year ho mi object        status  object2 detail
#       __ __ ____ __ __ _______       ___       _____ ________
# (Mon)  1-11-2010 10:44    Moon (Vir) Squ (Sag) Mars
# (Mon)  1-11-2010 11:40    Moon (Vir) Sex [Sco] Venus
# (Mon)  1-11-2010 15:45   Venus [Sco] Sex (Cap) Pluto
# (Sat)  6-11-2010  6:51     Sun (Sco) Con (Sco) Moon (New Moon)
  } elsif ($one=~m!^\([[:alpha:]]{3}\) +(?<day>[[:digit:]]{1,2})- ?(?<month>[[:digit:]]{1,2})-(?<year>[[:digit:]]{4}) +(?<hour>[[:digit:]]{1,2}):(?<minute>[[:digit:]]{2}) +(?<object>[[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] (?<status>-->) (?<stella>[[:alpha:]]{3,11})(?: \((?<detail>(?:Vernal|Summer|Autumnal|Winter) (?:Equinox|Solstice))\))?$!) {
    $type=2;
# OLD   1          2  3  4             5   6          7
#       0  1  2    3  4  5             6   7          8
#       da mo year ho mi object     status stella     detail
#       __ __ ____ __ __ _______       ___ _________  _______________
# (Mon)  1-11-2010  5:51    Moon (Leo) --> Virgo
# (Mon)  8-11-2010  5:08   Venus [Sco] --> Libra
# (Wed) 22-12-2010  1:38     Sun (Sag) --> Capricorn (Winter Solstice)
  } elsif ($one=~m!^\([[:alpha:]]{3}\) +(?<day>[[:digit:]]{1,2})- ?(?<month>[[:digit:]]{1,2})-(?<year>[[:digit:]]{4}) +(?<hour>[[:digit:]]{1,2}):(?<minute>[[:digit:]]{2}) +(?<object>[[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] (?<status>S/[RD])$!) {
    $type=3;
# OLD   1          2  3  4             5
#       0  1  2    3  4  5             6
#       da mo year ho mi object        status
#       __ __ ____ __ __ _______       ___
# (Sat)  6-11-2010 16:49 Neptune (Aqu) S/D
# (Fri) 10-12-2010  1:58 Mercury [Cap] S/R
# (Wed) 29-12-2010 22:01 Mercury <Sag> S/D
  } else {
    next;
  }
  %match=%+;

  next if $type==1 && ($match{object}~~@{$conf{restrict}{object}} || $match{object2}~~@{$conf{restrict}{object}});
  next if $type==1 && $match{status}~~@{$conf{restrict}{aspect}};

  my $odate=Time::Piece->strptime("$match{year}-$match{month}-$match{day} $match{hour}:$match{minute}",'%Y-%m-%d %H:%M');
  foreach my $pair (@shift) {
    if ((!${$pair}[0] || $odate>=${$pair}[0]) && (!${$pair}[1] || $odate<${$pair}[1])) {
      $odate+=ONE_HOUR;
      $match{year}=$odate->year;
      $match{month}=$odate->mon;
      $match{day}=$odate->mday;
      $match{hour}=$odate->hour;
      last;
    }
  }

# moon phase : new first full last

  if ($type==1) { # (*)
    if ($match{object} eq 'Moon' || $match{object2} eq 'Moon') { # Moon
      push @above,[$match{year},$match{month},$match{day},$match{hour},$match{minute},$match{object},$match{status},$match{object2}];
      if ($match{detail}) {
        $match{detail}=$moonphase eq 'New Moon'?'First Quarter':'Last Quarter' if $match{detail} eq 'Half Moon';
        $moonphase=$match{detail};
        push @blah,[$match{month},$match{day},$match{hour},$match{minute},$match{detail},$moonphase] if $match{detail} && $match{month}==$date->mon;

        if ($match{detail} eq 'Full Moon') {

          my $full=Time::Piece->strptime("$match{year}-$match{month}-$match{day} $match{hour}:$match{minute}",'%Y-%m-%d %H:%M');
          my $fullstart=$full-18*ONE_HOUR;
          my $fullend=$full+18*ONE_HOUR;

          push @above,[$fullstart->year,$fullstart->mon,$fullstart->mday,$fullstart->hour,$fullstart->min,'Moon','start','dark'];
          push @above,[$fullend->year,$fullend->mon,$fullend->mday,$fullend->hour,$fullend->min,'Moon','end','dark'];

          if ($fullstart->mon==$fullend->mon && $fullstart->mday==$fullend->mday) {
            push @full,[$fullstart->year,$fullstart->mon,$fullstart->mday,$fullstart->hour,$fullstart->min,$fullend->hour,$fullend->min];
          } else {
            push @full,[$fullstart->year,$fullstart->mon,$fullstart->mday,$fullstart->hour,$fullstart->min,23,59];
            for ($fullstart+=ONE_DAY;$fullstart->date lt $fullend->date;$fullstart+=ONE_DAY) {
              push @full,[$fullstart->year,$fullstart->mon,$fullstart->mday,0,0,23,59];
            }
            push @full,[$fullend->year,$fullend->mon,$fullend->mday,0,0,$fullend->hour,$fullend->min];
          }

        }
      }

      %prevmoon=%match if $match{status}~~[qw{Con Sex Squ Opp Tri}] && ($match{object}~~[qw{Sun Mercury Venus Mars Jupiter Saturn Uranus Neptune Pluto}] || $match{object2}~~[qw{Sun Mercury Venus Mars Jupiter Saturn Uranus Neptune Pluto}]);
    } else { # not Moon
      push @below,[$match{year},$match{month},$match{day},$match{hour},$match{minute},$match{object},$match{status},$match{object2}];
    }
=pod
      if ($match[4]=='Moon' || $match[6]=='Moon') {
//        $moon[$match[1]][]=array($match[2],$match[3],$match[4],$match[5],$match[6]);
        if ($match[7]) {
          $blah[]=array($match[1],$match[2],$match[3],$match[7]);
          if ($match[7]=='Full Moon') {
            $fullstart=explode(' ',date('n j G i',strtotime("$year-$month-$match[1] $match[2]:$match[3] -18 hour"))); // n month, j day, G hour, i minute
            $fullend=explode(' ',date('n j G i',strtotime("$year-$month-$match[1] $match[2]:$match[3] +18 hour")));
            if ($fullstart[0]==$month) $moon[$fullstart[1]][]=array($fullstart[2],$fullstart[3],'Moon','start','dark'); else $fullstart=array($month,1,0,0);
            if ($fullend[0]==$month) $moon[$fullend[1]][]=array($fullend[2],$fullend[3],'Moon','end','dark'); else $fullend=array($month,$countday,23,59);
            if ($fullstart[0]==$fullend[0] && $fullstart[1]==$fullend[1]) {
              $full[$fullstart[1]][]=array($fullstart[2],$fullstart[3],$fullend[2],$fullend[3]);
            } else {
              $full[$fullstart[1]][]=array($fullstart[2],$fullstart[3],23,59);
              for ($i=$fullstart[1]+1;$i<$fullend[1];$i++) $full[$i][]=array(0,0,23,59);
              $full[$fullend[1]][]=array(0,0,$fullend[2],$fullend[3]);
            }
          }
        }
        if (in_array($match[5],array('Con','Sex','Squ','Tri','Opp'))) $last=$match;
      } else $plan[$match[1]][]=array($match[2],$match[3],$match[4],$match[5],$match[6]);
=cut
  } elsif ($type==2) { # -->
    if ($match{object} eq 'Moon') {
      push @above,[$match{year},$match{month},$match{day},$match{hour},$match{minute},$match{object},'enter',$match{stella}];

      if (%previn) {
        my $moonstart=Time::Piece->strptime("$previn{year}-$previn{month}-$previn{day} $previn{hour}:$previn{minute}",'%Y-%m-%d %H:%M');
        for ($moonstart+=ONE_DAY,my $moonend=sprintf('%04d-%02d-%02d',$match{year},$match{month},$match{day});$moonstart->date lt $moonend;$moonstart+=ONE_DAY) {
          push @moonin,[$moonstart->year,$moonstart->mon,$moonstart->mday,0,0,'Moon','in',$previn{stella}];
        }
      }
      push @moonin,[$match{year},$match{month},$match{day},$match{hour},$match{minute},$match{object},'enter',$match{stella}];
      %previn=%match;

      if (%prevmoon) {

        my $voidstart=Time::Piece->strptime("$prevmoon{year}-$prevmoon{month}-$prevmoon{day} $prevmoon{hour}:$prevmoon{minute}",'%Y-%m-%d %H:%M');

        if ($voidstart->mon==$match{month} && $voidstart->mday==$match{day}) {
          push @void,[$match{year},$match{month},$match{day},$voidstart->hour,$voidstart->min,$match{hour},$match{minute}];
        } else {
          push @void,[$voidstart->year,$voidstart->mon,$voidstart->mday,$voidstart->hour,$voidstart->min,23,59];
          for ($voidstart+=ONE_DAY,my $voidend=sprintf('%04d-%02d-%02d',$match{year},$match{month},$match{day});$voidstart->date lt $voidend;$voidstart+=ONE_DAY) {
            push @void,[$voidstart->year,$voidstart->mon,$voidstart->mday,0,0,23,59];
          }
          push @void,[$match{year},$match{month},$match{day},0,0,$match{hour},$match{minute}];
        }

      }
    } else {
      push @below,[$match{year},$match{month},$match{day},$match{hour},$match{minute},$match{object},'enter',$match{stella}];
    }
    push @blah,[$match{month},$match{day},$match{hour},$match{minute},$match{detail}] if $match{detail} && $match{month}==$date->mon;
=pod if Moon
        $moonin[$match[1]][]=array($match[2],$match[3],$match[4],'enter',$match[6]);
        if ($last) {
          $moon[$last[1]][]=array($last[2],$last[3],$last[4],$last[5],$last[6]);
          $moon[$match[1]][]=array($match[2],$match[3],$match[4],'enter',$match[6]);
          if ($match[1]==$last[1]) {
            $void[$match[1]][]=array($last[2],$last[3],$match[2],$match[3]);
          } else {
            $void[$last[1]][]=array($last[2],$last[3],23,59);
            for ($i=$last[1]+1;$i<$match[1];$i++) $void[$i][]=array(0,0,23,59);
            $void[$match[1]][]=array(0,0,$match[2],$match[3]);
          }
        }
=cut
  } elsif ($type==3) { # R/D

    push @below,[$match{year},$match{month},$match{day},$match{hour},$match{minute},$match{object},'enter',substr $match{status},-1];

  }

}

=pod
$last=NULL;
for ($i=1;$i<=$countday;$i++) {
  if (!$moonin[$i] && $last) $moonin[$i][]=$last;
  else {
    $last=$moonin[$i][0];
    $last[3]='in';
  }
}
=cut

my @horizon;
foreach my $one (@riseset) {

  my %match;
  if ($one=~m!^\([[:alpha:]]{3}\) +(?<day>[[:digit:]]{1,2})- ?(?<month>[[:digit:]]{1,2})-(?<year>[[:digit:]]{4}) +(?<hour>[[:digit:]]{1,2}):(?<minute>[[:digit:]]{2}) +(?<object>[[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] (?<status>[[:alpha:]]{3,7}) +at +[[:digit:]]{1,3}: *[[:digit:]]{1,2}' \([[:digit:]]\.[[:digit:]]{2}[ns] [[:digit:]]\.[[:digit:]]{2}[ew]\)$!) { # '
# OLD    1         2  3  4             5
#       da mo year ho mi object        status
#       __ __ ____ __ __ _______       _______
# (Thu)  1- 1-2009  8:15     Sun (Cap) rises   at 325:22' (0.69s 1.00e)
# (Thu)  1- 1-2009 16:43     Sun (Cap) sets    at 214:34' (0.69s 1.00w)
  } else {
    next;
  }

  %match=%+;

  push @horizon,[$match{year},$match{month},$match{day},$match{hour},$match{minute},$match{object},$match{status}];

}

print "Ok\n";

#$dump->dumpValue(\@plan);
#$dump->dumpValue(\@blah);
#$dump->dumpValue(\@moonin);
#$dump->dumpValue(\@horizon);

print 'drawing... ',"\n";

my %char=(
  Sun=>'☉',Moon=>'☽',Crescent=>'☽',Decrescent=>'☾',Half=>'☾',Full=>'○',New=>'●',
  Mercury=>'☿',Venus=>'♀',Mars=>'♂',Jupiter=>'♃',Saturn=>'♄',Uranus=>'♅',Neptune=>'♆',Pluto=>'♇',Node=>'☊',Lilith=>'⚸',
  Aries=>'♈',Taurus=>'♉',Gemini=>'♊',Cancer=>'♋',Leo=>'♌',Virgo=>'♍',Libra=>'♎',Scorpio=>'♏',Sagittarius=>'♐',Capricorn=>'♑',Aquarius=>'♒',Pisces=>'♓',
  Conjunction=>'☌',Opposition=>'☍',Trine=>'△',Square=>'□',Sextile=>'✱',
  enter=>'➔',rises=>'↑',sets=>'↓',dark=>'☹',start=>'☞',end=>'☜',
#  rises=>'⤉',sets=>'⤈',zeniths=>'⤒',nadirs=>'⤓', # new & better arrows, but less supported in fonts
  D=>'D',R=>'R',in=>'∊',
);

foreach my $one (keys %char) { $char{substr $one,0,3}=$char{$one} if length $one>3 }

#$dump->dumpValue(\%char);

=pod
Draw 	
  primitive=>{point, line, rectangle, arc, ellipse, circle, path, polyline, polygon, bezier, color, matte, text, @filename}, 
  points=>string , 
  method=>{Point, Replace, Floodfill, FillToBorder, Reset}, 
  stroke=>color name, 
  fill=>color name, 
  font=>string, 
  pointsize=>integer, 
  strokewidth=>float, 
  antialias=>{true, false}, 
  bordercolor=>color name, 
  x=>float, 
  y=>float, 
  dash-offset=>float, 
  dash-pattern=>array of float values, 
  affine=>array of float values, 
  translate=>float, float, 
  scale=>float, float, 
  rotate=>float, 
  skewX=>float, 
  skewY=>float, 
  interpolate=>{undefined, average, bicubic, bilinear, mesh, nearest-neighbor, spline}, 
  kerning=>float, 
  text=>string, 
  vector-graphics=>string, 
  interline-spacing=>double, 
  interword-spacing=>double, 
  direction=>{right-to-left, left-to-right}

Annotate 	
  text=>string, 
  font=>string, 
  family=>string, 
  style=>{Normal, Italic, Oblique, Any}, 
  stretch=>{Normal, UltraCondensed, ExtraCondensed, Condensed, SemiCondensed, SemiExpanded, Expanded, ExtraExpanded, UltraExpanded}, 
  weight=>integer, "Valid Range 100-900. I found that any value 551 and above would give me bold." skmanji at manji dot org on php.net
  pointsize=>integer, 
  density=>geometry, 
  stroke=>color name, 
  strokewidth=>integer, 
  fill=>color name, 
  undercolor=>color name, 
  kerning=>float, 
  geometry=>geometry, 
  gravity=>{NorthWest, North, NorthEast, West, Center, East, SouthWest, South, SouthEast}, 
  antialias=>{true, false}, 
  x=>integer, 
  y=>integer, 
  affine=>array of float values, 
  translate=>float, float, 
  scale=>float, float, 
  rotate=>float, 
  skewX=>float, 
  skewY=> float, 
  align=>{Left, Center, Right}, 
  encoding=>{UTF-8}, 
  interline-spacing=>double, 
  interword-spacing=>double, 
  direction=>{right-to-left, left-to-right}
=cut

#__END__

my $image=Image::Magick->new(size=>"$conf{image}{width}x$conf{image}{height}",gravity=>'NorthWest');
$image->Set(density=>"$conf{image}{density}x$conf{image}{density}") if $conf{image}{density};
$image->Read("xc:$conf{color}{back}{color}");

$conf{layout}{titleheight}{value}=$conf{layout}{titleheight}{offset}*($conf{layout}{titleheight}{unit} eq '%'?$conf{image}{height}/100:1);

my %cell=(
  width=>($conf{image}{width}-1)/7,
  height=>($conf{image}{height}-$conf{layout}{titleheight}{value}-1)/6
);

$conf{layout}{timeline}{value}=$conf{layout}{timeline}{offset}*($conf{layout}{timeline}{unit} eq '%'?$cell{height}/100:1);
$conf{layout}{timesize}{value}=$conf{layout}{timesize}{offset}*($conf{layout}{timesize}{unit} eq '%'?$cell{height}/100:1);

foreach my $i (0..7) {
  $image->Draw( # grid vertical line
    primitive=>'line',
    stroke=>$conf{color}{line}{color},
    points=>"${ \( $i*$cell{width} ) },$conf{layout}{titleheight}{value} ${ \( $i*$cell{width} )},${ \( $conf{image}{height}-($i==4||$i==6?$cell{height}:0) ) }"
  );
}

foreach my $i (0..6) {
  $image->Draw( # grid horizontal line
    primitive=>'line',
    stroke=>$conf{color}{line}{color},
    points=>"0,${ \( $i*$cell{height}+$conf{layout}{titleheight}{value} ) } $conf{image}{width},${ \( $i*$cell{height}+$conf{layout}{titleheight}{value} ) }"
  );
}

my %size;
{
  my %sample=(
    month=>&expand($lang{format}{date},{YEAR=>$date->year,MONTH=>$lang{name}{month}[$date->_mon]}),
    week=>$lang{name}{week},
    day=>[1..31],
    sign=>[values %char],
    hour=>[0..9],
    moon=>[$char{Moon},$char{enter},$char{in}],
    tale=>join('',@blah), # FIXME : not @blah's values, but @blah's subarray's values
    tale_digit=>[0..60],
    about=>[split /\n/,$lang{about}{about}]
  );
  foreach my $one (keys %sample) {
    my $font=$one;
    $font=~s/_.+//;
    my @size=$image->QueryFontMetrics(
      font=>$conf{font}{$font}{name},
      pointsize=>$conf{font}{$font}{size},
      weight=>$conf{font}{$font}{bold},
      style=>$conf{font}{$font}{italic},
      text=>ref $sample{$one} eq 'ARRAY'?join '',@{$sample{$one}}:$sample{$one}
    );
    %{$size{$one}}=(width=>$size[4],height=>$size[5]);
    if (ref $sample{$one} eq 'ARRAY') {
      @size=$image->QueryMultilineFontMetrics(
        font=>$conf{font}{$font}{name},
        pointsize=>$conf{font}{$font}{size},
        weight=>$conf{font}{$font}{bold},
        style=>$conf{font}{$font}{italic},
        text=>join "\n",@{$sample{$one}}
      );
      $size{$one}{width}=$size[4];
    }
  }
}

#$dump->dumpValue(\%size);
#$dump->dumpValue(\%conf);

# title
&AnnotateBox(
  $image,
  x=>0,
  y=>0,
  width=>$conf{image}{width},
  height=>$conf{layout}{titleheight}{value},
  conf=>'month',
  text=>&expand($lang{format}{date},{YEAR=>$date->year,MONTH=>$lang{name}{month}[$date->_mon]})
);

#$conf{general}{weekstart}=0; # DEBUG

# week days ( column headings )
for my $i (0..6) {
  my $ii=($i+$conf{general}{weekstart})%7;
  &AnnotateBox(
    $image,
    x=>$i*$cell{width},
    y=>0,
    width=>$cell{width},
    height=>$conf{layout}{titleheight}{value},
    conf=>'week',
    fill=>$conf{color}{'week'.($ii==0||$ii==6?$ii:'')}{color},
    stroke=>$conf{color}{'week'.($ii==0||$ii==6?$ii:'')}{border},
    text=>$lang{name}{week}[$ii]
  );
}

my $basecell=($date->_wday-$conf{general}{weekstart})%7;

# days ( cell number )
my $nr=0;
my $month='';
my $themonth=0;
foreach my $day (
  $date[0]->strftime('%Y-%m-'),$date[0]->month_last_day-$basecell+1..$date[0]->month_last_day,
  $date[1]->strftime('%Y-%m-'),1..$date[1]->month_last_day,
  $date[2]->strftime('%Y-%m-'),1..10
) {

  if (substr($day,-1) eq '-') {
    $month=$day;
    $themonth=$month eq $date[1]->strftime('%Y-%m-');
    next;
  }

  my $dayx=($nr%7)*$cell{width};
  my $dayy=int ($nr/7)*$cell{height}+$conf{layout}{titleheight}{value};

  &AnnotateBox(
    $image,
    x=>$dayx,
    y=>$dayy,
    width=>$cell{width},
    height=>$cell{height},
    conf=>$themonth?'day':'dayother',
    text=>$day
  );

  last if ++$nr==38;
}

# timeline
foreach my $i (0..5) {
  $image->Draw( # time line
    primitive=>'line',
    stroke=>$conf{color}{time}{color},
    fill=>$conf{color}{time}{border},
    points=>"0,${ \( $i*$cell{height}+$conf{layout}{titleheight}{value}+$conf{layout}{timeline}{value}-$conf{layout}{timesize}{value}/2 ) } ${ \( $conf{image}{width}-($i==5?$cell{width}*4:0) ) },${ \( $i*$cell{height}+$conf{layout}{titleheight}{value}+$conf{layout}{timeline}{value}-$conf{layout}{timesize}{value}/2 ) }"
  );
  $image->Draw( # time line
    primitive=>'line',
    stroke=>$conf{color}{time}{color},
    fill=>$conf{color}{time}{border},
    points=>"0,${ \( $i*$cell{height}+$conf{layout}{titleheight}{value}+$conf{layout}{timeline}{value}+$conf{layout}{timesize}{value}/2 ) } ${ \( $conf{image}{width}-($i==5?$cell{width}*4:0) ) },${ \( $i*$cell{height}+$conf{layout}{titleheight}{value}+$conf{layout}{timeline}{value}+$conf{layout}{timesize}{value}/2 ) }"
  );
}

$nr=0;
$month='';
foreach my $day (
  $date[0]->strftime('%Y-%m-'),$date[0]->month_last_day-$basecell+1..$date[0]->month_last_day,
  $date[1]->strftime('%Y-%m-'),1..$date[1]->month_last_day,
  $date[2]->strftime('%Y-%m-'),1..10
) {

  if (substr($day,-1) eq '-') {
    $month=$day;
    next;
  }

  my $dayx=($nr%7)*$cell{width};
  my $dayy=int ($nr/7)*$cell{height}+$conf{layout}{titleheight}{value};

  my @part=split /-/,"$month$day";

  my @thisday=grep { ${$_}[0]==$part[0] && ${$_}[1]==$part[1] && ${$_}[2]==$part[2] } @moonin;

  $image->Annotate(
    x=>$dayx+$size{moon}{width}*1.5,
    y=>$dayy+$size{moon}{height}/3+$size{moon}{height}/2,
    font=>$conf{font}{moon}{name},
    pointsize=>$conf{font}{moon}{size},
    weight=>$conf{font}{moon}{bold},
    style=>$conf{font}{moon}{italic},
    align=>'Center',
    text=>$char{$thisday[0][5]}.$char{$thisday[0][6]}.$char{$thisday[0][7]}
  );

  @thisday=grep { ${$_}[0]==$part[0] && ${$_}[1]==$part[1] && ${$_}[2]==$part[2] } @void;

  foreach my $one (@thisday) {

    my $startdot=(${$one}[3]*60+${$one}[4])*$cell{width}/(24*60);
    my $enddot=(${$one}[5]*60+${$one}[6])*$cell{width}/(24*60);

    $image->Draw(
      primitive=>'rectangle',
      fill=>$conf{color}{void}{color},
      points=>"${ \( $dayx+$startdot ) },${ \( $dayy+$conf{layout}{timeline}{value}-$conf{layout}{timesize}{value}/2+1 ) } ${ \( $dayx+$enddot ) },${ \( $dayy+$conf{layout}{timeline}{value}+$conf{layout}{timesize}{value}/2-1 ) }"
    );

  }

  @thisday=grep { ${$_}[0]==$part[0] && ${$_}[1]==$part[1] && ${$_}[2]==$part[2] } @full;

  foreach my $one (@thisday) {

    my $startdot=(${$one}[3]*60+${$one}[4])*$cell{width}/(24*60);
    my $enddot=(${$one}[5]*60+${$one}[6])*$cell{width}/(24*60);

    $image->Draw(
      primitive=>'rectangle',
      fill=>$conf{color}{full}{color},
      points=>"${ \( $dayx+$startdot ) },${ \( $dayy+$conf{layout}{timeline}{value}-$conf{layout}{timesize}{value}/2+1 ) } ${ \( $dayx+$enddot ) },${ \( $dayy+$conf{layout}{timeline}{value} ) }"
    );

  }

  @thisday=grep { ${$_}[0]==$part[0] && ${$_}[1]==$part[1] && ${$_}[2]==$part[2]  } @above;
print "ABOVE ${ \( scalar @thisday ) } > 8 on $month$day !\n" if scalar @thisday>8;

#  push @thisday,[0,0,0,2,2,'Sun','Con','Sun'] if scalar @thisday<8;
#  push @thisday,[0,0,0,4,4,'Sun','Con','Sun'] if scalar @thisday<8;
#  push @thisday,[0,0,0,8,8,'Sun','Con','Sun'] if scalar @thisday<8;
#  push @thisday,[0,0,0,11,11,'Sun','Con','Sun'] if scalar @thisday<8;
#  push @thisday,[0,0,0,13,13,'Sun','Con','Sun'] if scalar @thisday<8;
#  push @thisday,[0,0,0,16,16,'Sun','Con','Sun'] if scalar @thisday<8;
#  push @thisday,[0,0,0,18,18,'Sun','Con','Sun'] if scalar @thisday<8;
#  push @thisday,[0,0,0,21,21,'Sun','Con','Sun'] if scalar @thisday<8;
  @thisday=sort { ${$a}[3]*60+${$a}[4]<=>${$b}[3]*60+${$b}[4] } @thisday;
  my $thisnr=0;
  foreach my $one (@thisday) {

# 0   1   2   3
# |   |   |   |

# 0 1 2 3 4 5 6 7
# | . | . | . | .

    my $timedot=(${$one}[3]*60+${$one}[4])*$cell{width}/(24*60);
    my $timetext=$cell{width}/(scalar(@thisday)+1)*($thisnr+++1);

#    439     $hourx=hourpos($data[0],$data[1]);
#    440     $textx=$cell[width]/4.5*$i/2+$cell[width]/9;
#    441     $texty=$cell[height]/4;
#    442     $textx=$cell[width]/count($set)*$i+$cell[width]/(count($set)*2);

#    my $textx=$cell{width}/4.5*$thisnr++/2+$cell{width}/9;
#    my $texty=$cell{height}/4;
#    my $textx=$cell{width}/scalar(@thisday)*$thisnr+++$cell{width}/(scalar(@thisday)*2);

    $image->Draw(
      primitive=>'ellipse',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value} ) } 1.5,1.5 0,360"
    );
    $image->Draw(
      primitive=>'line',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value} ) } ${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value}-5 ) }"
    );

    $image->Draw(
      primitive=>'line',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value}-5 ) } ${ \( $dayx+$timetext ) },${ \( $dayy+$conf{layout}{timeline}{value}-15-3 ) }"
    );
    $image->Draw(
      primitive=>'line',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timetext ) },${ \( $dayy+$conf{layout}{timeline}{value}-15-3 ) } ${ \( $dayx+$timetext ) },${ \( $dayy+$conf{layout}{timeline}{value}-20-$thisnr%2*($size{hour}{height}+$size{sign}{height}) ) }"
    );

    $image->Annotate(
      x=>$dayx+$timetext,
      y=>$dayy+$conf{layout}{timeline}{value}+$size{hour}{height}/3-20-$size{hour}{height}/2-$thisnr%2*($size{hour}{height}+$size{sign}{height}),
      font=>$conf{font}{hour}{name},
      pointsize=>$conf{font}{hour}{size},
      weight=>$conf{font}{hour}{bold},
      style=>$conf{font}{hour}{italic},
      align=>'Center',
      text=>sprintf '%2d:%02d',${$one}[3],${$one}[4]
    );

    $image->Annotate(
      x=>$dayx+$timetext,
      y=>$dayy+$conf{layout}{timeline}{value}+$size{sign}{height}/3-20-$size{hour}{height}-$size{sign}{height}/2-$thisnr%2*($size{hour}{height}+$size{sign}{height}),
      font=>$conf{font}{sign}{name},
      pointsize=>$conf{font}{sign}{size},
      weight=>$conf{font}{sign}{bold},
      style=>$conf{font}{sign}{italic},
      align=>'Center',
      text=>$char{${$one}[5]}.$char{${$one}[6]}.$char{${$one}[7]}
    );

  }

  @thisday=grep { ${$_}[0]==$part[0] && ${$_}[1]==$part[1] && ${$_}[2]==$part[2]  } @below;
print "BELOW ${ \( scalar @thisday ) } > 4 on $month$day !\n" if scalar @thisday>4;

#  push @thisday,[0,0,0,5,5,'Sun','Con','Sun'] if scalar @thisday<4;
#  push @thisday,[0,0,0,10,10,'Sun','Con','Sun'] if scalar @thisday<4;
#  push @thisday,[0,0,0,15,15,'Sun','Con','Sun'] if scalar @thisday<4;
#  push @thisday,[0,0,0,20,20,'Sun','Con','Sun'] if scalar @thisday<4;
#  @thisday=sort { ${$a}[3]*60+${$a}[4]<=>${$b}[3]*60+${$b}[4] } @thisday;
  $thisnr=0;
  foreach my $one (@thisday) {

    my $timedot=(${$one}[3]*60+${$one}[4])*$cell{width}/(24*60);
    my $timetext=$cell{width}/scalar(@thisday)*($thisnr+++.5);

    $image->Draw(
      primitive=>'ellipse',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value} ) } 1.5,1.5 0,360"
    );
    $image->Draw(
      primitive=>'line',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value} ) } ${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value}+5 ) }"
    );

    $image->Draw(
      primitive=>'line',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timedot ) },${ \( $dayy+$conf{layout}{timeline}{value}+5 ) } ${ \( $dayx+$timetext ) },${ \( $dayy+$conf{layout}{timeline}{value}+15+3 ) }"
    );
    $image->Draw(
      primitive=>'line',
      stroke=>$conf{color}{junction}{color},
      points=>"${ \( $dayx+$timetext ) },${ \( $dayy+$conf{layout}{timeline}{value}+15+3 ) } ${ \( $dayx+$timetext ) },${ \( $dayy+$conf{layout}{timeline}{value}+20 ) }"
    );

    $image->Annotate(
      x=>$dayx+$timetext,
      y=>$dayy+$conf{layout}{timeline}{value}+$size{hour}{height}/3+20+$size{hour}{height}/2,
      font=>$conf{font}{hour}{name},
      pointsize=>$conf{font}{hour}{size},
      weight=>$conf{font}{hour}{bold},
      style=>$conf{font}{hour}{italic},
      align=>'Center',
      text=>sprintf '%2d:%02d',${$one}[3],${$one}[4]
    );

    $image->Annotate(
      x=>$dayx+$timetext,
      y=>$dayy+$conf{layout}{timeline}{value}+$size{sign}{height}/3+20+$size{hour}{height}+$size{sign}{height}/2,
      font=>$conf{font}{sign}{name},
      pointsize=>$conf{font}{sign}{size},
      weight=>$conf{font}{sign}{bold},
      style=>$conf{font}{sign}{italic},
      align=>'Center',
      text=>$char{${$one}[5]}.$char{${$one}[6]}.$char{${$one}[7]}
    );

  }

  @thisday=grep { ${$_}[0]==$part[0] && ${$_}[1]==$part[1] && ${$_}[2]==$part[2] && (${$_}[5] eq 'Sun' || ${$_}[5] eq 'Moon') } @horizon; # FIXME: use $conf, not 'Sun'

  $thisnr=0;
  foreach my $one (@thisday) {

    my $timetext=$cell{width}-(scalar(@thisday)-$thisnr++-.5)*$size{sign}{width}*2.5;

    $image->Annotate(
      x=>$dayx+$timetext,
      y=>$dayy+$size{hour}{height}/3+$size{sign}{height}/2+$size{hour}{height},
      font=>$conf{font}{hour}{name},
      pointsize=>$conf{font}{hour}{size},
      weight=>$conf{font}{hour}{bold},
      style=>$conf{font}{hour}{italic},
      align=>'Center',
      text=>sprintf '%2d:%02d',${$one}[3],${$one}[4]
    );

    $image->Annotate(
      x=>$dayx+$timetext,
      y=>$dayy+$size{sign}{height}/3+$size{sign}{height}/2,
      font=>$conf{font}{sign}{name},
      pointsize=>$conf{font}{sign}{size},
      weight=>$conf{font}{sign}{bold},
      style=>$conf{font}{sign}{italic},
      align=>'Center',
      text=>$char{${$one}[5]}.$char{${$one}[6]}
    );

  }




  last if ++$nr==38;
}

#$date=Time::Piece->strptime("$date-01 12",'%Y-%m-%d %H');

#my $prevmoon='';
#for (my $one=$date[0];$one<$date[2];$one+=ONE_DAY) {
#  print $one->strftime,"\n";

#grep

#  $image->Annotate(
#    x=>$ont
#  );

#}

#$dump->dumpValue(\@above);
#$dump->dumpValue(\$date);
#$dump->dumpValue(\@date);

=pod
function daypos($day)
{
  global $cell,$firstday;
  return array(
    (($day-1+$firstday)%7)*$cell[width]+$cell[left],
    floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]
  );
}

function hourpos($hour,$minute)
{
  global $cell;
  return ($hour*60+$minute)*$cell[width]/1440;
}

for ($i=1;$i<=$countday;$i++) {
  list($dayx,$dayy)=daypos($i);
  $image->annotateImage($draw[day],$dayx+$cell[width]-5,$dayy+$cell[height]-10,0,$i);
}
=cut

#%{$conf{align}{tale}}=(horiz=>'right',vert=>'top',hoffset=>0,voffset=>0,hunit=>'',vunit=>'');

sub AnnotateBox($%)
{
  my $image=shift;
  my %param=@_;

  if ($param{conf}) {
    $param{font}=$conf{font}{$param{conf}}{name} unless exists $param{font};
    $param{pointsize}=$conf{font}{$param{conf}}{size} unless exists $param{pointsize};
    $param{weight}=$conf{font}{$param{conf}}{bold} unless exists $param{weight};
    $param{style}=$conf{font}{$param{conf}}{italic} unless exists $param{style};
    $param{fill}=$conf{color}{$param{conf}}{color} unless exists $param{fill};
    $param{stroke}=$conf{color}{$param{conf}}{border} unless exists $param{stroke};
    delete $param{stroke} unless $param{stroke};
    if (exists $conf{align}{$param{conf}}) {
      foreach my $one (keys %{$conf{align}{$param{conf}}}) {
        $param{$one}=$conf{align}{$param{conf}}{$one} unless exists $param{$one};
      }
    }
  }

  $param{debug} and
  $image->Draw(
    primitive=>'rectangle',
    stroke=>'red',
    fill=>'transparent',
    points=>"${ \( $param{x}+3 ) },${ \( $param{y}+3 ) } ${ \( $param{x}+$param{width}-3 ) },${ \( $param{y}+$param{height}-3 ) }"
  );

  if (($param{horiz} && $param{width}) || ($param{vert} && $param{height})) {
    my ($twidth,$theight)=(0,0);
    ($twidth,$theight)=@{[$image->QueryMultilineFontMetrics(%param)]}[4,5] if $param{horiz}~~[qw{center right}] || $param{vert}~~[qw{middle bottom}];

    if ($param{horiz}) {
      $param{x}=$param{horiz} eq 'left'?$param{x}:$param{horiz} eq 'right'?$param{x}+$param{width}-$twidth:$param{x}+($param{width}-$twidth)/2;
      $param{x}+=$param{hunit}?$param{width}*$param{hoffset}/100:$param{hoffset} if $param{hoffset};
    }
    if ($param{vert}) {
      $param{y}=$param{vert} eq 'top'?$param{y}:$param{vert} eq 'bottom'?$param{y}+$param{height}-$theight:$param{y}+($param{height}-$theight)/2;
      $param{y}+=$param{vunit}?$param{height}*$param{voffset}/100:$param{voffset} if $param{voffset};
    }
  }

  $image->Annotate(%param);
}


# textual information at the bottom
for (my $i=0;$i<@blah;$i++) {
  &AnnotateBox(
    $image,
    x=>$cell{width}*3+5,
    y=>$cell{height}*5+$conf{layout}{titleheight}{value}+$i*$size{tale}{height}+5,
    width=>$size{tale_digit}{width},
    height=>$cell{height},
    conf=>'tale',
    horiz=>'right',
    text=>$blah[$i][1]
  );
  &AnnotateBox(
    $image,
    x=>$cell{width}*3+$size{tale_digit}{width}*2+5,
    y=>$cell{height}*5+$conf{layout}{titleheight}{value}+$i*$size{tale}{height}+5,
    width=>$size{tale_digit}{width},
    height=>$cell{height},
    conf=>'tale',
    horiz=>'right',
    text=>$blah[$i][2]
  );
  &AnnotateBox(
    $image,
    x=>$cell{width}*3+$size{tale_digit}{width}*3+5,
    y=>$cell{height}*5+$conf{layout}{titleheight}{value}+$i*$size{tale}{height}+5,
    width=>$size{tale_digit}{width},
    height=>$cell{height},
    conf=>'tale',
    text=>":$blah[$i][3]  $lang{phase}{&id($blah[$i][4])}"
  );
}

&AnnotateBox(
  $image,
  x=>$cell{width}*5,
  y=>$cell{height}*5+$conf{layout}{titleheight}{value},
  width=>$cell{width}*2,
  height=>$cell{height},
  conf=>'about',
  text=>$lang{about}{about}
);

#$dump->dumpValue(\@blah);
#$dump->dumpValue(\%conf);

print "Ok\n";

print 'writing image... ';

$image->Write(filename=>$conf{file}{output});

print "Ok ( $conf{file}{output} )\n";

$image->AdaptiveResize(width=>1020,height=>725);
#$image->Display();

undef $image;

__END__











































=head1 NAME

B<astrocal.pl> - Graphical astrological calendar generator.

=head1 SYNOPSIS

B<astrocal.pl> [B<-c> I<file>] [B<-l> I<lang>] [I<date>]

=head1 DESCRIPTION

Generates an image with the calendar for a given month.

The

=head1 OPTIONS

=over 4

=item B<-c> I<file>

=item B<--config>=I<file>

Configuration file to load. It is an .ini file, its default name is F<astrocal.ini>. ( See L</astrocal.ini> below. )

=item B<-l> I<file>

=item B<--language>=I<file>

Language file to load. It is an .ini file, its default name is F<astrocal-lang-{LANG}.ini>. ( See L</astrocal-lang.ini> below. )

=item I<date>

Actually just the month part of the date for which to generate the calendar. Can be either in I<year>B<->I<month> or I<month>B<->I<year> order, separated by B<->, B</>,
B<:>, B<.> or space. The I<year> is optional and defaults to current year. The I<year> must be specified on 4 digits, the I<month> can have 1 or 2 digits. If I<date> is
not specified, the current month is used.

=back

=head1 CONFIGURATION

=head2 astrocal-lang.ini

  .

=head2 astrocal.ini

  .

=head2 astrocal-shift.txt

  2011-03-27T03:00:00+00:00 - 2011-10-30T03:00:00+00:00

=head1 PREREQUISITE

=head2 Perl

http://perl.org/

At least version 5.10 is needed.

=head2 Image::Magick

http://imagemagick.org/script/perl-magick.php

=head2 Astrolog

http://www.astrolog.org/astrolog.htm

Astrolog is written by Walter D. Pullen. It is the strongest program I ever met.

This version was developed for and tested with Astrolog version 5.40.

Probably you will never find an Astrolog version incompatible with AstroCal, but anyway, here are the required features :

=over 4

=item general

  -i <file>: Compute chart based on info in file.
  -YQ <rows>: Pause text scrolling after a page full has printed.

=item aspect

  -qm <month> <year>: Compute chart for first of month.
  -d [<step>]: Print all aspects and changes occurring in a day.
  -dm: Like -d but print all aspects for the entire month.

=item rise & set

  -qd <month> <date> <year>: Compute chart for noon on date.
  -Zd: Search day for object local rising and setting times.
  -YRZ <rise> <zenith> <set> <nadir>: Set restrictions for -Zd chart.

=back

In case you have no Astrolog available, but you can run it on other machine/system and save its aspect/change and rise/set data to files, you can feed AstroCal with them
by configuring the cache option accordingly. This is not documented, so contact AstroCal's author if you need help. ( See L<AUTHOR> below. )

=head1 SEE ALSO

perl(1), Image::Magick(3), astrolog(1)

=head1 TODO

=over 4

=item

Better restriction expressions. The current implementation is a huge OR, but there should be AND, or meybe even NOT too.

=item

Colors, somehow similar to Astrolog. Mostly for wallpapers, not for printing purpose.

=item

Find some formula to help calculating font sizes when density is set to other than default.

=back

=head1 BUGS

Certainly there are. Report them, please.

=head1 AUTHOR

Feherke

=cut

__END__

<?php

// >>> settings >>>

$width=1400;
$height=1000;

$year=2010;
$month=1;

$shift=array(
//       H M S m d  Y             H M S m  d  Y
  mktime(3,0,0,3,29,2009)=>mktime(0,0,0,12,31,2009)
);

$astro=array(
  dir=>'/home/feherke/opt/astrolog',
  dat=>'iskola.dat'
);

$font=array(
//  title=>array('/home/feherke/lasthour/web/decorstudio-facsiga/font/x/Verona Script.ttf',72),
//  title=>array('/usr/share/foobillard/youregon.ttf',72),
//  title=>array('/usr/share/imlib2/data/fonts/cinema.ttf',72),
//  title=>array('/home/feherke/lasthour/web/timcsi/Actionwd.ttf',72),
  monthtitle=>array('/usr/lib/java/jre/lib/oblique-fonts/LucidaTypewriterBoldOblique.ttf',72),
  daytitle=>array('/usr/lib/X11/fonts/TTF/georgiai.ttf',32),
  day=>array('/usr/lib/X11/fonts/TTF/luxirbi.ttf',175),
  hour=>array('/usr/lib/X11/fonts/TTF/verdana.ttf',14),
  sign=>array('/usr/lib/X11/fonts/TTF/DejaVuLGCSansCondensed.ttf',18),
  moon=>array('/usr/lib/X11/fonts/TTF/DejaVuLGCSansCondensed.ttf',28),
  tale=>array('/usr/lib/X11/fonts/TTF/DejaVuSerifCondensed.ttf',20),
  about=>array('/usr/lib/X11/fonts/TTF/Vera.ttf',12)
);

$restrict=array('Lilith');

//$monthname=array('','Január','Február','Március','Április','Május','Június','Július','Augusztus','Szeptember','Október','November','December');
$monthname=array('','Ianuarie','Februarie','Martie','Aprilie','Mai','Iunie','Iulie','August','Septembrie','Octombrie','Noiembrie','Decembrie');
//$weekname=array('Hétfő','Kedd','Szerda','Csütörtök','Péntek','Szombat','Vasárnap');
$weekname=array('Luni','Marţi','Miercuri','Joi','Vineri','Sîmbătă','Duminică');
$phasename=array(
//  'Half Moon'=>'Fél hold',
  'Half Moon'=>'Semilună',
//  'First Quarter'=>'Első negyed',
  'First Quarter'=>'Primul pătrar',
//  'Last Quarter'=>'Utolsó negyed',
  'Last Quarter'=>'Ultimul pătrar',
//  'Full Moon'=>'Teli hold',
  'Full Moon'=>'Lună plină',
//  'New Moon'=>'Új hold',
  'New Moon'=>'Lună nouă',
//  'Vernal Equinox'=>'Tavaszi napéjegyenlőség',
  'Vernal Equinox'=>'Echinocţiu de primăvară',
//  'Summer Solstice'=>'Nyári napforduló',
  'Summer Solstice'=>'Solstiţiu de vară',
//  'Autumnal Equinox'=>'Őszi napéjegyenlőség',
  'Autumnal Equinox'=>'Echinocţiu de toamnă',
//  'Winter Solstice'=>'Téli napforduló'
  'Winter Solstice'=>'Solstiţiu de iarnă'
);

// <<< settings <<<

$date=strtotime("$year-$month-1");
$firstday=(idate('w',$date)+6)%7;
$countday=idate('t',$date);
$nextdate=strtotime("$year-$month-1 +1 month");
$nextmonth=idate('n',$nextdate);
$nextyear=idate('Y',$nextdate);

$astro[diresc]=escapeshellarg($astro[dir]);
$astro[datesc]=escapeshellarg($astro[dat]);

if (file_exists("as-aspect-$year-$month.txt")) {
  $output=file("as-aspect-$year-$month.txt",FILE_IGNORE_NEW_LINES);
} else {
  exec("cd $astro[diresc]; ./astrolog -i $astro[datesc] -YQ 0 -qm $month $year -dm",$output,$error);
//exec("cd $astro[diresc]; ./astrolog -i $astro[datesc] -YQ 0 -qd $nextmonth 1 $nextyear -d",$output,$error);
//exec("cd $astro[diresc]; ./astrolog -i $astro[datesc] -YQ 0 -qd $nextmonth 2 $nextyear -d",$output,$error);
  file_put_contents("as-aspect-$year-$month.txt",join("\n",$output));
}

if (file_exists("as-riseset-$year-$month.txt")) {
  $outputrs=file("as-riseset-$year-$month.txt",FILE_IGNORE_NEW_LINES);
} else {
  for ($day=1;$day<=$countday;$day++) exec("cd $astro[diresc]; ./astrolog -i $astro[datesc] -YQ 0 -qd $month $day $year -Zd -YRZ 0 1 0 1",$outputrs,$error);
  file_put_contents("as-riseset-$year-$month.txt",join("\n",$outputrs));
}

/*      $1         $2 $3 $4            $5        $6    $7
1 (Sun) 11- 1-2009  6:28    Moon (Can) Sex [Vir] Saturn
1 (Sun) 11- 1-2009  5:28     Sun (Cap) Opp (Can) Moon (Full Moon)
2 (Sun) 11- 1-2009 19:42    Moon (Can) --> Leo
2 (Fri) 20- 3-2009 13:43     Sun (Pis) --> Aries (Vernal Equinox)
3 (Sun) 11- 1-2009  4:50 Mercury <Aqu> S/R
*/

$moon=$moonin=$sun=$plan=$void=$blah=$full=array();
$last=NULL;
$quarter=0;
foreach ($output as $str) {
  $str=chop($str);

  unset($match);
  $type=0;

  if (preg_match('!^\([[:alpha:]]{3}\) +([[:digit:]]{1,2})- ?[[:digit:]]{1,2}-[[:digit:]]{4} +([[:digit:]]{1,2}):([[:digit:]]{2}) +([[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] ([[:alpha:]]{3}) [(\[<][[:alpha:]]{3}[)\]>] ([[:alpha:]]{3,7})(?: \(((?:New|Half|Full) Moon)\))?$!',$str,$match)) $type=1;
  elseif (preg_match('!^\([[:alpha:]]{3}\) +([[:digit:]]{1,2})- ?[[:digit:]]{1,2}-[[:digit:]]{4} +([[:digit:]]{1,2}):([[:digit:]]{2}) +([[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] (-->) ([[:alpha:]]{3,11})(?: \(((?:Vernal|Summer|Autumnal|Winter) (?:Equinox|Solstice))\))?$!',$str,$match)) $type=2;
  elseif (preg_match('!^\([[:alpha:]]{3}\) +([[:digit:]]{1,2})- ?[[:digit:]]{1,2}-[[:digit:]]{4} +([[:digit:]]{1,2}):([[:digit:]]{2}) +([[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] (S/[RD])$!',$str,$match)) $type=3;
  else $type=0;

  if (!$type || in_array($match[4],$restrict) || in_array($match[6],$restrict)) continue;

  foreach ($shift as $from=>$to) { // daylight saving
    $given=mktime($match[2],$match[3],0,$month,$match[1],$year,-1);
    if ($given>=$from && $given<$to) {
      $given=mktime($match[2]+1,$match[3],0,$month,$match[1],$year,-1);
      if (idate('n',$given)!=$month) break 2;
      $match[1]=idate('j',$given);
      $match[2]=idate('G',$given);
      break;
    }
  }

  switch ($type) {
    case 1: // (*)
      if ($match[4]=='Moon' || $match[6]=='Moon') {
//        $moon[$match[1]][]=array($match[2],$match[3],$match[4],$match[5],$match[6]);
        if ($match[7]) {
          $blah[]=array($match[1],$match[2],$match[3],$match[7]);
          if ($match[7]=='Full Moon') {
            $fullstart=explode(' ',date('n j G i',strtotime("$year-$month-$match[1] $match[2]:$match[3] -18 hour")));
            $fullend=explode(' ',date('n j G i',strtotime("$year-$month-$match[1] $match[2]:$match[3] +18 hour")));
            if ($fullstart[0]==$month) $moon[$fullstart[1]][]=array($fullstart[2],$fullstart[3],'Moon','start','dark'); else $fullstart=array($month,1,0,0);
            if ($fullend[0]==$month) $moon[$fullend[1]][]=array($fullend[2],$fullend[3],'Moon','end','dark'); else $fullend=array($month,$countday,23,59);
            if ($fullstart[0]==$fullend[0] && $fullstart[1]==$fullend[1]) {
              $full[$fullstart[1]][]=array($fullstart[2],$fullstart[3],$fullend[2],$fullend[3]);
            } else {
              $full[$fullstart[1]][]=array($fullstart[2],$fullstart[3],23,59);
              for ($i=$fullstart[1]+1;$i<$fullend[1];$i++) $full[$i][]=array(0,0,23,59);
              $full[$fullend[1]][]=array(0,0,$fullend[2],$fullend[3]);
            }
          }
        }
        if (in_array($match[5],array('Con','Sex','Squ','Tri','Opp'))) $last=$match;
      } else $plan[$match[1]][]=array($match[2],$match[3],$match[4],$match[5],$match[6]);
    break;
    case 2: // -->
      if ($match[4]=='Moon') {
        $moonin[$match[1]][]=array($match[2],$match[3],$match[4],'enter',$match[6]);
        if ($last) {
          $moon[$last[1]][]=array($last[2],$last[3],$last[4],$last[5],$last[6]);
          $moon[$match[1]][]=array($match[2],$match[3],$match[4],'enter',$match[6]);
          if ($match[1]==$last[1]) {
            $void[$match[1]][]=array($last[2],$last[3],$match[2],$match[3]);
          } else {
            $void[$last[1]][]=array($last[2],$last[3],23,59);
            for ($i=$last[1]+1;$i<$match[1];$i++) $void[$i][]=array(0,0,23,59);
            $void[$match[1]][]=array(0,0,$match[2],$match[3]);
          }
        }
      } elseif ($match[4]=='Sun') {
        $sun[$match[1]][]=array($match[2],$match[3],$match[4],'enter',$match[6]);
      } else {
        $plan[$match[1]][]=array($match[2],$match[3],$match[4],'enter',$match[6]);
        if ($match[7]) $blah[]=array($match[1],$match[2],$match[3],$match[7]);
      }
    break;
    case 3: // R/D
      $plan[$match[1]][]=array($match[2],$match[3],$match[4],'enter',substr($match[5],-1));
    break;
  }

}

$last=NULL;
for ($i=1;$i<=$countday;$i++) {
  if (!$moonin[$i] && $last) $moonin[$i][]=$last;
  else {
    $last=$moonin[$i][0];
    $last[3]='in';
  }
}

/*     $1        $2 $3 $4            $5
(Thu)  1- 1-2009  8:15     Sun (Cap) rises   at 325:22' (0.69s 1.00e)                                                                                                    
(Thu)  1- 1-2009 16:43     Sun (Cap) sets    at 214:34' (0.69s 1.00w)                                                                                                    
*/

$rise=array();

foreach ($outputrs as $str) {
  $str=chop($str);

  unset($match);

  if (preg_match('!^\([[:alpha:]]{3}\) +([[:digit:]]{1,2})- ?[[:digit:]]{1,2}-[[:digit:]]{4} +([[:digit:]]{1,2}):([[:digit:]]{2}) +([[:alpha:]]{3,7}) [(\[<][[:alpha:]]{3}[)\]>] (rises|sets) +.*$!',$str,$match)) {

    foreach ($shift as $from=>$to) { // daylight saving
      $given=mktime($match[2],$match[3],0,$month,$match[1],$year,-1);
      if ($given>=$from && $given<$to) {
        $given=mktime($match[2]+1,$match[3],0,$month,$match[1],$year,-1);
        if (idate('n',$given)!=$month) break 2;
        $match[1]=idate('j',$given);
        $match[2]=idate('G',$given);
        break;
      }
    }

    if ($match[4]=='Sun') {
      $rise[$match[1]][]=array($match[2],$match[3],$match[5]);
    }
  }

}

$str=`recode html..utf8 <<< $'Sun &#x2609;\nMoon &#x263d;\nCrescent &#x263d;\nDecrescent &#x263e;\nHalf &#x263e;\nFull &#x25cb;\nNew &#x25cf;\nMercury &#x263f;\nVenus &#x2640;\nMars &#x2642;\nJupiter &#x2643;\nSaturn &#x2644;\nUranus &#x2645;\nNeptune &#x2646;\nPluto &#x2647;\nNode &#x260a;\nAries &#x2648;\nTaurus &#x2649;\nGemini &#x264a;\nCancer &#x264b;\nLeo &#x264c;\nVirgo &#x264d;\nLibra &#x264e;\nScorpio &#x264f;\nSagittarius &#x2650;\nCapricorn &#x2651;\nAquarius &#x2652;\nPisces &#x2653;\nConjunction &#x260c;\nOpposition &#x260d;\nTrine &#x25b3;\nSquare &#x25a1;\nSextile &#x2731;\nenter &#x2794;\nrises &#x2191;\nsets &#x2193;\ndark &#9785;\nstart &#9758;\nend &#9756;'`;
// $str=`recode html..utf8 <<< $'Sun &#x2609;\nMoon &#x263d;\nCrescent &#x263d;\nDecrescent &#x263e;\nHalf &#x263e;\nFull &#x25cb;\nNew &#x25cf;\nMercury &#x263f;\nVenus &#x2640;\nMars &#x2642;\nJupiter &#x2643;\nSaturn &#x2644;\nUranus &#x2645;\nNeptune &#x2646;\nPluto &#x2647;\nNode &#x260a;\nAries &#x2648;\nTaurus &#x2649;\nGemini &#x264a;\nCancer &#x264b;\nLeo &#x264c;\nVirgo &#x264d;\nLibra &#x264e;\nScorpio &#x264f;\nSagittarius &#x2650;\nCapricorn &#x2651;\nAquarius &#x2652;\nPisces &#x2653;\nConjunction &#x260c;\nOpposition &#x260d;\nTrine &#x25b3;\nSquare &#x25a1;\nSextile &#x2731;\nenter &#x2794;\nrises &#x2909;\nsets &#x2908;'`;

foreach (explode("\n",$str) as $one) {
  $two=explode(' ',$one);
  $char[$two[0]]=$two[1];
  if (strlen($two[0])>3) $char[substr($two[0],0,3)]=$two[1];
}
$char=array_merge($char,array(
  'D'=>'D',
  'R'=>'R',
  'in'=>'   '
));

$color=array(
  white=>new ImagickPixel('white'),
  black=>new ImagickPixel('black'),
  gray=>new ImagickPixel('gray'),
  silver=>new ImagickPixel('silver'),
  lightgray=>new ImagickPixel('lightgray'),
  dimgray=>new ImagickPixel('#eee')
);

$image=new Imagick();
$image->newImage($width,$height,$color[white]);
$image->setImageFormat('png');
$image->setCompression(Imagick::COMPRESSION_NO);

$draw=array(
  line=>new ImagickDraw(),
  mark=>new ImagickDraw()
);
foreach (array_keys($font) as $one) $draw[$one]=new ImagickDraw();

foreach (array_keys($font) as $one) {
  $draw[$one]->setFont($font[$one][0]);
  $draw[$one]->setFontSize($font[$one][1]);
  $draw[$one]->setGravity(Imagick::GRAVITY_NORTHWEST); // Imagick::GRAVITY_( NORTHWEST | NORTH | NORTHEAST | WEST | CENTER | EAST | SOUTHWEST | SOUTH | SOUTHEAST )
}

$draw[monthtitle]->setStrokeColor($color[lightgray]);
$draw[monthtitle]->setFillColor($color[dimgray]);
$draw[monthtitle]->setTextAlignment(Imagick::ALIGN_RIGHT);
$draw[day]->setStrokeColor($color[lightgray]);
$draw[day]->setFillColor($color[dimgray]);
$draw[day]->setTextAlignment(Imagick::ALIGN_RIGHT);
$draw[hour]->setTextAlignment(Imagick::ALIGN_CENTER);
$draw[sign]->setTextAlignment(Imagick::ALIGN_CENTER);
$draw[moon]->setTextAlignment(Imagick::ALIGN_CENTER);
//$draw[about]->setGravity(Imagick::GRAVITY_NORTHEAST); // Imagick::GRAVITY_( NORTHWEST | NORTH | NORTHEAST | WEST | CENTER | EAST | SOUTHWEST | SOUTH | SOUTHEAST )

$size=array(
  monthtitle=>$image->queryFontMetrics($draw[monthtitle],"$year $monthname[$month]",false),
  daytitle=>$image->queryFontMetrics($draw[daytitle],$weekname[0],false),
  day=>$image->queryFontMetrics($draw[day],12,false),
  hour=>$image->queryFontMetrics($draw[hour],'12:34',false),
  sign=>$image->queryFontMetrics($draw[sign],$char[Sun].$char[Conjunction].$char[Moon],false),
  tale=>$image->queryFontMetrics($draw[tale],'Fairy Tale',false)
);

$cell=array(
  left=>1,
  top=>$size[monthtitle][textHeight]
);
$cell=array_merge($cell,array(
  width=>floor(($width-$cell[left])/7),
  height=>floor(($height-$cell[top])/6)
));
$cell=array_merge($cell,array(
  right=>$cell[width]*7+$cell[left],
  bottom=>$cell[height]*6+$cell[top]
));

// border ?
$draw[line]->setStrokeColor($color[gray]);
$draw[line]->setFillColor($color[white]);
for ($i=0;$i<7+1;$i++) $draw[line]->line($cell[width]*$i+$cell[left],$cell[top],$cell[width]*$i+$cell[left],$cell[bottom]-(abs(5-$i)==1?$cell[height]:0));
for ($i=0;$i<6+1;$i++) $draw[line]->line($cell[left],$cell[height]*$i+$cell[top],$cell[right],$cell[height]*$i+$cell[top]);

$draw[line]->setStrokeColor($color[silver]);
for ($i=0;$i<6;$i++) {
  $draw[line]->line($cell[left],$cell[height]*$i+$cell[top]+$cell[height]/3*2-5,$cell[right]-($i==5?$cell[width]*4:0),$cell[height]*$i+$cell[top]+$cell[height]/3*2-5);
  $draw[line]->line($cell[left],$cell[height]*$i+$cell[top]+$cell[height]/3*2+5,$cell[right]-($i==5?$cell[width]*4:0),$cell[height]*$i+$cell[top]+$cell[height]/3*2+5);
}

$image->annotateImage($draw[monthtitle],$cell[right],$cell[top]-10,0,"$year $monthname[$month]");
//$image->annotateImage($draw[about],10,5,0,"Walter D. Pullen számításai alapján az Astrolog 5.40 felhasználásával");
//$image->annotateImage($draw[about],10,15,0,"PHP script rajzolta az ImageMagick rutinkönyvtár segítségével");
//$image->annotateImage($draw[about],$cell[width]*5+$cell[left]+3,$cell[height]*5+$cell[top]+3,0,"Walter D. Pullen számításai alapján\naz Astrolog 5.40 felhasználásával");
$image->annotateImage($draw[about],$cell[width]*5+$cell[left]+3,$cell[height]*5+$cell[top]+3,0,"Pe baza calculelor lui Walter D. Pullen\nfolosind programul Astrolog 5.40");
//$image->annotateImage($draw[about],$cell[width]*5+$cell[left]+3,$cell[height]*5+$cell[top]+$cell[height]/2,0,"PHP script rajzolta\naz ImageMagick rutinkönyvtár segítségével");
$image->annotateImage($draw[about],$cell[width]*5+$cell[left]+3,$cell[height]*5+$cell[top]+$cell[height]/2,0,"Desenat de script PHP\ncu ajutorul bibliotecii ImageMagick");

for ($i=0;$i<7;$i++) $image->annotateImage($draw[daytitle],$cell[width]*$i+$cell[left],$size[monthtitle][textHeight]-$size[daytitle][textHeight],0,$weekname[$i]);

for ($i=1;$i<=$countday;$i++) {
  list($dayx,$dayy)=daypos($i);
  $image->annotateImage($draw[day],$dayx+$cell[width]-5,$dayy+$cell[height]-10,0,$i);
}

$draw[line]->setStrokeColor($color[silver]);
$draw[line]->setFillColor($color[gray]);

foreach ($void as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

  foreach ($set as $i=>$data) {
    $hourx1=hourpos($data[0],$data[1]);
    $hourx2=hourpos($data[2],$data[3]);

    $draw[line]->rectangle($dayx+$hourx1,$dayy+$cell[height]/3*2-5,$dayx+$hourx2,$dayy+$cell[height]/3*2+5);
  }
}

$draw[line]->setStrokeColor($color[silver]);
$draw[line]->setFillColor($color[black]);

foreach ($full as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

  foreach ($set as $i=>$data) {
    $hourx1=hourpos($data[0],$data[1]);
    $hourx2=hourpos($data[2],$data[3]);

    $draw[line]->rectangle($dayx+$hourx1,$dayy+$cell[height]/3*2-5,$dayx+$hourx2,$dayy+$cell[height]/3*2-1);
  }
}

/*foreach ($sun as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

  foreach ($set as $i=>$data) {
    $hourx=hourpos($data[0],$data[1]);
    $textx=$cell[width]/9*2;
    $texty=5;

    $image->annotateImage($draw[hour],$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+15,0,$data[0].':'.$data[1]);
    $image->annotateImage($draw[moon],$dayx+$textx,$dayy+$texty+18,0,$char['Sun'].$char['enter'].$char[$data[4]]);

    $draw[mark]->ellipse($dayx+$hourx,$dayy+$cell[height]/3*2,1.5,1.5,0,360);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2,$dayx+$hourx,$dayy+$cell[height]/3*2-5);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2-5,$dayx+$textx,$dayy+$cell[height]/3*2-20);
    $draw[mark]->line($dayx+$textx,$dayy+$cell[height]/3*2-20,$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+22);
  }

}*/

foreach ($moonin as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

  foreach ($set as $i=>$data) {
    $textx=$cell[width]/9*2;
    $texty=10;

    $image->annotateImage($draw[moon],$dayx+$textx,$dayy+$texty+18,0,$char['Moon'].$char[$data[3]].$char[$data[4]]);
    if (!trim($char[$data[3]])) $image->annotateImage($draw[hour],$dayx+$textx,$dayy+$texty+18,0,'în');
  }

}

foreach ($rise as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

  foreach ($set as $i=>$data) {
    $hourx=hourpos($data[0],$data[1]);
    $textx=$cell[width]/9*($i*2+6);
    $texty=0;

    $image->annotateImage($draw[hour],$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+15,0,$data[0].':'.$data[1]);
    $image->annotateImage($draw[sign],$dayx+$textx,$dayy+$texty+18,0,$char['Sun'].$char[$data[2]]);

//    $draw[mark]->ellipse($dayx+$hourx,$dayy+$cell[height]/3*2,1.5,1.5,0,360);
//    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2,$dayx+$hourx,$dayy+$cell[height]/3*2-5);
//    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2-5,$dayx+$textx,$dayy+$cell[height]/3*2-20);
//    $draw[mark]->line($dayx+$textx,$dayy+$cell[height]/3*2-20,$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+22);
  }

}

/*
foreach ($moon as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

//for ($i=count($set);$i<8;$i++) $set[]=$set[0];

  foreach ($set as $i=>$data) {
    $hourx=hourpos($data[0],$data[1]);
    $textx=$cell[width]/4.5*$i/2+$cell[width]/9;
    $texty=$i%2*$cell[height]/4;

    $textx=$cell[width]/(count($set)/2+.5)*$i/2+$cell[width]/(count($set)+1);

//if ($data[2]=='-->') $image->annotateImage($draw[sign],(($day-1+$firstday)%7)*$cell[width]+$cell[left]+$i*($size[sign][textWidth]+5)+5,floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]+$size[day][textHeight],0,$char[Moon].$char[enter].$char[$data[3]]);
//elseif (substr($data[2],-4)=='Moon') $image->annotateImage($draw[sign],(($day-1+$firstday)%7)*$cell[width]+$cell[left]+$i*($size[sign][textWidth]+5)+5,floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]+$size[day][textHeight],0,$char[substr($data[2],0,-5)]);
//else ;
//$image->annotateImage($draw[hour],(($day-1+$firstday)%7)*$cell[width]+$cell[left]+$i*($size[sign][textWidth]+5)+5,floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]+$size[day][textHeight]+$size[sign][textHeight],0,$data[0].':'.$data[1]);

    $image->annotateImage($draw[hour],$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+15,0,$data[0].':'.$data[1]);
    $image->annotateImage($draw[sign],$dayx+$textx,$dayy+$texty+18,0,$char[$data[2]].$char[$data[3]].$char[$data[4]]);

    $draw[mark]->ellipse($dayx+$hourx,$dayy+$cell[height]/3*2,1.5,1.5,0,360);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2,$dayx+$hourx,$dayy+$cell[height]/3*2-5);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2-5,$dayx+$textx,$dayy+$cell[height]/3*2-20);
    $draw[mark]->line($dayx+$textx,$dayy+$cell[height]/3*2-20,$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+22);
  }

}
*/

foreach ($moon as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

//for ($i=count($set);$i<4;$i++) $set[]=$set[0];

  sort($set);
  foreach ($set as $i=>$data) {
    $hourx=hourpos($data[0],$data[1]);
    $textx=$cell[width]/4.5*$i/2+$cell[width]/9;
    $texty=$cell[height]/4;
    $textx=$cell[width]/count($set)*$i+$cell[width]/(count($set)*2);

    $image->annotateImage($draw[hour],$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+15,0,$data[0].':'.$data[1]);
    $image->annotateImage($draw[sign],$dayx+$textx,$dayy+$texty+18,0,$char[$data[2]].$char[$data[3]].$char[$data[4]]);

    $draw[mark]->ellipse($dayx+$hourx,$dayy+$cell[height]/3*2,1.5,1.5,0,360);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2,$dayx+$hourx,$dayy+$cell[height]/3*2-5);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2-5,$dayx+$textx,$dayy+$cell[height]/3*2-20);
    $draw[mark]->line($dayx+$textx,$dayy+$cell[height]/3*2-20,$dayx+$textx,$dayy+$texty+$size[sign][textHeight]+22);
  }

}

foreach ($plan as $day=>$set) {
  list($dayx,$dayy)=daypos($day);

  foreach ($set as $i=>$data) {
    $hourx=hourpos($data[0],$data[1]);
    $textx=$cell[width]/4*$i+$cell[width]/8;
    $textx=$cell[width]/count($set)*$i+$cell[width]/(count($set)*2);

//if ($data[2]=='-->') $image->annotateImage($draw[sign],(($day-1+$firstday)%7)*$cell[width]+$cell[left]+$i*($size[sign][textWidth]+5)+5,floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]+$cell[height]-$size[sign][textHeight],0,$char[Sun].$char[enter].$char[$data[3]]);
//else $image->annotateImage($draw[sign],(($day-1+$firstday)%7)*$cell[width]+$cell[left]+$i*($size[sign][textWidth]+5)+5,floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]+$cell[height]-$size[sign][textHeight],0,$char[$data[2]].$char[enter].substr($data[3],2));
//$image->annotateImage($draw[hour],(($day-1+$firstday)%7)*$cell[width]+$cell[left]+$i*($size[sign][textWidth]+5)+5,floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]+$cell[height]-$size[sign][textHeight]-$size[hour][textHeight],0,$data[0].':'.$data[1]);

//    $image->annotateImage($draw[hour],$dayx+$textx,$dayy+$cell[height]/3*2+$size[sign][textHeight]+$size[hour][textHeight],0,$data[0].':'.$data[1]);
//    $image->annotateImage($draw[sign],$dayx+$textx,$dayy+$cell[height]/3*2+$size[sign][textHeight],0,$char[$data[2]].$char[$data[3]].$char[$data[4]]);

    $image->annotateImage($draw[hour],$dayx+$textx,$dayy+$cell[height]-$size[sign][textHeight],0,$data[0].':'.$data[1]);
    $image->annotateImage($draw[sign],$dayx+$textx,$dayy+$cell[height]-3,0,$char[$data[2]].$char[$data[3]].$char[$data[4]]);

    $draw[mark]->ellipse($dayx+$hourx,$dayy+$cell[height]/3*2,1.5,1.5,0,360);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2,$dayx+$hourx,$dayy+$cell[height]/3*2+5);
    $draw[mark]->line($dayx+$hourx,$dayy+$cell[height]/3*2+5,$dayx+$textx,$dayy+$cell[height]/3*2+15);
    $draw[mark]->line($dayx+$textx,$dayy+$cell[height]/3*2+15,$dayx+$textx,$dayy+$cell[height]/3*2+17);
  }

}

foreach ($blah as $i=>$set) {
  $image->annotateImage($draw[tale],$cell[width]*3+$cell[left]+3,$cell[height]*5+$cell[top]+$size[tale][textHeight]*$i+3,0,sprintf("%2d %2d:%02d - %s",$set[0],$set[1],$set[2],$phasename[$set[3]]));
}

$image->drawImage($draw[line]);

$image->drawImage($draw[mark]);

echo $image;

function daypos($day)
{
  global $cell,$firstday;
  return array(
    (($day-1+$firstday)%7)*$cell[width]+$cell[left],
    floor(($day-1+$firstday)/7)*$cell[height]+$cell[top]
  );
}

function hourpos($hour,$minute)
{
  global $cell;
  return ($hour*60+$minute)*$cell[width]/1440;
}

?>
