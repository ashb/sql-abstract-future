use MooseX::Declare;

class SQL::Abstract::AST::v1 extends SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef/;
  use MooseX::AttributeHelpers;
  use SQL::Abstract::Types qw/AST/;
  use Devel::PartialDump qw/dump/;

  clean;

  # set things that are valid in where clauses
  override _build_expr_dispatch_table {
    return { 
      %{super()},
      in => $self->can('_in'),
      not_in => $self->can('_in'),
      and => $self->can('_recurse_where'),
      or => $self->can('_recurse_where'),
      map { +"$_" => $self->can("_$_") } qw/
        value
        name
        true
        false
        expr
      /
    };
  }

  method _select(AST $ast) {
    # Default to requiring columns and from.
    # DB specific ones (i.e. mysql/Pg) can not require the FROM part with a bit
    # of refactoring
    
    for (qw/columns tablespec/) {
      confess "'$_' is required in select AST with " . dump ($ast)
        unless exists $ast->{$_};
    }
   
    # Check that columns is a -list
    confess "'columns' should be an array ref, not " . dump($ast->{columns})
      unless is_ArrayRef($ast->{columns});

    my $cols = $self->_list({-type => 'list', args => $ast->{columns} });

    my @output = (
      SELECT => $cols
    );

    push @output, FROM => $self->dispatch($ast->{tablespec})
      if exists $ast->{tablespec};

    if (exists $ast->{where}) {
      my $sub_ast = $ast->{where};

      confess "$_ option is not an AST: " . dump($sub_ast)
        unless is_AST($sub_ast);

      push @output, "WHERE", $self->_expr($sub_ast);
    }

    for (qw/group_by having order_by/) {
      if (exists $ast->{$_}) {
        my $sub_ast = $ast->{$_};

        confess "$_ option is not an AST or an ArrayRef: " . dump($sub_ast)
          unless is_AST($sub_ast) || is_ArrayRef($sub_ast);;

        my $meth = "__$_";
        push @output, $self->$meth($sub_ast);
      }
    }

    return join(' ', @output);
  }

  method _join(HashRef $ast) {

    # TODO: Validate join type
    my $type = $ast->{join_type} || "";
  
    my @output = $self->dispatch($ast->{lhs});

    push @output, uc $type if $type;
    push @output, "JOIN", $self->dispatch($ast->{rhs});

    push @output, 
        exists $ast->{on}
      ? ('ON', '(' . $self->_expr( $ast->{on} ) . ')' )
      : ('USING', '(' .$self->dispatch($ast->{using} 
                        || croak "No 'on' or 'uinsg' clause passed to join cluase: " .
                                 dump($ast) 
                        ) .
                  ')' );

    return join(" ", @output);
      
  }

  method _ordering(AST $ast) {
 
    my $output = $self->_expr($ast->{expr});

    $output .= " " . uc $1
      if $ast->{direction} && 
         ( $ast->{direction} =~ /^(asc|desc)$/i 
           || confess "Unknown ordering direction " . dump($ast)
         );

    return $output;
  }

  method _name(AST $ast) {
    my @names = @{$ast->{args}};

    my $sep = $self->name_separator;
    my $quote = $self->is_quoting 
              ? $self->quote_chars
              : [ '' ];

    my $join = $quote->[-1] . $sep . $quote->[0];

    # We dont want to quote * in [qw/me */]: `me`.* is the desired output there
    # This means you can't have a field called `*`. I am willing to accept this
    # situation, cos thats a really stupid thing to want.
    my $post;
    $post = pop @names if $names[-1] eq '*';

    my $ret;
    $ret = $quote->[0] . 
           join( $join, @names ) . 
           $quote->[-1]
      if @names;

    $ret = $ret 
         ? $ret . $sep . $post
         : $post
      if defined $post;


    return $ret;
  }


  method _list(AST $ast) {
    return "" unless $ast->{args};

    my @items = is_ArrayRef($ast->{args})
              ? @{$ast->{args}}
              : $ast->{args};

    return join(
      $self->list_separator,
      map { $self->dispatch($_) } @items);
  }

  # TODO: I think i want to parameterized AST type to get better validation
  method _alias(AST $ast) {
    
    # TODO: Maybe we want qq{ AS "$as"} here
    return $self->dispatch($ast->{ident}) . " AS " . $ast->{as};

  }

  method _value(AST $ast) {

    $self->add_bind($ast->{value});
    return "?";
  }

  # Not dispatchable to.
  method __having($args) {
    return "HAVING " . $self->_list({-type => 'list', args => $args});
  }

  method __group_by($args) {
    return "GROUP BY " . $self->_list({-type => 'list', args => $args});
  }

  method __order_by($args) {
    return "ORDER BY " . $self->_list({-type => 'list', args => $args});
  }


  # Perhaps badly named. handles 'and' and 'or' clauses
  method _recurse_where(AST $ast) {

    my $op = $ast->{op};

    my $OP = uc $op;
    my $prio = $SQL::Abstract::PRIO{$op};

    my $dispatch_table = $self->expr_dispatch_table;

    my @output;
    foreach ( @{$ast->{args}} ) {
      croak "invalid component in where clause: $_" unless is_AST($_);

      if ($_->{-type} eq 'expr' && $_->{op} =~ /^(and|or)$/) {
        my $sub_prio = $SQL::Abstract::PRIO{$1}; 

        if ($sub_prio <= $prio) {
          push @output, $self->_recurse_where($_);
        } else {
          push @output, '(' . $self->_recurse_where($_) . ')';
        }
      } else {
        push @output, $self->_expr($_);
      }
    }

    return join(" $OP ", @output);
  }

  method _expr(AST $ast) {
    my $op = $ast->{-type};

    $op = $ast->{op} if $op eq 'expr';

    if (my $code = $self->lookup_expr_dispatch($op)) { 
      
      return $code->($self, $ast);

    }
    croak "'$op' is not a valid AST type in an expression with " . dump($ast)
      if $ast->{-type} ne 'expr';

    # This is an attempt to do some form of validation on function names. This
    # might end up being a bad thing.
    croak "'$op' is not a valid operator in an expression with " . dump($ast)
      if $op =~ /\W/;

    return $self->_generic_function_op($ast);
   
  }

  method _binop(AST $ast) {
    my ($lhs, $rhs) = @{$ast->{args}};
    my $op = $ast->{op};

    join (' ', $self->_expr($lhs), 
               $self->binop_mapping($op) || croak("Unknown binary operator $op"),
               $self->_expr($rhs)
    );
  }

  method _generic_function_op(AST $ast) {
    my $op = $ast->{op};

    return "$op(" . $self->_list($ast) . ")";
  }

  method _in(AST $ast) {
  
    my ($field,@values) = @{$ast->{args}};

    my $not = ($ast->{op} =~ /^not_/) ? " NOT" : "";

    return $self->_false unless @values;

    return $self->_expr($field) .
           $not . 
           " IN (" .
           join(", ", map { $self->dispatch($_) } @values ) .
           ")";
  }

  # 'constants' that are portable across DBs
  method _false($ast?) { "0 = 1" }
  method _true($ast?) { "1 = 1" }

}
