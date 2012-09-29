use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Statistics::Sequences::Turns',
    license             => 'perl',
    dist_author         => q{Roderick Garton <rgarton@cpan.org>},
    dist_version_from   => 'lib/Statistics/Sequences/Turns.pm',
    build_requires => {
        'Test::More' => 0,
        'Scalar::Util' => '1.23',
        'Statistics::Sequences' => '0.051',
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'Statistics-Sequences-Turns-0.04-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
