use strict;
use warnings;

use Test::More tests => 2;
use Test::Differences;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::SQL::Abstract::Util qw/
  mk_name
  mk_value
  mk_alias
  mk_expr
  :dumper_sort
/;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  { -type => 'update',
    tablespec => mk_name('test'),
    columns => [
      mk_name(qw/me id/),
      mk_name(qw/hostname/),
    ],
    values => [
      mk_expr('+', mk_name(qw/me id/), mk_value(5)),
      mk_value('localhost'),
    ]
  }
), "UPDATE test SET me.id = me.id + ?, hostname = ?",
   "update clause";
