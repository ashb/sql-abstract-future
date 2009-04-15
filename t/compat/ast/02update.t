use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use Test::SQL::Abstract::Util qw/
  mk_name
  mk_value
  mk_expr
  field_op_value
  :dumper_sort
/;

use SQL::Abstract::Compat;

use Test::More tests => 2;
use Test::Differences;

ok(my $visitor = SQL::Abstract::Compat->new);


my $foo_id = { -type => 'identifier', elements => [qw/foo/] };
my $bar_id = { -type => 'identifier', elements => [qw/bar/] };

my $foo_eq_1 = field_op_value($foo_id, '==', 1);
my $bar_eq_str = field_op_value($bar_id, '==', 'some str');

local $TODO = 'Work out what this should be';
eq_or_diff
  $visitor->update_ast('test', { foo => 1 }),
  { -type => 'update',
    tablespec => mk_name('test'),

  },
  "simple update";



