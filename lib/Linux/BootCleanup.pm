#! /usr/bin/perl

package Linux::BootCleanup;

use strict;
use warnings;
use Carp;

our $VERSION = 0.02;

use POSIX qw(strftime);
use Exporter qw(import);
use Pod::Usage;
use Getopt::Long;
use Getopt::ArgvFile home => 1;
use Archive::Tar;
use IO::Prompt;
use Linux::Bootloader;
use Linux::Bootloader::Detect;

our @EXPORT_OK = qw(
    normalized_release_num  rel_num_compare
    remove_bootldr_stanzas  archive_files
    boot_files_older_than 
);

__PACKAGE__->run unless caller;

#######

sub _show_help { pod2usage( -verbose => 99, -sections => 'PROGRAM: SYNOPSIS' ) }

sub run {
    my ($help, $archive_dest_dir, $bootloader_menu, $delete_originals,
        $targets_re, $oldest_kernel_to_keep, $dry_run, $verbose);
    my $options_ok = GetOptions(
        'help'                  => \$help,
        'archive-dest=s'        => \$archive_dest_dir,
        'bootldr-config=s'      => \$bootloader_menu,
        'delete-originals=s'    => \$delete_originals,
        'targets-re=s'          => \$targets_re,
        'oldest-to-keep=s'      => \$oldest_kernel_to_keep,
        'dry-run'               => \$dry_run,
        'verbose'               => \$verbose,
    );
    $options_ok     || _show_help;
    defined $help   && _show_help;

    my $archive_name;

    # Get archive destination dir...
    until( defined $archive_dest_dir && -d $archive_dest_dir ) {
        $archive_dest_dir = prompt(
            'Enter destination directory for archive of old boot files ',
            -default => '/boot' );
    }

    # Determine whether or not to remove original files...
    if( defined $delete_originals ) {
        $delete_originals = 'n' unless lc $delete_originals eq 'y';
    }
    else {
        $delete_originals = prompt(
            'Delete originals after archiving? ',
            -default => 'n' );
    }
    undef $delete_originals unless lc $delete_originals eq 'y';

    # Define filter to identify target files...
    my $default_targets_re = '/system\.map|vmlinux|vmlinuz|config|initrd/';
    until( $targets_re && $targets_re =~ m|^/.*/$| ) {
        $targets_re = prompt(
            'Enter a regex against which target files from /boot must match (include leading/trailing \'/\') ',
            -default => $default_targets_re );
    }
    $targets_re =~ s|^/|| && $targets_re =~ s|/$||;

    my $date = strftime "%Y%m%d_%H_%M_%S", localtime;
    $archive_name = "archived_boot_files" . '_' . $date . '.tgz';

    # Get current kernel release...
    my $current_kernel_release = qx{ uname -r };
    $current_kernel_release =~ s/\s//g;
    $current_kernel_release = normalized_release_num( $current_kernel_release );
    
    # Get bootloader config file location...
    until( defined $bootloader_menu && -f $bootloader_menu ) {
        $bootloader_menu = prompt(
            'Bootloader config file? ',
            -default => '/boot/grub/menu.lst' );
    }

    # Get oldest kernel release version to keep active (older versions will be
    # archived)...
    unless( defined $oldest_kernel_to_keep ) {
        $oldest_kernel_to_keep = prompt(
            'Enter the oldest kernel version number to keep active (all older versions will be archived) ',
            -default => $current_kernel_release );
    }

    $oldest_kernel_to_keep = normalized_release_num( $oldest_kernel_to_keep );

    rel_num_compare( $oldest_kernel_to_keep, $current_kernel_release ) > 0 &&
        warn "WARNING: you have indicated that the currently-running kernel
        version should be archived!\n";

    my @to_archive = boot_files_older_than( $oldest_kernel_to_keep, qr/$targets_re/o );

    if( @to_archive ) {
        # Interactively get confirmation of files to be archived...
        my @confirmed_for_archival;
        if( $verbose ) {
            for( @to_archive ) {
                my $ans = prompt( "Archive $_? ", -default => 'y' );
                push @confirmed_for_archival, $_ if lc $ans eq 'y';
            }
        }
        else {
            @confirmed_for_archival = @to_archive;
        }

        # Option 'verbose' activated => print summary of actions...
        if( $verbose ) {
            print "\n...Preparing to archive old kernel files\n\n";
            print "Current kernel version: $current_kernel_release\n";
            print " Oldest kernel to keep: $oldest_kernel_to_keep\n";
            print "   Destination archive: $archive_dest_dir/$archive_name";
            $delete_originals ? print " (deleting originals)\n" : print "\n";
            print "\n\tFiles to be archived: \n\t"
                . join("\n\t", @confirmed_for_archival), "\n\n";
            print "...Will then update boot loader menu: '$bootloader_menu'\n\n";
            prompt "\n ";
        }

        # Create archive, removing original files...
        archive_files(
            ARCHIVE_NAME    => "$archive_dest_dir/$archive_name",
            DELETE_ORIG     => $delete_originals,
            FILES           => \@confirmed_for_archival,
            DRY_RUN         => $dry_run,
        );

        # Update bootloader menu, removing archived kernels...
        remove_bootldr_stanzas(
            BOOTLDR_CONF        => $bootloader_menu,
            BACKUP_FILENAME     => "$bootloader_menu.$date",
            OLDEST_REL_TO_KEEP  => $oldest_kernel_to_keep,
            DRY_RUN             => $dry_run,
            VERBOSE             => $verbose,
        );
    }
}

#######

sub normalized_release_num {
    my ($name) = @_;

    my ($result) = ( $name =~ /
            (
              \d            # matches must start with a digit...
              [\d\.\-]*     # ...and consist of {digits, dots, hyphens}
            )
        /x
    );
    $result =~ s/^[\.\-]// if $result; # remove leading dots and hyphens
    $result =~ s/[\.\-]$// if $result; # remove trailing dots and hyphens

    return $result || undef;
}

#######

sub rel_num_compare {
    my ($a, $b) = @_;

    return unless ( length $a and length $b );

    # Replace all hyphens with decimals...
    ( my $A = $a ) =~ s/\-/\./g;
    ( my $B = $b ) =~ s/\-/\./g;

    # Separate values into prefix, suffix...
    my ( $a_prefix, $a_suffix ) = ( $A =~ /^(\d+)\.?(.*)/ );
    my ( $b_prefix, $b_suffix ) = ( $B =~ /^(\d+)\.?(.*)/ );

    if( defined $a_prefix && defined $b_prefix && $a_prefix == $b_prefix ) {
        if( length $a_suffix and length $b_suffix ) {
            return rel_num_compare( $a_suffix, $b_suffix)
        }
        else {
            return 0;
        }
    }
    return $a_prefix <=> $b_prefix;
}

#######

sub boot_files_older_than {
    my ($oldest_kernel_to_keep, $targets_re) = (@_);

    opendir( my $dh, '/boot' ) or croak "Error: can't opendir: $!";
    my @to_archive = grep {
        (lc $_) =~ /$targets_re/o &&
        rel_num_compare( normalized_release_num($_), $oldest_kernel_to_keep ) < 0
    } readdir $dh;
    closedir $dh;
    @to_archive = map { "/boot/$_" } @to_archive;

    return @to_archive;
}

#######

sub archive_files {
    my %param = @_;

    my $archive_name =          $param{ARCHIVE_NAME}
        or croak "required param: archive file path";

    my $delete_originals =      $param{DELETE_ORIG};
    my $files =                 $param{FILES}
        or croak "required param: list of files to archive";

    my $dry_run =               $param{DRY_RUN};

    unless( $dry_run ) {
        my $tar = Archive::Tar->new();
        $tar->add_files( @$files ) or croak "Error: cannot add files to archive.";
        $tar->write( $archive_name, 1 ) or croak "Error: cannot write tar archive.";

        if( $delete_originals ) {
            map { unlink $_ } @$files;
        }
    }

    return 1;
}

#######

sub remove_bootldr_stanzas {
    my %param = @_;

    my $bootldr_conf =          $param{BOOTLDR_CONF}
        or croak "required: bootloader configuration file";
    my $backup_filename =       $param{BACKUP_FILENAME};
    my $oldest_kernel_to_keep = $param{OLDEST_REL_TO_KEEP}
        or croak "required: version number representing oldest kernel to keep";

    my $dry_run =               $param{DRY_RUN};
    my $verbose =               $param{VERBOSE};

    $verbose && print "backing up $bootldr_conf -> $backup_filename\n";
    $dry_run || system( "cp", $bootldr_conf, $backup_filename ) == 0
        or croak "Error: can't copy '$bootldr_conf' to '$backup_filename'\n";

    # Read bootloader config...
    my $lbl = Linux::Bootloader->new();
    $lbl->debug(0);
    $lbl->read("$bootldr_conf");
    my @stanzas = $lbl->_info;

    my @indices_of_stanzas_to_remove;
    for my $stanza (@stanzas) {
        # Consider only stanzas with a kernel and a title...
        next unless $stanza->{kernel} && $stanza->{title};

        my $kernel_rel = normalized_release_num( $stanza->{kernel} );
         
        # Remove stanza if it is for a kernel older than the oldest we're
        # keeping active...
        if( rel_num_compare($kernel_rel, $oldest_kernel_to_keep) < 0 ) {

            $verbose && print "removing $stanza->{title}...\n";

            # FIXME: Linux::Bootloader v1.2 has a bug in remove(), making it
            # print confirmation of stanza removal even if its debug setting
            # is 0; avoid its output deliberately...
            local *STDOUT;
            open(STDOUT, ">", "/dev/null");
            $lbl->remove( $stanza->{title} );
            close STDOUT;
        }
    }

    if( $verbose ) {
        print "\nupdated $bootldr_conf:\n\n";
        $lbl->print_info("all");
    }

    $lbl->write() unless $dry_run;
    return 1;
}

#######

__END__

=pod

=head1 NAME

Linux::BootCleanup - clean up old kernel files in /boot and update bootloader
menu entries accordingly


=head1 VERSION

This documentation refers to Linux::BootCleanup version 0.02.


=head1 MODULE: FUNCTIONS

=head2 normalized_release_num

    $rel = normalized_release_num( $file_from_boot_dir );

Extract a release number from strings expected to contain one.  Returns a
release number (see L</"VERSION NUMBER FORMAT">) or undef if string does not
contain anything that looks like a release number.

=head2 rel_num_compare

    $sort_order = rel_num_compare( $a, $b );

Compare release numbers (see L</"VERSION NUMBER FORMAT">), returning -1, 0, or
1 if the first argument is less than, equal to, or greater than, the second.

=head2 boot_files_older_than

    my @to_archive = boot_files_older_than(
        $oldest_kernel_to_keep, qr/$targets_regex/o
    );

Find and return a list of all files in the /boot directory that meet BOTH of
the following criteria:

=over

=item 1.

file is considered to be kernel version-specific

=item 2.

file's version is earlier than a given number

=back

Only files with version numbers earlier than the version number given by the
first parameter (which is assumed to be in a sensible format) will be selected
(criterion #1).  The second parameter is a regex that is used to identify
"target" files -- only files matching this regex meet criterion #2.

=head2 run

"main() method" for running modulino as a command line program.  Parses
command line options, handles flow of control, interactively getting options
not specified on the command line.

=head2 remove_bootldr_stanzas

    remove_bootldr_stanzas(
        BOOTLDR_CONF        => $bootloader_menu_filename,
        BACKUP_FILENAME     => "$bootloader_menu.$date",
        OLDEST_REL_TO_KEEP  => $oldest_kernel_to_keep,
        DRY_RUN             => 1,
        VERBOSE             => 1,
    );

Backup the bootloader menu and remove all kernel stanzas that correspond to a
kernel with a version number older than the specified oldest version to save.

=head2 archive_files

    archive_files(
        ARCHIVE_NAME    => "$archive_dest_dir/$archive_name",
        DELETE_ORIG     => $delete_originals,
        FILES           => \@confirmed_for_archival,
        DRY_RUN         => $dry_run,
    );

Create a tarred and gzipped archive of files in arrayref specified by FILES.
If DELETE_ORIG is a true value, the original files will be deleted.


=head1 PROGRAM: DESCRIPTION

Finds kernel-version-specific files in /boot and prompts for the newest
kernel version whose /boot files are to be kept.  The older /boot files are
compressed and archived.  The bootloader menu is updated accordingly.

To run as a program, invoke the module itself from the command line, e.g.:

    $ perl `perldoc -l Linux::BootCleanup` --help


=head1 PROGRAM: SYNOPSIS

    Linux::BootCleanup modulino: archive old kernel files from /boot directory
    and update bootloader menu...

    Without options, interactively prompts for required information.  Can run
    non-interactively if all options are given.  Configuration files are
    supported and should contain the same arguments used on the command line
    (one per line separated by newlines).  The config file should be named after
    the executable, preceded by a dot.

    options:
        --help                 show this help menu
        --bootldr-config =     <path to boot loader configuration file>
        --archive-dest =       <path to dest dir for archive of old files>
        --targets-re =         <regex that all target filenames must match>
        --oldest-to-keep =     <oldest kernel version to keep active>
        --delete-originals     delete originals after archiving
        --dry-run              pretend, but take no actions
        --verbose              be noisy

    NOTES:
        * The "targets" matched by 'targets-re' are files under /boot to be
          considered for archiving.  Matching files are archived provided they
          meet remaining criteria.  By default, the targets are files
          containing: system.map, vmlinux, vmlinuz, config, initrd


=head1 PROGRAM: REQUIRED ARGUMENTS

None.  Any arguments not supplied via the command line are prompted for interactively.


=head1 PROGRAM: DIAGNOSTICS

=over

=item C<< Error: can't opendir: ... >>

OS Error while trying to open a directory.


=item C<< Error: cannot add files to archive. >>

The list of files specified for archival could not be added to the in-memory
tar archive.  Check to be sure that the files exist.


=item C<< Error: cannot write tar archive. >>

The in-memory tar archive could not be written to disk.  Check to be sure that
the filename you specified can be written.


=item C<< Error: can't copy '<source filename>' to '<dest filename>' >>

Failed attempt to copy a file using system 'cp'.  Check permissions and path
existence.


=back


=head1 VERSION NUMBER FORMAT

Valid version numbers used by this module are of the form 'a.b...c-X.Y...Z'
(e.g. 2.6.17-12).


=head1 DEPENDENCIES

POSIX

Exporter

Getopt::Long

Getopt::ArgvFile

Archive::Tar

IO::Prompt

Linux::Bootloader

Linux::Bootloader::Detect


=head1 INCOMPATIBILITIES

This modulino is intended to be used on Linux platforms only.


=head1 BUGS AND LIMITATIONS

No known bugs.  Please report problems to Karl Erisman
(kerisman@cpan.org).  Patches are welcome.


=head1 ACKNOWLEDGEMENTS

Thanks to the Perl Monks, O'Reilly, Stonehenge, various authors of learning
resources, and last but not least, to CPAN authors everywhere!


=head1 AUTHOR

Karl Erisman (kerisman@cpan.org)


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 Karl Erisman (kerisman@cpan.org), Murray State University.
All rights reserved.

This is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.  See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.


=head1 SCRIPT CATEGORIES

UNIX/System_Administration


=cut

