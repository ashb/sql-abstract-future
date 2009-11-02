use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use Test::SQL::Abstract::Util qw/
  mk_name
  mk_value
  field_op_value
  :dumper_sort
/;

use SQL::Abstract::Compat;

use Test::More tests => 3;
use Test::Differences;

ok(my $visitor = SQL::Abstract::Compat->new);


eq_or_diff
  $visitor->update_ast('test', { foo => 1 }),
  { -type => 'update',
    tablespec => mk_name('test'),
    columns => [
      mk_name('foo')
    ],
    values => [
      mk_value(1)
    ]
  },
  "simple update";

eq_or_diff
  $visitor->update_ast('test', { foo => 1 }, { id => 2 }),
  { -type => 'update',
    tablespec => mk_name('test'),
    columns => [
      mk_name('foo')
    ],
    values => [
      mk_value(1)
    ],
    where => field_op_value('id' => '==', 2)
  },
  "simple update";





