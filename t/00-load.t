#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Statistics::Sequences::Turns' ) || print "Bail out!\n";
}

diag( "Testing Statistics::Sequences::Turns $Statistics::Sequences::Turns::VERSION, Perl $], $^X" );
