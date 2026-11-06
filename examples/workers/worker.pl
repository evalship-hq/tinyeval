# tinyeval worker in Perl. In your eval file:
#   worker perl evals/worker.pl
# Load your app's modules at the top, so they load once per worker.
use strict;
use warnings;

sub reply {
    my ($input) = @_;
    return "You said: $input";    # your app's AI call goes here
}

$| = 1;       # flush after every print
$/ = "\0";    # read up to each NUL byte
while (my $input = <STDIN>) {
    chomp $input;
    print reply($input), "\0";
}
