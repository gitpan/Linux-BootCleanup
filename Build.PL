use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Linux::BootCleanup',
    license             => 'perl',
    dist_author         => 'Karl Erisman <karl.erisman@gmail.com>',
    dist_version_from   => 'lib/Linux/BootCleanup.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Linux-BootCleanup-*' ],
);

$builder->create_build_script();
