
package inifile;

use strict;
use warnings;



sub readini($\%)
{
  my $name=shift;
  my $data=shift;

  return 1 unless ref($data) eq 'HASH';

  return 1 unless -f $name;
  return 3 unless -r $name;

  my %data=%{$data};

  foreach my $cat (keys %data) {
    return 6 if ref($data{$cat}) ne 'HASH';
  }

  open FIL,'<',$name or return 7;
  my $cat='-';
  while (my $str=<FIL>) {
    chomp $str;
    next if ! $str or substr($str,0,1) eq '#';
    if ($str=~m/^\[(\w+)\]/) {
      $cat=$1;
    } elsif ($str=~m/^(\w+)=(.*)/) {
      $data->{$cat}{$1}=$2;
    }
  }
  close FIL;

  0
}



sub writeini($\%\@)
{
  my $name=shift;
  my $data=shift;

  return 1 unless ref($data) eq 'HASH';

  if (-e $name) {
    return 2 unless -f $name;
    return 4 unless -w $name;
  }

  my %data=%{$data};

  foreach my $cat (keys %data) {
    return 6 if ref($data{$cat}) ne 'HASH';
  }

  open FIL,'>',$name or return 7;
  foreach my $str (@_) { print FIL "# $str\n" }
  foreach my $cat (keys %data) {
    print FIL "\n[$cat]\n";
    foreach my $key (keys %{$data{$cat}}) { print FIL "$key=$data{$cat}{$key}\n" }
  }
  close FIL;

  0
}



1;



=head1 SYNTAX

  use inifile;

  my %datastructure;

  &inifile::readini 'filename.ini', \%datastructure;

  &inifile::writeini 'filename.ini', \%datastructure, 'file header comment';

=head1 RETURN VALUE

=over 4

=item 0

performed successfully

=item 1

file not found

=item 2

file exists but is not a regular file

=item 3

file with no read permission

=item 4

file with no write permission

=item 5

parameter is not a hash reference

=item 6

hash element is not a hash

=item 7

other error

=back

=cut
