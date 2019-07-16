#!/usr/bin/perl

=pod

=head1 NAME

fix_md.pl

=head1 SYNOPSIS

./fix_md.pl [ OPTIONS ]

=cut

use strict;
use warnings;
use IO::File;
use Pod::Usage;
use Getopt::Long;
use POSIX;

my $debug = 0;

=head1 OPTIONS

=over

=item -h | --help

Print this message

=item -d | --debug

Turn on debugging mode. 

=back

=cut

my $dummy = GetOptions( 
	"h|help" => sub { pod2usage(verbose => 1, exitval => 1); },
	"d|debug" => \$debug
);

my $fh = IO::File->new('/proc/mdstat','r')
	or die "Couldn't open /proc/mdstat!";
chomp ( my @md_info = <$fh> );

printf "# %d MDs found.\n", scalar(grep /^md/, @md_info) if $debug;
foreach my $rec (grep {/^md/} @md_info) {
	my $md = $1 if $rec =~ m/^(md\w+)/mg;	
	my @devices = undef;
	printf "# Processing MD: %s\n", $md if $debug and $md;
	@devices = $rec =~ m/ (\w+)\[\d\]/g;
	foreach my $device (@devices) {
		my $status = ($rec =~ m/$device\[\d\]\(F\)/ ) ? 'nok' : 'ok';
		print "# Found device $device ($status).\n" if $debug;
		if ($status eq 'nok' ) {
			print "# Re-addinging $device from $md.\n" if $debug;
			print "mdadm --manage /dev/$md --remove /dev/$device\n";
			print "mdadm --manage /dev/$md --add /dev/$device\n";
		}
	}	

	unless ( scalar(@devices) > 1 ) {
		my $uuid = $1 if qx(blkid) =~ m/$devices[0].* UUID=\"(\S+)\"/;
		my $newbie = $1 if qx(blkid | fgrep -v $devices[0]) =~ m/(\S+):.*$uuid/mg;
		print "# !!! Some devices are missing !!!\n" if $debug;
		print "# UUID: $uuid has also $newbie\n" if $debug;
		print "# Adding $newbie into $md.\n" if $debug;
		print "mdadm --manage /dev/$md --add $newbie\n";
		
	}
	printf "\n" if $debug;
}

$fh->close;
