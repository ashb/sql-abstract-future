use strict;
use warnings;
use Test::More;

use SQL::Abstract::Test import => ['is_same_sql_bind'];

#LDNOTE: renamed all "bind" into "where" because that's what they are

my @handle_tests = (
    #2
    {
         args => {},
         stmt => 'SELECT * FROM test WHERE ( a = ? AND b = ? )'
    }
);

plan tests => (1 + scalar(@handle_tests));

use_ok('SQL::Abstract::Compat');

for (@handle_tests) {
  my $sql  = SQL::Abstract::Compat->new($_->{args});
  my $where = $_->{where} || { a => 4, b => 0};
  my($stmt, @bind) = $sql->select('test', '*', $where);


  # LDNOTE: this original test suite from NWIGER did no comparisons
  # on @bind values, just checking if @bind is nonempty.
  # So here we just fake a [1] bind value for the comparison.
  is_same_sql_bind($stmt, [@bind ? 1 : 0], $_->{stmt}, [1]);
}
