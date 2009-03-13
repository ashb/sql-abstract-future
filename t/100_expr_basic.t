use strict;
use warnings;

use Test::More tests => 13;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  { -type => 'expr',
    op => '>',
    args => [
      {-type => name => args => [qw/me id/] }, 
      { -type => 'value', value => 500 }
    ]
  }
), "me.id > ?", 
   "simple expr clause";

is $sqla->dispatch(
  { -type => 'expr',
    op => '>',
    args => [
      {-type => 'name', args => [qw/me id/]}, 
      {-type => 'value', value => 500 }
    ]
  }
), "me.id > ?", 
   "simple expr clause";

my $cols = [
  { -type => 'expr',
    op => '>',
    args => [
      {-type => 'name', args => [qw/me id/]}, 
      {-type => 'value', value => 500 }
    ]
  },
  { -type => 'expr',
    op => '==',
    args => [
      {-type => 'name', args => [qw/me name/]}, 
      {-type => 'value', value => '200' }
    ]
  },
];

eq_or_diff( [ SQL::Abstract->generate(
    { -ast_version => 1,
      -type => 'expr',
      op => 'and',
      args => $cols,
    }
  ) ], 
  [ "me.id > ? AND me.name = ?",
    [ 500,
      '200'
    ]
  ],
  "Where with binds"
);


is $sqla->dispatch(
  { -type => 'expr',  op => 'or', args => $cols }
), "me.id > ? OR me.name = ?", 
   "expr clause (simple or)";


is $sqla->dispatch(
  { -type => 'expr', op => 'or',
    args => [
      { -type => 'expr', op => '==', 
        args => [ {-type => 'name', args => [qw/me name/] }, {-type => 'value', value => 500 } ]
      },
      { -type => 'expr', op => 'or', args => $cols }
    ]
  }
), "me.name = ? OR me.id > ? OR me.name = ?",
   "expr clause (nested or)";

is $sqla->dispatch(
  { -type => 'expr', op => 'or',
    args => [
      { -type => 'expr', op => '==', 
        args => [ {-type => 'name', args => [qw/me name/] }, {-type => 'value', value => 500 } ]
      },
      { -type => 'expr', op => 'and', args => $cols }
    ]
  }
), "me.name = ? OR me.id > ? AND me.name = ?", 
   "expr clause (inner and)";

is $sqla->dispatch(
  { -type => 'expr', op => 'and', args => [
      { -type => 'expr', op => '==', args => [
          {-type => 'name', args => [qw/me id/] }, {-type => 'value', value => 200 } 
        ],
      },
      { -type => 'expr', op => 'and', args => $cols }
    ]
  }
), "me.id = ? AND me.id > ? AND me.name = ?", 
   "expr clause (nested and)";


is $sqla->dispatch(
  { -type => 'expr', op => 'and', args => [
      { -type => 'expr', op => '==', args => [
          {-type => 'name', args => [qw/me id/] }, {-type => 'value', value => 200 } 
        ],
      },
      { -type => 'expr', op => 'or', args => $cols }
    ]
  }
), "me.id = ? AND (me.id > ? OR me.name = ?)",
   "expr clause (inner or)";

is $sqla->dispatch(
  { -type => 'expr', op => 'in', args => [  ] }
), "0 = 1", "emtpy -in";

is $sqla->dispatch(
  { -type => 'expr', 
    op => 'in', 
    args => [ { -type => 'name', args => ['foo'] } ],
  }
), "0 = 1", "emtpy -in";

eq_or_diff(
  [SQL::Abstract->generate(
    { -ast_version => 1,
      -type => 'expr',
      op => 'and',
      args => [
        { -type => 'expr',
          op => 'in',
          args => [
            {-type => 'name', args => [qw/me id/] },
            {-type => 'value', value => 100 },
            {-type => 'value', value => 200 },
            {-type => 'value', value => 300 },
          ]
        }
      ]
    }
  ) ],

  [ "me.id IN (?, ?, ?)", 
    [ 100, 200, 300 ]
  ],
  
  "IN expression");

eq_or_diff(
  [SQL::Abstract->generate(
    { -ast_version => 1,
      -type => 'expr',
      op => 'and',
      args => [
        { -type => 'expr',
          op => 'not_in',
          args => [
            {-type => 'name', args => [qw/me id/] },
            {-type => 'value', value => 100 },
            {-type => 'value', value => 200 },
            {-type => 'value', value => 300 },
          ]
        }
      ]
    }
  ) ],

  [ "me.id NOT IN (?, ?, ?)", 
    [ 100, 200, 300 ]
  ],
  
  "NOT IN clause");
