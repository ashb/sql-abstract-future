use MooseX::Declare;

class SQL::Abstract::AST::v1 extends SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef/;
  use MooseX::AttributeHelpers;
  use SQL::Abstract::Types qw/AST ArrayAST HashAST/;

  clean;

  # set things that are valid in where clauses
  override _build_where_dispatch_table {
    return { 
      %{super()},
      -in => $self->can('_in'),
      -not_in => $self->can('_in'),
      map { +"-$_" => $self->can("_$_") } qw/
        value
        name
        true
        false
      /
    };
  }

  method _select(HashAST $ast) {
    
  }

  method _where(ArrayAST $ast) {
    my (undef, @clauses) = @$ast;
  
    return 'WHERE ' . $self->_recurse_where(\@clauses);
  }

  method _order_by(ArrayAST $ast) {
    my (undef, @clauses) = @$ast;

    my @output;
   
    for (@clauses) {
      if ($_->[0] =~ /^-(asc|desc)$/) {
        my $o = $1;
        push @output, $self->dispatch($_->[1]) . " " . uc($o);
        next;
      }
      push @output, $self->dispatch($_);
    }

    return "ORDER BY " . join(", ", @output);
  }

  method _name(ArrayAST $ast) {
    my (undef, @names) = @$ast;

    my $sep = $self->name_separator;

    return $sep->[0] . 
           join( $sep->[1] . $sep->[0], @names ) . 
           $sep->[1]
              if (@$sep > 1);

    return join($sep->[0], @names);
  }

  method _join(HashAST $ast) {
  
    my $output = 'JOIN ' . $self->dispatch($ast->{tablespec});

    $output .= exists $ast->{on}
             ? ' ON (' . $self->_recurse_where( $ast->{on} )
             : ' USING (' .$self->dispatch($ast->{using} || croak "No 'on' or 'join' clause passed to -join");

    $output .= ")";
    return $output;
      
  }

  method _list(ArrayAST $ast) {
    my (undef, @items) = @$ast;

    return join(
      $self->list_separator,
      map { $self->dispatch($_) } @items);
  }

  method _alias(ArrayAST $ast) {
    my (undef, $alias, $as) = @$ast;

    return $self->dispatch($alias) . " AS $as";

  }

  method _value(ArrayAST $ast) {
    my ($undef, $value) = @$ast;

    $self->add_bind($value);
    return "?";
  }

  method _recurse_where(ArrayRef $clauses) {

    my $OP = 'AND';
    my $prio = $SQL::Abstract::PRIO{and};
    my $first = $clauses->[0];

    if (!ref $first) {
      if ($first =~ /^-(and|or)$/) {
        $OP = uc($1);
        $prio = $SQL::Abstract::PRIO{$1};
        shift @$clauses;
      } else {
        # If first is not a ref, and its not -and or -or, then $clauses
        # contains just a single clause
        $clauses = [ $clauses ];
      }
    }

    my $dispatch_table = $self->where_dispatch_table;

    my @output;
    foreach (@$clauses) {
      croak "invalid component in where clause: $_" unless is_ArrayRef($_);
      my $op = $_->[0];

      if ($op =~ /^-(and|or)$/) {
        my $sub_prio = $SQL::Abstract::PRIO{$1}; 

        if ($sub_prio <= $prio) {
          push @output, $self->_recurse_where($_);
        } else {
          push @output, '(' . $self->_recurse_where($_) . ')';
        }
      } else {
        push @output, $self->_where_component($_);
      }
    }

    return join(" $OP ", @output);
  }

  method _where_component(ArrayRef $ast) {
    my $op = $ast->[0];

    if (my $code = $self->lookup_where_dispatch($op)) { 
      
      return $code->($self, $ast);

    }
    croak "'$op' is not a valid clause in a where AST"
      if $op =~ /^-/;

    croak "'$op' is not a valid operator";
   
  }


  method _binop(ArrayRef $ast) {
    my ($op, $lhs, $rhs) = @$ast;

    join (' ', $self->_where_component($lhs), 
               $self->binop_mapping($op) || croak("Unknown binary operator $op"),
               $self->_where_component($rhs)
    );
  }

  method _in(ArrayAST $ast) {
    my ($tag, $field, @values) = @$ast;

    my $not = $tag =~ /^-not/ ? " NOT" : "";

    return $self->_false if @values == 0;
    return $self->_where_component($field) .
           $not. 
           " IN (" .
           join(", ", map { $self->dispatch($_) } @values ) .
           ")";
  }

  method _generic_func(ArrayRef $ast) {
  }

  # 'constants' that are portable across DBs
  method _false($ast?) { "0 = 1" }
  method _true($ast?) { "1 = 1" }

}
