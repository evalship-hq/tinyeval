# examples/workers/worker.pl around packages/SPEC.md's fake app, which prints to stdout and dies on "crash".
use strict;
use warnings;

open(my $replies, '>&', \*STDOUT) or die "can't dup stdout: $!";
open(STDOUT, '>&', \*STDERR) or die "can't point stdout at stderr: $!";    # the app's output stays off the replies
$| = 1;
select((select($replies), $| = 1)[0]);

print "app loaded\n";

sub reply {
    my ($input) = @_;
    print "app called\n";
    die "boom\n" if $input eq 'crash';
    return "You said: $input";
}

$/ = "\0";
while (my $input = <STDIN>) {
    chomp $input;
    my $reply = eval { reply($input) } // "Error: $@";
    print $replies $reply, "\0";
}
