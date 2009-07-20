use MooseX::Declare;

class SQL::Abstract::Compat {

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/Str ScalarRef ArrayRef HashRef/;
  use SQL::Abstract::Types::Compat ':all';
  use SQL::Abstract::Types qw/AST NameSeparator QuoteChars/;
  use SQL::Abstract::AST::v1;
  use Data::Dump qw/pp/;
  use Devel::PartialDump qw/dump/;
  use Carp qw/croak/;

  class_type 'SQL::Abstract';

  has logic => (
    is => 'rw',
    isa => LogicEnum,
    default => 'AND',
    coerce => 1,
    required => 1,
  );

  has visitor => (
    is => 'rw',
    isa => 'SQL::Abstract',
    clearer => 'clear_visitor',
    lazy => 1,
    builder => '_build_visitor',
  );

  has cmp => (
    is => 'rw',
    isa => 'Str',
    default => '=',
    required => 1,
  );

  our %CMP_MAP = (
    '=' => '==',
  );

  has convert => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_field_convertor'
  );

  # TODO: a metaclass trait to automatically use this on vistior construction
  has quote_char => (
    is => 'rw',
    isa => QuoteChars,
    coerce => 1,
    predicate => "has_quote_chars"
  );

  has name_sep => (
    is => 'rw',
    isa => NameSeparator,
    predicate => "has_name_sep"
  );

  method _build_visitor() {
    my %args = (
      ast_version => 1
    );
    $args{quote_chars} = $self->quote_char
      if $self->has_quote_chars;
    $args{ident_separator} = $self->name_sep
      if $self->has_name_sep;

    # TODO: this needs improving along with SQL::A::create
    my $visitor = SQL::Abstract::AST::v1->new(%args);
  } 

  method select(Str|ArrayRef|ScalarRef $from, ArrayRef|Str $fields,
                WhereType $where?,
                WhereType $order?)
  {
    my $ast = $self->select_ast($from,$fields,$where,$order);

    return ($self->visitor->dispatch($ast), @{$self->visitor->binds});
  }

  method update(Str|ArrayRef|ScalarRef $from,   
                HashRef $fields, WhereType $where? )
  {
    my $ast = $self->update_ast($from,$fields,$where);

    return ($self->visitor->dispatch($ast), @{$self->visitor->binds});
  }

  method update_ast(Str|ArrayRef|ScalarRef $from,   
                    HashRef $fields, WhereType $where? ) 
  {
    my (@columns, @values);
    my $ast = {
      -type => 'update',
      tablespec => $self->tablespec($from),
      columns => \@columns,
      values => \@values
    };

    for (keys %$fields) {
      push @columns, $self->mk_name(0, $_);
      push @values, { -type => 'value', value => $fields->{$_} };
    }

    $ast->{where} = $self->recurse_where($where)
      if defined $where;

    return $ast;
  }

  method select_ast(Str|ArrayRef|ScalarRef $from, ArrayRef|Str $fields,
                WhereType $where?,
                WhereType $order?)
  {
    my $ast = {
      -type => 'select',
      columns => [ 
        map {
          $self->mk_name(0, $_)
        } ( is_Str($fields) ? $fields : @$fields )
      ],
      tablespec => $self->tablespec($from)
    };


    $ast->{where} = $self->recurse_where($where)
      if defined $where;

    if (defined $order) {
      my @order = is_ArrayRef($order) ? @$order : $order;
      $ast->{order_by} = [ map { $self->mk_name(0, $_) } @order ];
    }

    return $ast;
  }

  method where(WhereType $where,
               WhereType $order?)
  {
    my $ret = "";
 
    if ($where) {
      my $ast = $self->recurse_where($where);
      $ret .= "WHERE " . $self->visitor->_expr($ast);
    }

    return $ret;
  }


  # method mk_name(Bool $use_convert, Str @names) {
  sub mk_name {
    my ($self, $use_convert, @names) = @_;

    @names = split /\Q@{[$self->name_sep]}\E/, $names[0]
      if (@names == 1 && $self->has_name_sep);

    my $ast = { -type => 'identifier', elements => [ @names ] };

    return $ast
      unless $use_convert && $self->has_field_convertor;

    return $self->apply_convert($ast);
  }

  method tablespec(Str|ArrayRef|ScalarRef $from) {
    return $self->mk_name(0, $from)
      if is_Str($from);

    return {
      -type => 'list',
      args => [ map {
        $self->mk_name(0, $_)
      } @$from ]
    };
  }

  method recurse_where(WhereType $ast, LogicEnum $logic?) {
    return $self->recurse_where_hash($logic || 'AND', $ast) if is_HashRef($ast);
    return $self->recurse_where_array($logic || 'OR', $ast) if is_ArrayRef($ast);
    croak "Unknown where clause type " . dump($ast);
  }

  # Deals with where({ .... }) case
  method recurse_where_hash(LogicEnum $logic, HashRef $ast) {
    my @args;
    my $ret = {
      -type => 'expr',
      op => lc $logic,
      args => \@args
    };

    for my $key ( sort keys %$ast ) {
      my $value = $ast->{$key};

      if ($key =~ /^-(or|and)$/) {
        my $val = $self->recurse_where($value, uc $1);
        if ($val->{op} eq $ret->{op}) {
          push @args, @{$val->{args}};
        }
        else {
          push @args, $val;
        }
        next;
      }

      push @args, $self->field($key, $value);
    }

    return $args[0] if @args == 1;

    return $ret;
  }

  # Deals with where([ .... ]) case
  method recurse_where_array(LogicEnum $logic, ArrayRef $ast) {
    my @args;
    my $ret = {
      -type => 'expr',
      op => lc $logic,
      args => \@args
    };
    my @nodes = @$ast;

    while (my $key = shift @nodes) {
      if ($key =~ /^-(or|and)$/) {
        my $value = shift @nodes
          or confess "missing value after $key at " . dump($ast);

        my $val = $self->recurse_where($value, uc $1);
        if ($val->{op} eq $ret->{op}) {
          push @args, @{$val->{args}};
        }
        else {
          push @args, $val;
        }
        next;
      }

      push @args, $self->recurse_where($key);
    }

    return $args[0] if @args == 1;

    return $ret;
  }

  # { field => { .... } } case
  method field_hash(Str $key, HashRef $value) {
    my ($op, @rest) = keys %$value;

    confess "Don't know how to handle " . dump($value) . " (too many keys)"
      if @rest;

    $value = $value->{$op};

    my $ret = {
      -type => 'expr',
      op => $op,
      args => [
        $self->mk_name(1, $key)
      ],
    };
    $ret->{op} = $op;

    # TODO: Validate the op?
    # 'word_like' operator
    if ($op =~ /^-?(?:(not)[_ ])?([a-z_]+)$/i) {
      $ret->{op} = lc $2;
      $ret->{op} = "not_" . $ret->{op} if $1;


      if (is_ArrayRef($value)) {
        push @{$ret->{args}}, $self->value($_) for @{$value};
        return $ret;
      }
    }
  
    # Cases like:
    #   field => { '!=' =>  [ 'a','b','c'] }
    #   field => { '<' =>  [ 'a','b','c'] }
    #
    # *not* when op is a work or function operator - basic cmp operator only  
    if (is_ArrayRef($value)) {
      local $self->{cmp} = $op;

      my $ast = {
        -type => 'expr',
        op => 'or',
        args => [ map {
          $self->field($key, $_)
        } @{$value} ]
      };
      return $ast;
    }

    
    push @{$ret->{args}}, $self->value($value);
    return $ret;
  }

  # Handle [ { ... }, { ... } ]
  method field_array(Str $key, ArrayRef $value) {
    # Return an or clause, sort of.
    return {
      -type => 'expr',
      op => 'or',
      args => [ map {
          $self->field($key, $_)
      } @$value ]
    };
  }

  method field(Str $key, $value) {

    if (is_HashRef($value)) {
      return $self->field_hash($key, $value);
    }
    elsif (is_ArrayRef($value)) {
      return $self->field_array($key, $value);
    }

    my $ret = {
      -type => 'expr',
      op => $CMP_MAP{$self->cmp} || $self->cmp,
      args => [
        $self->mk_name(1, $key),
        $self->value($value)
      ],
    };

    return $ret;
  }

  method value($value) {
    return $self->apply_convert( { -type => 'value', value => $value })
      if is_Str($value);

    confess "Don't know how to handle terminal value " . dump($value);
  }

  method apply_convert(AST $ast) {
    return $ast unless $self->has_field_convertor;

    return {
      -type => 'expr',
      op => $self->convert,
      args => [ $ast ]
    };
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
