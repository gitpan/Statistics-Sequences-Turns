package Statistics::Sequences::Turns;

use 5.008008;
use strict;
use warnings;
use Carp 'croak';
use vars qw($VERSION @ISA);
use Statistics::Sequences 0.10;
@ISA = qw(Statistics::Sequences);
$VERSION = 0.10;
use Statistics::Zed 0.072;
our $zed = Statistics::Zed->new();
use Scalar::Util qw(looks_like_number);

=pod

=head1 NAME

Statistics::Sequences::Turns - Kendall's test for turning-points - peaks or troughs - in a numerical sequence

=head1 SYNOPSIS

 use strict;
 use Statistics::Sequences::Turns 0.10;
 my $turns = Statistics::Sequences::Turns->new();
 $turns->load([qw/2 0 8 5 3 5 2 3 1 1 9 4 4 1 5 5 6 5 8 7 5 3 8 5 6/]); # strings/numbers; or send as "data => $aref" with each stat call
 my $val = $turns->observed(state => 5); # other methods include: expected(), variance(), obsdev() and stdev()
 $val = $turns->zscore(state => 5, tails => 2, ccorr => 1); # # or want an array & get back both z- and p-value
 $val = $turns->p_value(state => 5, tails => 1); # assuming data are loaded; alias: test()
 my $href = $turns->stats_hash(values => {observed => 1, p_value => 1}, ccorr => 1); # include any other stat-method as needed
 $turns->dump(values => {observed => 1, expected => 1, p_value => 1}, ccorr => 1, flag => 1, precision_s => 3, precision_p => 7);
 # prints: observed = 11.000, expected = 10.900, p_value = 0.5700167

=head1 DESCRIPTION

For data of the continuous numerical type, a count of turns is incremented if the value on trial I<i>, for I<i> is greater than zero and less than I<n>, is, with respect to its neighbours, a peak (greater than both neighbours) or a trough (less than both neighbours). Comparing this count with the expected number of turns, and the expected variance of this count, for a randomly generated sequence completes the test.

=head1 METHODS

=head2 new

 $turns = Statistics::Sequences::Turns->new();

Returns a new Turns object. Expects/accepts no arguments but the classname.

=head2 load

 $turns->load(@data); # anonymously
 $turns->load(\@data);
 $turns->load('sample1' => \@data); # labelled whatever

Loads data anonymously or by name - see L<load|Statistics::Data/load, load_data> in the Statistics::Data manpage for details on the various ways data can be loaded and then retrieved (more than shown here). Data must be numerical (ordinal, interval type). All elements must be numerical of the method croaks.

=cut

sub load {
    my $self = shift;
    $self->SUPER::load(@_);
    my $data = $self->read(@_);
    foreach (@$data) {
        croak __PACKAGE__, '::test All data must be numerical for turns statistics' if ! looks_like_number($_);
    }
    return 1;
}

=head2 add, read, unload

See L<Statistics::Data> for these additional operations on data that have been loaded.

=head2 observed, turncount_observed, tco

 $v = $pot->observed(); # use the first data loaded anonymously; specify a 'state' within it to test its pot
 $v = $pot->observed(index => 1); # ... or give the required "index" for the loaded data
 $v = $pot->observed(label => 'mysequence'); # ... or its "label" value
 $v = $pot->observed(data => \@data); # ... or just give the data now

Returns observed number of turns. This is the number of peaks and troughs, starting the count from index 1 of a flat array, checking if both its left/right (or past/future) neighbours are lesser than it (a peak) or greater than it (a trough). Wherever the values in successive indices of the list are equal, they are treated as a single observation/datum - so the following:

 0 0 1 1 0 1 1 1 0 1

is counted up for turns as

 0 1 0 1 0 1
   * * * *

So there are four turns in this example - two peaks (0 1 0) and two troughs (1 0 1). (If repeated, this sequence would significantly deviate from expectation, I<p> = .035.)

=cut

sub observed {
    my $self = shift;
    my $args = ref $_[0] ? shift : {@_};
    my $data = _set_data($self, $args);
    my $num = scalar(@{$data});
    return 0 if ! $num or $num < 3; 
    my ($count, $i) = (0);
    
    for ($i = 1; $i < $num - 1; $i++) {
        if ( ($data->[$i - 1] > $data->[$i]) && ($data->[$i + 1] > $data->[$i]) ) { # trough at $i
            $count++;
        }
        elsif ( ($data->[$i - 1] < $data->[$i]) && ($data->[$i + 1] < $data->[$i]) ) { # peak at $i
            $count++;
        }
    }
    return $count;
}
*turncount_observed = \&observed;
*tco = \&observed;

=head2 expected, turncount_expected, tce

 $v = $turns->expected(); # use first-loaded data; or specify by "index" or "label", or give it as "data" - see observed()
 $v = $turns->expected(data => \@data); # use these data
 $v = $turns->expected(trials => 10); # don't use actual data; calculate from this number of trials

Returns the expected number of turns, which is set by I<N> the number of trials/observations/sample-size ...:

=for html <p>&nbsp;&nbsp;<i>E[T]</i> = 2 / 3 (<i>N</i> &ndash; 2)

=cut
 
sub expected {
   my $self = shift;
   my $args = ref $_[0] ? shift : {@_};
   my $num = defined $args->{'trials'} ? $args->{'trials'} : scalar(@{_set_data($self, $args)});
   return 2/3 * ($num - 2);
}
*tce = \&expected;
*turncount_expected = \&expected;

=head2 variance, turncount_variance, tcv

 $v = $turns->variance(); # use first-loaded data; or specify by "index" or "label", or give it as "data" - see observed()
 $v = $turns->variance(data => \@data); # use these data
 $v = $turns->variance(trials => number); # don't use actual data; calculate from this number of trials

Returns the expected variance in the number of turns for the given length of data I<N>.

=for html <p>&nbsp;&nbsp;<i>V[T]</i> = (16<i>N</i> &ndash; 29 ) / 90

=cut

sub variance {
   my $self = shift;
   my $args = ref $_[0] ? shift : {@_};
   my $num = defined $args->{'trials'} ? $args->{'trials'} : scalar(@{_set_data($self, $args)});
   return (16 * $num - 29) / 90;
}
*tcv = \&variance;
*turncount_variance = \&variance;

=head2 obsdev, observed_deviation

 $v = $pot->obsdev(); # use data already loaded - anonymously; or specify its "label" or "index" - see observed()
 $v = $pot->obsdev(data => [1.3, 0.007, -3.2, 11, 12]); # use these data

Returns the deviation of (difference between) observed and expected pot for the loaded/given sequence (I<O> - I<E>). 

=cut

sub obsdev {
    return observed(@_) - expected(@_);
}
*observed_deviation = \&obsdev;

=head2 stdev, standard_deviation

 $v = $pot->stdev(); # use data already loaded - anonymously; or specify its "label" or "index" - see observed()
 $v = $pot->stdev(data => [3, 4.7, 55, 5.03]);

Returns square-root of the variance.

=cut

sub stdev {
    return sqrt(variance(@_));
}
*standard_deviation = \&stdev;

=head2 z_value, zscore, turncount_zscore, tzs

 $v = $turns->z_value(ccorr => 1); # use data already loaded - anonymously; or specify its "label" or "index" - see observed()
 $v = $turns->z_value(data => $aref, ccorr => 1);
 ($zvalue, $pvalue) = $turns->z_value(data => $aref, ccorr => 1, tails => 2); # same but wanting an array, get the p-value too

Returns the zscore from a test of turncount deviation, taking the turncount expected away from that observed and dividing by the root expected turncount variance, by default with a continuity correction in the numerator. Called wanting an array, returns the z-value with its p-value for the tails (1 or 2) given.

=cut

sub zscore {
   my $self = shift;
   my $args = ref $_[0] ? shift : {@_};
   my $data = _set_data($self, $args);
   my $num = scalar(@$data);
   my $tco = defined $args->{'observed'} ? $args->{'observed'} : $self->tco($args);
   my $ccorr = defined $args->{'ccorr'} ? $args->{'ccorr'} : 1;
   my $tails = $args->{'tails'} || 2;
   my $precision_s = $args->{'precision_s'};
   my $precision_p = $args->{'precision_p'};
   my ($zval, $pval) = $zed->zscore(
        observed => $tco,
        expected => $self->tce(trials => $num),
        variance => $self->tcv(trials => $num),
        ccorr => $ccorr,
        tails => $tails,
        precision_s => $precision_s, 
        precision_p => $precision_p,
     );
    return wantarray ? ($zval, $pval) : $zval;
}
*tzs = \&zscore;
*turncount_zscore = \&zscore;
*z_value = \&zscore;

=head2 p_value, test, turns_test, tnt

 $p = $turns->p_value(); # using loaded data and default args
 $p = $turns->p_value(ccorr => 0|1, tails => 1|2); # normal-approximation based on loaded data
 $p = $turns->p_value(data => $aref, ccorr => 1, tails => 2); #  using given data (by-passing load and read)

Test the currently loaded data for significance of the number of turning-points by normal approximation. Note: for turns there is "a fairly rapid tendency of the distribution to normality" (Kendall 1973, p. 24).

=cut

sub p_value {
   return (z_value(@_))[1];
}
*test = \&p_value;
*turns_test = \&p_value;
*tnt = \&p_value;

=head2 dump

 $turns->dump(flag => '1|0', text => '0|1|2');

Print test results to STDOUT. See L<dump|Statistics::Sequences/dump> in the Statistics::Sequences manpage for details.

=cut

sub dump {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    $args->{'stat'} = 'turns';
    $self->SUPER::dump($args);
    return $self;
}

sub _set_data {# Remove equivalent successors: e.g., strip 2nd 2 from (3, 2, 2, 7, 2) # Check elements are numeric:
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    my $data = $self->read($args);
    ref $data or croak __PACKAGE__, '::Data for counting up turns are needed';
    my ($i, @data_u) = ();
    for ($i = 0; $i < scalar(@{$data}); $i++) {
        croak __PACKAGE__, '::test All data must be numerical for testing turns' if ! looks_like_number($data->[$i]);
        push @data_u, $data->[$i] if !scalar(@data_u) || $data->[$i] != $data_u[-1];
    }
    return \@data_u;
}

__END__

=head1 REFERENCES

Kendall, M. G. (1973). I<Time-series>. London, UK: Griffin. [The test is described on pages 22-24; in the Example 2.1 for this test, the expected number of turns should be calculated with the value 52 (i.e., I<n> - 2), not 54.]

=head1 SEE ALSO

L<Statistics::Sequences|Statistics::Sequences> for other tests of sequences, and for sharing data between these tests.

=head1 TO DO/BUGS

Implementation of the serial test for non-overlapping I<v>-nomes.

=head1 REVISION HISTORY

See CHANGES in installation dist for revisions.

=head1 AUTHOR/LICENSE

=over 4

=item Copyright (c) 2006-2013 Roderick Garton

rgarton AT cpan DOT org

This program is free software. It may be used, redistributed and/or modified under the same terms as Perl-5.6.1 (or later) (see L<http://www.perl.com/perl/misc/Artistic.html>).

=back

=head1 DISCLAIMER

To the maximum extent permitted by applicable law, the author of this module disclaims all warranties, either express or implied, including but not limited to implied warranties of merchantability and fitness for a particular purpose, with regard to the software and the accompanying documentation.

=cut
