#
# Test release number normalization function...
#
use strict;

use Test::More tests => 10;
use Linux::BootCleanup qw( normalized_release_num );

#~~~~ ((( begin test initialization ))) ~~~~
my %valid_releases = (
    'initrd.img-2.6.15-27-386'                  => '2.6.15-27-386',
    'initrd.img-2.6.15-27-386.EL'               => '2.6.15-27-386',
    'initrd.img-2.6.15-27-386.ELsmp'            => '2.6.15-27-386',
    'System.map-2.6.17-12-generic'              => '2.6.17-12',
    'blahblahblah-2.6.15-27-386'                => '2.6.15-27-386',
    'anything-9999.9999.999999-999999-XXXXX'    => '9999.9999.999999-999999',
    'memtest86+.bin'                            => '86',    # valid -- potential rel num format
    'initrd.img2-xxx-2.6.15-27-386'             => '2',     # valid -- first match
);

my @no_release_nums = qw(
    no-release-number
    vmlinuz-test
);
#~~~~ ((( end test initialization ))) ~~~~

while( my ($arg, $relnum) = each %valid_releases ) {
    is( normalized_release_num( $arg ), $relnum, "string '$arg' corresponds to release number $relnum\n" )
}

map {
    is( normalized_release_num( $_ ), undef, "string $_ contains no valid release number\n" )
} @no_release_nums;

