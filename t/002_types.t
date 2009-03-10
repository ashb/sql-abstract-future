use strict;
use warnings;

use Test::More tests => 7;

use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef/;
use SQL::Abstract::Types ':all';

is(ArrayAST->validate( [ -foo => 'bar' ] ), undef, "is_ArrayAST with valid" );
ok(!is_ArrayAST( [ foo => 'bar' ] ), "is_ArrayAST with invalid" );


is(HashAST->validate( { -type => 'select', select => [] } ), undef, "is_HashAST with valid" );
ok(!is_HashAST( { foo => 'bar' } ), "is_HashAST with invalid" );


is(AST->validate( { -type => 'select', select => [] } ), undef, "is_AST with valid hash" );
is(AST->validate( [ -name => 1, 2 ] ), undef, "is_AST with valid array" );

is(is_AST([ -name => qw/me id/]), 1);
