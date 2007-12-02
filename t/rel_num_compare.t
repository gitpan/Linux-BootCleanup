#
# Test release number comparison function...
#
use strict;
use Test::More tests => 12;

use constant SAME_ORDER => 0;
use constant A_BEFORE_B => -1;
use constant A_AFTER_B  => 1;

use Linux::BootCleanup qw( rel_num_compare );

#~~~~ ((( begin test initialization ))) ~~~~
my @same_order = (
    ['5',               '5'],
    ['0.0-00',          '0.0-00'],
);
my @a_before_b = (
    ['4',               '5'],
    ['0.0-08',          '0.0-09'],
    ['0.0-08',          '0.0-088'],
    ['2.6.9-55',        '2.6.9-55.0.12'],
);
my @a_after_b = (
    ['0.0-09',          '0.0-08'],
    ['0.0-088',         '0.0-08'],
    ['5',               '4'],
    ['0.5',             '0.4'],
    ['0.5.9',           '0.4.9'],
    ['2.6.9-55.0.12',   '2.6.9-55'],
);
#~~~~ ((( end test initialization ))) ~~~~

map {
    my ($a, $b) = (@$_);
    is( rel_num_compare($a, $b), SAME_ORDER, "$a and $b should have same sort order" );
} @same_order;

map {
    my ($a, $b) = (@$_);
    is( rel_num_compare($a, $b), A_BEFORE_B, "$a comes before $b" );
} @a_before_b;

map {
    my ($a, $b) = (@$_);
    is( rel_num_compare($a, $b), A_AFTER_B, "$a comes after $b" );
} @a_after_b;
