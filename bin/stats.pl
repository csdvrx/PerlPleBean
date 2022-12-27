#!/usr/bin/perl
# Catching outliers, by csdvrx 2019, 2022
################################################################
# step 0: declarations

### Includes
## Modern perl
use v5.14;                      # for /r match+assign on regexp and ~~ smartmatch
use strict;
use warnings;
use open qw(:std);              # should use unicode, but (:std :utf8) gives mojibake

## Minimalistic set of dependancies: must not come from CPAN for portability
use Data::Dumper;               # for cheap debug, always present by default

# min, max of arrays
use List::Util qw( min max );

# ceil, floor
use POSIX;

# statistics
use Statistics::Descriptive::Weighted;
use Statistics::Descriptive;

my $debug=100; # be like super verbose
my %groups;    # hash, counting elements for each group
my %stats;     # hash, with stats data

### Routines

## flatten an array
sub flat(@) {
 return map { ref eq 'ARRAY' ? @$_ : $_ } @_;
}

## deduplicate routine using a hash internally to output an array
sub unique {
 my %seen;
 grep !$seen{$_}++, @_;
}

## basic stats
sub basicstats {
 if ($debug>100) {
  print STDERR "Raw inputs:\n";
  print STDERR Dumper(@_);
 }
 # input is 2 arrays
 my @input_values         = @{ $_[0] };
 my @input_values_weights = @{ $_[1] };

 if ($debug>100) {
  print STDERR "Inputs:\n";
  print STDERR Dumper(@input_values);
  print STDERR "Weights:\n";
  print STDERR Dumper(@input_values_weights);
 }

 # output is a hash that we will assemble with various objects, like statistical measures
 my %summary;
 # it will include a selection of input values and weights, that'll be used to make more stats
 my @selected_values;
 my @selected_values_weights;
 # and it will separate the outliers
 my @outliers_values;
 my @outliers_values_weights;
 # and make a list of unique outliers
 my @outliers_unique;

 # weights are in second argument
 my $stat  = Statistics::Descriptive::Weighted::Full->new();
 $stat->add_data(\@input_values, \@input_values_weights);

 # The raw statistics
 my $rawmean  = $stat->mean();                    ## weighted mean
 my $rawvar   = $stat->variance();                ## weighted sample variance (unbiased estimator)

 my $rawstdev = sqrt($rawvar);
# my $bvar   = $stat->biased_variance();        ## weighted sample variance (biased)
 my $rawmed   = $stat->median();                  ## weighted sample median
 my $rawmedpval  = $stat->rtp($rawmed);           ## returns right tail probability

 # The array of absolute deviations
 my @ad;
 foreach my $val (@input_values) {
  push (@ad, abs($val-$rawmed));
 }

 my $stat_ad  = Statistics::Descriptive::Weighted::Full->new();
 $stat_ad->add_data(\@ad, \@input_values_weights);
 my $mad = $stat_ad->median();
 # instead of estimating sigma from the sample, give a consistent estimator of the stddev:
 # sigmahat=1.4826*mad
 # cf https://en.wikipedia.org/wiki/Median_absolute_deviation#Relation_to_standard_deviation
 # 1.4826 is the constant scale factor, assuming a normal distribution by the LLN)
 my $madstdev=(1.4826)*$mad;
 # Acceptance criteria to flag outliers
 # 2 sigmas 95% confidence interval, as usual
 # cf https://en.wikipedia.org/wiki/97.5th_percentile_point
 # Except that instead of the usual xbar +- 1.96 stdev,
 # we can use the more robust med +- 1.96 madstdev
 # FIXME: use a w scaling factor to artificially enlarge or tighten the interval
 my $plusminus=1.96*$madstdev;
 #my $plusminus=$madstdev;
 my $topbound=$rawmed+$plusminus;
 my $lowbound=$rawmed-$plusminus;

 my $val_index=0; # to synchronize the list of weight with the selected values
 foreach my $val (@input_values) {
  if ($val > $topbound || $val < $lowbound) {
   # print STDERR "outlier as $val > $topbound || $val < $lowbound\n";
   push (@outliers_values, $val);
   push (@outliers_values_weights, $input_values_weights[$val_index]);
   $val_index=$val_index+1;
  } else { # not within bounds
   push (@selected_values, $val);
   push (@selected_values_weights, $input_values_weights[$val_index]);
   $val_index=$val_index+1;
  } # if bounds
 } # foreach
 
 # return the important numbers: raw statistics first
 $summary{rawmean}=$rawmean;
 $summary{rawstdev}=$rawstdev;
 $summary{rawmed}=$rawmed;
 $summary{rawmedpval}=$rawmedpval;
 # then the selection critera
 $summary{mad}=$mad;
 # even if it's just multiplied by constant scale factor, save it as is
 $summary{madstdev}=$madstdev;
 # and likewise for the boundaries
 $summary{topbound}=$topbound;
 $summary{lowbound}=$lowbound;
 # then the list of selected values and outliers
 # dereference the arrays:
 $summary{selected_values}=\@selected_values;
 $summary{selected_values_weights}=\@selected_values_weights;
 # $summary{rawad}=\@ad; # useless  to pass on
 @outliers_unique=unique(@outliers_values);
 $summary{outliers}=\@outliers_unique;
 $summary{outliers_values}=\@outliers_values;
 $summary{outliers_values_weights}=\@outliers_values_weights;
 my $stat_corrected  = Statistics::Descriptive::Weighted::Full->new();
 $stat_corrected->add_data(\@selected_values, \@selected_values_weights);
 # and the most important: corrected mean and variance
 my $mean  = $stat_corrected->mean();          ## weighted mean
 my $var   = $stat_corrected->variance();      ## weighted sample variance (unbiased estimator)
 my $stdev = sqrt($var);
 $summary{mean}=$mean;
 $summary{stdev}=$stdev;
 my $correctmed   = $stat_corrected->median();                 ## weighted sample median
 my $correcmedpval  = $stat_corrected->rtp($correctmed);       ## returns right tail probability
 $summary{correctmed}=$correctmed;
 $summary{correctmedpval}=$correcmedpval;
 my $stat_corrected_unweighted  = Statistics::Descriptive::Full->new();
 $stat_corrected_unweighted->add_data(\@selected_values);
 my $med_unweighted = $stat_corrected_unweighted->median();
 # WONTFIX: duh, no we can't do pval on unweighted, meaningless lol
 # my $med_unweighted_pval  = $stat_corrected_unweighted->rtp($med_unweighted);              ## returns right tail probability
 $summary{med_unweighted} = $med_unweighted;
 return (%summary);
} # basicstats

################################################################
# step 1: read the files into temporary variables

my @data;       # where the data is stored
my $fields_nbr; # for the whole file, to detect sudden changes indicate of a format error
my $line_num=0; # line counter for debugging with the above

while (my $line = <>) {
  # strip CRLF better than chomp
  $line =~ s/[\x0A\x0D]$//g;
  my @line_read;
  @line_read=split (/\t/, $line);
  # store by dereferencing the array
  $data[$line_num] = \@line_read;
  # then basic check
  if ($line_num==0) {
      # store the number of fields to check
      $fields_nbr=$#line_read;
  } else {
     # check if the size differs from what's expected, complain
     if ($#line_read != $fields_nbr) {
        print STDERR ("ERROR: Expected " . $fields_nbr . " fields but read " . $#line_read . " fields on line " . $line_num . "\n");
     } # line_read != fields_nbr
  } # line_num != 0
  $line_num=$line_num+1;
} # while

# Secondary check: refuse to process without any data
if (scalar (@data)<2)
 {
  print STDERR "There is not even one line of data, indicating a possible error\n";
  die "Cant do without data\n";
 }
# set the number of lines
my $line_nbr=$line_num;

if ($debug >0) {
 print STDERR "Step 1: Read $line_num lines\n";
 if ($debug >10) {
  print STDERR Dumper(@data);
 }
}

################################################################ 
# step 2: create groups using the fields matching what we want

# for ingredients (cas and names): one field
my $cas_field=0;
# for hazard codes: multiple fields 
my $code_field=0;
my @code_fields;

# for summary statistics
my %operator_counts;

# restart from 0
$line_num=0;

while ($line_num < $line_nbr) {
   # Construct the hash objects
   my $group =$data[$line_num][0];
   my $type  =$data[$line_num][1];
   my $number=$data[$line_num][2];
   my $weight=$data[$line_num][3];
   my $source=$data[$line_num][4];

   # do not tolerate numbers without digits (!)
   # WONTFIX: we could use looks_like_a_number() from Scalar::Utils for things like 1e5
   # however, numbers in engineering notation are less likely than database errors
   # so let's do that more simply
   unless ($number =~ m/[0-9]+/) {
     if ($debug >0 ) {
      print STDERR "\tSkipping empty value on line $line_num of $type for $group from $source\n"; 
     }
     $line_num = $line_num+1;
     next;
   }

   # Update the cardinality of the group
   if (defined($groups{$group})) {
    $groups{$group}=$groups{$group}+1;
   } else {
    $groups{$group}=1;
   }

   # Update the summary statistics
   if (defined($operator_counts{$type})) {
    $operator_counts{$type}=$operator_counts{$type}+1;
   } else {
    # initialize
    $operator_counts{$type}=1
   }

   # type can be an equality or a predicate
   # for equalities, tolerate multiple formats: single equal, double equal or nothing at all
   if      ($type =~ m/^==$/ or $type =~ m/^=$/ or $type =~ m/^$/) {
   # equalities directly go in values
    push(@{ $stats{$group}{values} }, $number);
    push(@{ $stats{$group}{values_weights} }, $weight);
   } elsif ($type =~ m/^\<$/) {
    push(@{ $stats{$group}{predicates_lt} }, $number);
    push(@{ $stats{$group}{predicates_lt_weights} }, $weight);
   } elsif ($type =~ m/^\<=$/) {
    push(@{ $stats{$group}{predicates_le} }, $number);
    push(@{ $stats{$group}{predicates_le_weights} }, $weight);
   } elsif ($type =~ m/^\>$/) {
    push(@{ $stats{$group}{predicates_gt} }, $number);
    push(@{ $stats{$group}{predicates_gt_weights} }, $weight);
   } elsif ($type =~ m/^\>=$/) {
    push(@{ $stats{$group}{predicates_ge} }, $number);
    push(@{ $stats{$group}{predicates_ge_weights} }, $weight);
   } elsif ($type =~ m/^\!=$/) {
    push(@{ $stats{$group}{predicates_ne} }, $number);
    push(@{ $stats{$group}{predicates_ne_weights} }, $weight);
   }
   $line_num=$line_num+1;
} # while line_num < line_nbr

if ($debug>0) {
 print STDERR "Step 2: Made " . scalar(keys(%groups)) . " groups, with the following equalities and inequalities types:\n";
 foreach my $t (keys(%operator_counts)) {
  print STDERR "- operator type '$t' has " . $operator_counts{$t} , " values\n";
 } # if debug
 if ($debug>20) {
  print STDERR "groups:";
  print STDERR Dumper(%groups);
  print STDERR "stats:";
  print STDERR Dumper(%stats);
 } # if >20
} # if debug

print STDERR "Step 3: Using data to create a TSV with statistics:\n";

# the output TSV format specification is the first line:
print "group\ttype\tcorrectmed_unweighted\tcorrected_med\tcorrected_med_pval\tcorrected_mean\tcorrected_stdev\traw_mean\traw_stdev\tmad\tmad_stdev\traw_med\traw_med_pval\tlow_boundary\ttop_boundary\tselected_values\tselected_values_weights\toutliers_values\toutliers_values_weights\tnbr_selected\tnbr_outliers\tnbr_total\n";
foreach my $group (sort keys (%groups)) {
 if ($debug>=4) {
  print STDERR "- $group : ";
 } # if debug

 my @numbers;
 my @numbers_weights;
 if (defined($stats{$group}{values}) && scalar($stats{$group}{values})>0 && defined($stats{$group}{values_weights}) && scalar($stats{$group}{values_weights})>0) {
  @numbers=$stats{$group}{values};
  @numbers_weights=$stats{$group}{values_weights};
 }

 ################################################################ 
 # We now have values, weights and a case number: compute stats
 my %bs=basicstats(@numbers, @numbers_weights);

 if ($debug>4.5) {
  print STDERR Dumper(%bs);
 }

 # create a TSV, line per line
 print "$group\t=";
 my $correctmed_unweighted = $bs{med_unweighted};
 my $correctmed = $bs{correctmed};
 my $correctmedpval = $bs{correctmedpval};
 print "\t$correctmed_unweighted\t$correctmed\t$correctmedpval";
 # corrected mean
 my $mean=$bs{mean};
 # correctd stdev
 my $stdev=$bs{stdev};
 # raw mean and stdev
 my $rawmean=$bs{rawmean};
 my $rawstdev=$bs{rawstdev};
 my $mad=$bs{mad};
 my $madstdev=$bs{madstdev};
 my $rawmed=$bs{rawmed};
 my $rawmedpval=$bs{rawmedpval};
 # the actual numbers
 print "\t$mean\t$stdev\t$rawmean\t$rawstdev\t$mad\t$madstdev\t$rawmed\t$rawmedpval";
 # then the selection criteria
 my $lowbound=$bs{lowbound};
 my $topbound=$bs{topbound};
 print "\t$lowbound\t$topbound";
 # then the list of numbers selected and excluded as outliers, to allow a quick inspection of how the sausage was made
 my @selected_values = @{ ${bs}{selected_values} };
 my $selected_values_list=join("|", @selected_values);
 my @selected_values_weights = @{ ${bs}{selected_values_weights} };
 my $selected_values_weights_list=join("|", @selected_values_weights);
 print ("\t$selected_values_list\t$selected_values_weights_list");
 # TODO: may want to keep the weight of the outliers?
 my @outliers_values=@{ $bs{outliers_values} };
 my $outliers_values_list=join("|", @outliers_values);
 my @outliers_values_weights=@{ $bs{outliers_values_weights} };
 my $outliers_values_weights_list=join("|", @outliers_values_weights);
 print ("\t$outliers_values_list\t$outliers_values_weights_list\t");
 print scalar(@selected_values);
 print "\t";
 print scalar(@outliers_values);
 print "\t";
 print (scalar(@outliers_values)+scalar(@selected_values));
 print "\n";
} # foreach group
