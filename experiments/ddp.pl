use DDP;  # same as 'use Data::Printer'
 
p $some_var;
p $some_var, as => "This label will be printed too!";
 
# no need to use '\' before arrays or hashes!
p @array;
p %hash;
 
# printing anonymous array references:
p [ $one, $two, $three ]->@*;    # perl 5.24 or later!
p @{[ $one, $two, $three ]};     # same, older perls
&p( [ $one, $two, $three ] );    # same, older perls
 
# printing anonymous hash references:
p { foo => $foo, bar => $bar }->%*;   # perl 5.24 or later!
p %{{ foo => $foo, bar => $bar }};    # same, older perls
&p( { foo => $foo, bar => $bar } );   # same, older perls
