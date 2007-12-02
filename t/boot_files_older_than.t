#
# Test routine to identify obsolete kernel-specific files in /boot...
#
use strict;
use warnings;

use Test::More tests => 3;

use_ok( 'Linux::BootCleanup', qw( boot_files_older_than ) ) or exit;

#~~~~ ((( begin test initialization ))) ~~~~
my @misc = qw(
    .
    ..
    grub
    lost+found
    memtest86+.bin
    System.map
);
my @abi = qw(
    abi-2.6.15-26-386
    abi-2.6.15-26-386.EL
    abi-2.6.15-26-386.ELsmp
    abi-2.6.15-27-386
    abi-2.6.17-10-generic
    abi-2.6.17-11-generic
    abi-2.6.17-12-generic
    abi-2.6.17-12-generic.EL
    abi-2.6.17-12-generic.ELsmp
);
my @config = qw(
    config-2.6.00-00-386
    config-2.6.15-26-386
    config-2.6.15-26-386.EL
    config-2.6.15-26-386.ELsmp
    config-2.6.15-27-386
    config-2.6.17-10-generic
    config-2.6.17-11-generic
    config-2.6.17-12-generic
    config-2.6.17-12-generic.EL
    config-2.6.17-12-generic.ELsmp
);
my @initrd = qw(
    initrd.img-2.6.00-00-386
    initrd.img-2.6.15-26-386
    initrd.img-2.6.15-26-386.EL
    initrd.img-2.6.15-26-386.ELsmp
    initrd.img-2.6.15-27-386
    initrd.img-2.6.17-10-generic
    initrd.img-2.6.17-11-generic
    initrd.img-2.6.17-12-generic
    initrd.img-2.6.17-12-generic.EL
    initrd.img-2.6.17-12-generic.ELsmp
);
my @system = qw(
    System.map-2.6.00-00-386
    System.map-2.6.15-26-386
    System.map-2.6.15-26-386.EL
    System.map-2.6.15-26-386.ELsmp
    System.map-2.6.15-27-386
    System.map-2.6.17-10-generic
    System.map-2.6.17-11-generic
    System.map-2.6.17-12-generic
    System.map-2.6.17-12-generic.EL
    System.map-2.6.17-12-generic.ELsmp
);
my @vmlinuz = qw(
    vmlinuz-2.6.00-00-386
    vmlinuz-2.6.15-26-386
    vmlinuz-2.6.15-26-386.EL
    vmlinuz-2.6.15-26-386.ELsmp
    vmlinuz-2.6.15-27-386
    vmlinuz-2.6.17-10-generic
    vmlinuz-2.6.17-11-generic
    vmlinuz-2.6.17-12-generic
    vmlinuz-2.6.17-12-generic.EL
    vmlinuz-2.6.17-12-generic.ELsmp
);

# Represent entire contents of /boot directory...
my @aggregated_bootfiles = (@misc, @abi, @config, @initrd, @system, @vmlinuz);

my $lower_bound_version = '2.6.17-10';

# All of the above whose versions are less than our chosen lower bound...
my @obsolete = qw(
    abi-2.6.15-26-386
    abi-2.6.15-26-386.EL
    abi-2.6.15-26-386.ELsmp
    abi-2.6.15-27-386
    config-2.6.00-00-386
    config-2.6.15-26-386
    config-2.6.15-26-386.EL
    config-2.6.15-26-386.ELsmp
    config-2.6.15-27-386
    initrd.img-2.6.00-00-386
    initrd.img-2.6.15-26-386
    initrd.img-2.6.15-26-386.EL
    initrd.img-2.6.15-26-386.ELsmp
    initrd.img-2.6.15-27-386
    System.map-2.6.00-00-386
    System.map-2.6.15-26-386
    System.map-2.6.15-26-386.EL
    System.map-2.6.15-26-386.ELsmp
    System.map-2.6.15-27-386
    vmlinuz-2.6.00-00-386
    vmlinuz-2.6.15-26-386
    vmlinuz-2.6.15-26-386.EL
    vmlinuz-2.6.15-26-386.ELsmp
    vmlinuz-2.6.15-27-386
);
#~~~~ ((( end test initialization ))) ~~~~

# Alter filenames to represent would-be paths as done by boot_files_older_than()
my @prefixed_obsolete = map { "/boot/$_" } @obsolete;

{
    # Mock dir-reading functions within Linux::Bootcleanup package...
    package Linux::BootCleanup;
    use subs qw( opendir closedir readdir );
    package main;

    my $next_index = 0;

    *Linux::BootCleanup::opendir =  sub { return 1 };
    *Linux::BootCleanup::closedir = sub { return 1 };
    *Linux::BootCleanup::readdir =  sub {
        if( wantarray() ) {
            return @aggregated_bootfiles;
        }
        else {
            if( $next_index <= $#aggregated_bootfiles ) {
                return $aggregated_bootfiles[ $next_index++ ];
            }
            else{ return undef; }
        }
    };

    ok( my @got_obsolete =
            boot_files_older_than( $lower_bound_version, qr/abi|system\.map|vmlinux|vmlinuz|config|initrd/i ),
            "can get list of obsolete /boot files"
    );

    my @sorted_got =        sort @got_obsolete;
    my @sorted_expected =   sort @prefixed_obsolete;
    is_deeply( \@sorted_got, \@sorted_expected, "located expected set of obsoletes from mock /boot dir" );
}
