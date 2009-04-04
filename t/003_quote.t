use strict;
use warnings;
 
use Test::More tests => 5;
use Test::Exception;
 
use_ok('SQL::Abstract') or BAIL_OUT( "$@" );
 
my $sqla = SQL::Abstract->create(1);

lives_ok {
  $sqla->quote_chars('[]');
} "coercion of quote_chars from Str works";


is $sqla->dispatch( { -type => 'identifier', elements => [qw/me id/] }), 
   "[me].[id]",
   "me.id";


is $sqla->dispatch( { -type => 'identifier', elements => [qw/me */] }), 
   "[me].*",
   "me.*";


is $sqla->dispatch( { -type => 'identifier', elements => [qw/*/] }), 
   "*",
   "*";
