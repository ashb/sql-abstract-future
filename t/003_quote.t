use strict;
use warnings;
 
use Test::More tests => 2;
use Test::Exception;
 
use_ok('SQL::Abstract') or BAIL_OUT( "$@" );
 
my $sqla = SQL::Abstract->create(1);

lives_ok {
  $sqla->quote_chars('[]');
} "coercion of quote_chars from Str works";
