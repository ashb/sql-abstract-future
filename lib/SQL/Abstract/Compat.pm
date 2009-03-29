use MooseX::Declare;

class SQL::Abstract::Compat {

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/Str ScalarRef ArrayRef HashRef/;
  use SQL::Abstract::Types::Compat ':all';
  use SQL::Abstract::AST::Compat;
  use SQL::Abstract::AST::v1;
  use Data::Dump qw/pp/;

  class_type 'SQL::Abstract';
  clean;

  has logic => (
    is => 'rw',
    isa => LogicEnum,
    default => 'AND'
  );

  has visitor => (
    is => 'rw',
    isa => 'SQL::Abstract',
    clearer => 'clear_visitor',
    lazy => 1,
    builder => '_build_visitor',
  );


  method select(Str|ArrayRef|ScalarRef $from, ArrayRef|Str $fields,
                WhereType $where?,
                WhereType $order?)
  {

    my $ast = $self->_new_compat_ast->select($from,$fields,$where,$order);
    pp($ast);

    return ($self->visitor->dispatch($ast), $self->visitor->binds);
  }

  method where(WhereType $where,
               WhereType $order?)
  {
    my $ret = "";
 
    if ($where) {
      my $ast = $self->_new_compat_ast->generate($where);
      $ret .= "WHERE " . $self->visitor->_expr($ast);
    }

    return $ret;
  }

  #TODO: Handle logic and similar args later
  method _new_compat_ast() {
    return SQL::Abstract::AST::Compat->new;
  }

  method _build_visitor() {
    return SQL::Abstract->create(1);
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
