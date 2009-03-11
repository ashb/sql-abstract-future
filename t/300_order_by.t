use strict;
use warnings;

use Test::More tests => 4;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);


is $sqla->dispatch(
  { -type => 'order_by', order_by => [ { -type => name => args => [qw/me date/ ] } ] }
), "ORDER BY me.date",
   "order by";

is $sqla->dispatch(
  { -type => 'order_by',
    order_by => [
      { -type => name => args => [qw/me date/] },
      { -type => name => args => [qw/me foobar/] },
    ]
  }
), "ORDER BY me.date, me.foobar",
   "order by";

# Hrmmm how to mark this up.
is $sqla->dispatch(
  { -type => 'order_by', 
    order_by => [
      [ -desc => { -type => name => args => [qw/me date/ ] } ] 
    ] 
  }
), "ORDER BY me.date DESC",
   "order by desc";
