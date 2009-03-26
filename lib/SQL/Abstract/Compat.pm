use MooseX::Declare;

class SQL::Abstract::Compat {

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/Str ScalarRef ArrayRef HashRef/;
  use MooseX::Types -declare => [qw/LogicEnum WhereType/];

  enum LogicEnum, qw(OR AND);

  subtype WhereType, as Str;

  clean;

  has logic => (
    is => 'rw',
    isa => LogicEnum,
    default => 'AND'
  );



  method select(Str|ArrayRef|ScalarRef $from, ArrayRef|Str $fields,
                Str|ScalarRef|ArrayRef|HashRef $where?,
                Str|ScalarRef|ArrayRef|HashRef $order?) {
    return ("", );
  }

  method where(Str|ScalarRef|ArrayRef|HashRef $where,
               Str|ScalarRef|ArrayRef|HashRef $order?) {

    my $ast = {
      -type => 'expr',
    };
  }

  method recurse_where(LogicEsnum $where) {
    
  }

}

=head1 NAME

SQL::Abstract::Compant - compatibility layer for SQL::Abstrct v 1.xx

=head1 DESCRIPTION

This class attempts to maintain the original behaviour of version 1 of
SQL::Abstract. It does this by internally converting to an AST and then using
the standard AST visitor.

If so desired, you can get hold of this transformed AST somehow. This is aimed
at libraries such as L<DBIx::Class> that use SQL::Abstract-style arrays or
hashes as part of their public interface.

=head1 AUTHOR

Ash Berlin C<< <ash@cpan.org> >>

=cut

1;
