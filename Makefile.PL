use strict;
use warnings;
use ExtUtils::MakeMaker;

die "OS unsupported\n" unless $^O =~ /linux/i;

WriteMakefile(
    NAME                => 'Linux::BootCleanup',
    AUTHOR              => 'Karl Erisman <kerisman@cpan.org>',
    VERSION_FROM        => 'lib/Linux/BootCleanup.pm',
    ABSTRACT_FROM       => 'lib/Linux/BootCleanup.pm',
    EXE_FILES           => [ qw( bin/bootcleanup ) ],
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'POSIX' => 0,
        'Exporter' => 0,
        'ExtUtils::Installed' => 0,
        'Pod::Usage' => 1.33,
        'Getopt::Long' => 0,
        'Getopt::ArgvFile' => 0,
        'Archive::Tar' => 0,
        'IO::Prompt' => 0,
        'Linux::Bootloader' => 0,
        'Linux::Bootloader::Detect' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Linux-BootCleanup-*' },
);
