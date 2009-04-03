BEGIN {
  require Data::Dumper;
  my $Dump = Data::Dumper->can('Dump');

  no warnings 'redefine';

  *Data::Dumper::Dump = sub {
    local $Data::Dumper::Sortkeys = sub {
      my $hash = @_[0];
      my @keys = sort { 
        my $a_minus = substr($a,0,1) eq '-';
        my $b_minus = substr($b,0,1) eq '-';

        return $a cmp $b if $a_minus || $b_minus;

        return -1 if $a eq 'op';
        return  1 if $b eq 'op';
        return $a cmp $b;
      } keys %$hash;

      return \@keys;
    };
    return $Dump->(@_);
  };
}

1;
