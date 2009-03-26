use strict;
use warnings;

use Test::More tests => 3;

use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef/;
use SQL::Abstract::Types ':all';

is(AST->validate( { -type => 'select', select => [] } ), undef, "is_AST with valid" );
ok(!is_AST( { foo => 'bar' } ), "is_AST with invalid" );

is(AST->validate( { -type => 'select', select => [] } ), undef, "is_AST with valid hash" );

