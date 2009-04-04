use strict;
use warnings;

use Test::More tests => 4;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);


is $sqla->dispatch(
  { -type => 'ordering', expr => { -type => identifier => elements => [qw/me date/ ] } }
), "me.date",
   "basic ordering";

is $sqla->dispatch(
  { -type => 'ordering', 
    expr => { -type => identifier => elements => [qw/me date/] },
    direction => 'DESC'
  }
), "me.date DESC",
   "desc ordering";


is $sqla->dispatch(
  { -type => 'ordering', 
    expr => { -type => identifier => elements => [qw/me date/] },
    direction => 'asc'
  }
), "me.date ASC",
   "asc ordering";
