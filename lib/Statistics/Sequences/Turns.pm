package Statistics::Sequences::Turns;

use 5.008008;
use strict;
use warnings;
use Carp 'croak';
use vars qw($VERSION @ISA);
use Scalar::Util qw(looks_like_number);
use Statistics::Sequences 0.051;
@ISA = qw(Statistics::Sequences);

$VERSION = '0.04';

=pod

=head1 NAME

Statistics::Sequences::Turns - Kendall's test for turning-points - peaks or troughs - in a numerical sequence

=head1 SYNOPSIS

 use Statistics::Sequences::Turns 0.031;
 $turns = Statistics::Sequences::Turns->new();
 $turns->load(0, 3, 9, 2 , 1, 1, 3, 4, 0, 3, 5, 5, 5, 8, 4, 7, 3, 2, 4, 3, 6); # or send with each stat call
 $val = $turns->observed(); # also expected() and variance(), with optional arg trials => n in place of real data 
 ($val, $sig) = $turns->zscore(tails => 2, ccorr => 1); # Z = -0.0982471864864821, 2p = 0.92174
 $turns->test()->dump(text => 1); # print of all the descriptives and zscore, lumping each into object as well

=head1 DESCRIPTION

For data of the continuous numerical type, a count of turns is incremented if the value on trial I<i>, for I<i> is greater than zero and less than I<n>, is, with respect to its neighbours, a peak (greater than both neighbours) or a trough (less than both neighbours). Comparing this count with the expected number of turns, and the expected variance of this count, for a randomly generated sequence completes the test.

=head1 METHODS

=head2 new

 $turns = Statistics::Sequences::Turns->new();

Returns a new Turns object. Expects/accepts no arguments but the classname.

=head2 load

 $turns->load(@data);
 $turns->load(\@data);
 $turns->load('dist1' => \@data1, 'dist2' => \@data2)
 $turns->load({'dist1' => \@data1, 'dist2' => \@data2})

Loads data anonymously or by name. See L<load|Statistics::Sequences/load> in the Statistics::Sequences manpage.

=head2 add

See L<Statistics::Sequences/add>

=head2 read

See L<Statistics::Sequences/read>

=head2 unload

See L<Statistics::Sequences/unload>

=head2 observed, turncount_observed, tco

 $count = $turns->observed(); # assumes testdata have already been loaded
 $count = $turns->observed(data => [qw/0 0 1 1 0 1 1 1 0 1/]);

Returns observed number of turns. This is the number of peaks and troughs, starting the count from index 1 of a flat array, checking if both its left/right (or past/future) neighbours are lesser than it (a peak) or greater than it (a trough). Wherever the values in successive indices of the list are equal, they are treated as a single observation/datum - so the following:

 0 0 1 1 0 1 1 1 0 1

is counted up for turns as

 0 1 0 1 0 1
   * * * *

So there are four turns in this example - two peaks (0 1 0) and two troughs (1 0 1). (If repeated, this sequence would significantly deviate from expectation, I<p> = .035.)

The data to test can already have been L<load|load>ed, or you send it here as a flat referenced array keyed as C<data>.

=cut

sub observed {# Count the number of turns in the given data:
    my $self = shift;
    my $args = ref $_[0] ? shift : {@_};
    my $data_aref = ref $args->{'data'} ? $args->{'data'} : $self->testdata($args);
    ref $data_aref or croak __PACKAGE__, '::Data for counting up turns are needed';
    my $data_u = _set_data($data_aref);
    my $num = scalar(@{$data_u});
    return 0 if ! $num or $num < 3; 
    my ($count, $i) = (0);
    
    for ($i = 1; $i < $num - 1; $i++) {
        if ( ($data_u->[$i - 1] > $data_u->[$i]) && ($data_u->[$i + 1] > $data_u->[$i]) ) { # trough at $i
            $count++;
        }
        elsif ( ($data_u->[$i - 1] < $data_u->[$i]) && ($data_u->[$i + 1] < $data_u->[$i]) ) { # peak at $i
            $count++;
        }
    }
    return $count;
}
*turncount_observed = \&observed;
*tco = \&observed;

=head2 expected, turncount_expected, tce

 $val = $turns->expected(); # assumes testdata have already been loaded
 $val = $turns->expected(data => [1, 0, 0, 0, 1, 0, 0, 1, 0, 1]); # count these data
 $val = $turns->expected(trials => 10); # use this trial number, assume no data

Returns the expected number of turns, which is simply set by I<N> the number of trials/observations/sample-size ...:

=for html <p>&nbsp;&nbsp;<i>E[T]</i> = 2 / 3 (<i>N</i> &ndash; 2)

=cut
 
sub expected {
   my $self = shift;
   my $args = ref $_[0] ? shift : {@_};
   my $num = defined $args->{'trials'} ? $args->{'trials'} : ref $args->{'data'} ? scalar @{$args->{'data'}} : scalar(@{_set_data($self->testdata($args))});
    return 2/3 * ($num - 2);
}
*tce = \&expected;
*turncount_expected = \&expected;

=head2 variance, turncount_variance, tcv

 $val = $turns->variance(); # assume the data are already "loaded" for counting
 $val = $turns->variance(data => [1, 0, 0, 0, 1, 0, 0, 1, 0, 1]); # count for these data
 $val = $turns->variance(trials => number); # use this trial number 

Returns the expected variance in the number of turns for the given length of data I<N>.

=for html <p>&nbsp;&nbsp;<i>V[T]</i> = (16<i>N</i> &ndash; 29 ) / 90

=cut

sub variance {
   my $self = shift;
   my $args = ref $_[0] ? shift : {@_};
   my $num = defined $args->{'trials'} ? $args->{'trials'} : ref $args->{'data'} ? scalar @{$args->{'data'}} : scalar(@{_set_data($self->testdata($args))});
   return (16 * $num - 29) / 90;
}
*tcv = \&variance;
*turncount_variance = \&variance;

=head2 zscore, turncount_zscore, tzs, z_value

 $val = $turns->zscore(); # data already loaded, use default windows and prob
 $val = $turns->zscore(data => $aref, ccorr => 1);
 ($zvalue, $pvalue) =  $turns->zscore(data => $aref, ccorr => 1, tails => 2); # same but wanting an array, get the p-value too

Returns the zscore from a test of turncount deviation, taking the turncount expected away from that observed and dividing by the root expected turncount variance, by default with a continuity correction in the numerator. Called wanting an array, returns the z-value with its p-value for the tails (1 or 2) given.

The data to test can already have been L<load|load>ed, or you send it directly as a flat referenced array keyed as C<data>.

=cut

sub zscore {
   my $self = shift;
   my $args = ref $_[0] ? shift : {@_};
   my $tco = defined $args->{'observed'} ? $args->{'observed'} : $self->tco($args);
   my $num = defined $args->{'trials'} ? $args->{'trials'} : ref $args->{'data'} ? scalar @{$args->{'data'}} : scalar(@{_set_data($self->testdata($args))});
   my $ccorr = defined $args->{'ccorr'} ? delete $args->{'ccorr'} : 1;
   my $tails = delete $args->{'tails'} || 2;
   my ($zval, $pval) = $self->{'zed'}->zscore(
        observed => $tco,
        expected => $self->tce(trials => $num),
        variance => $self->tcv(trials => $num),
        ccorr => $ccorr,
        tails => $tails,
     );
    return wantarray ? ($zval, $pval) : $zval;
}
*tzs = \&zscore;
*turncount_zscore = \&zscore;
*z_value = \&zscore;

=head2 test, turns_test, tnt

 $joins->test();

Test the currently loaded data for significance of the number of turning-points. Returns the Turns object, lumped with a C<z_value>, C<p_value>, and the descriptives C<observed>, C<expected> and C<variance>. Note: for turns there is "a fairly rapid tendency of the distribution to normality" (Kendall 1973, p. 24).

=cut

sub test {
   my $seq = shift;
   my $args = ref $_[0] ? $_[0] : {@_};
   $seq->testdata($args);
   my $tco = defined $args->{'observed'} ? $args->{'observed'} : $seq->tco($args);
   my $tce = $seq->turncount_expected($args);
   my $tve = $seq->turncount_variance($args);

   if ($tve) {
       $seq->_expound($tco, $tce, $tve, $args);
   }
   else {
       $seq->_expire($tco, $tce, $args);
   }

   return $seq;
}
*turns_test = \&test;
*tnt = \&test;

=head2 dump

 $turns->dump(flag => '1|0', text => '0|1|2');

Print test results to STDOUT. See L<dump|Statistics::Sequences/dump> in the Statistics::Sequences manpage for details.

=cut

sub dump {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    $args->{'testname'} = 'Turns';
    if ($args->{'text'} and $args->{'text'} > 1) {
        $args->{'title'} = 'Turns test results:';
        $self->SUPER::_dump_verbose($args);
    }
     else {
        $self->SUPER::_dump_sparse($args);
    }
    return $self;
}

sub _set_data {# Remove equivalent successors: e.g., strip 2nd 2 from (3, 2, 2, 7, 2) # Check elements are numeric:
    my $data_aref = shift;
    my ($i, @data_u) = ();
    for ($i = 0; $i < scalar(@{$data_aref}); $i++) {
        croak __PACKAGE__, '::test All data must be numerical for testing turns' if ! looks_like_number($data_aref->[$i]);
        push @data_u, $data_aref->[$i] if !scalar(@data_u) || $data_aref->[$i] != $data_u[-1];
    }
    return \@data_u;
}

__END__

=head1 EXAMPLE

=head2 Seating at the diner

These are the data from Swed and Eisenhart (1943) also given as an example for the L<Runs test|Statistics::Sequences::Runs/EXAMPLE> and L<Vnomes test|Statistics::Sequences::Vnomes/EXAMPLE>. It lists the occupied (O) and empty (E) seats in a row at a lunch counter.
Have people taken up their seats on a random basis? The Runs test suggested some non-random basis for people to take their seats, ouputting (as per C<dump>):

  Runs: observed = 11.00, expected = 7.88, Z = 1.60, 1p = 0.054834

That means there was more serial discontinuity than expected. What does the test of Turns tell us?

 use Statistics::Sequences::Turns;
 my $turns = Statistics::Sequences::Turns->new();
 my @seating = (qw/E O E E O E E E O E E E O E O E/);
 $turns->load(\@data);
 $turns->binate(); # transform Es and Os into 1s and 0s
 $turns->test(tails => 1)->dump();

This outputs, as returned by C<string>: 

 Z = 1.95615199108988, 1p = 0.025224

So each seated person is neighboured by empty seats, and/or each empty seat is neighboured by seated persons, more so than would be expected if people were taking their seats randomly.

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

=item Copyright (c) 2006-2012 Roderick Garton

rgarton AT cpan DOT org

This program is free software. It may be used, redistributed and/or modified under the same terms as Perl-5.6.1 (or later) (see L<http://www.perl.com/perl/misc/Artistic.html>).

=back

=head1 DISCLAIMER

To the maximum extent permitted by applicable law, the author of this module disclaims all warranties, either express or implied, including but not limited to implied warranties of merchantability and fitness for a particular purpose, with regard to the software and the accompanying documentation.

=cut
