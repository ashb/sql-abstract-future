use MooseX::Declare;

class SQL::Abstract::Types::Compat is dirty {
  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef ScalarRef/;

  clean;

  use MooseX::Types -declare => [qw/LogicEnum WhereType/];

  enum LogicEnum, qw(OR AND);

  coerce LogicEnum, from Str, via { uc $_ };

  subtype WhereType, as Str|ArrayRef|HashRef|ScalarRef;
}
