use strict;
use warnings;
use feature 'say';

use Getopt::Long qw(:config no_auto_abbrev);

my $P = $0;
my $help = 0;

sub trim {
    my $s = shift;
    $s =~ s/^\s+|\s+$//g;
    return $s
};

sub help {
    my ($exit_code) = @_;
    print << "EOM";
Usage: $P [OPTION]... [FILE]...
  -g, --git         treat FILE as a single commit or git revision range
                    single git commit with:
                    <rev>
                    <rev>^
                    <rev>~n
                    multiple git commits with:
                    <rev1>..<rev2>
                    <rev1>...<rev2>
                    <rev>-<count>
  --report-file     a path of checkstyle report file
EOM

    exit ($exit_code);
};

my $git,
my $report_file;

GetOptions(
    'g|git!' => \$git,
    'report-file' => \$report_file,
    'h|help' => \$help,
) or help(1);

help(0) if ($help);

my $checkpatch_result;
if ($git) {
    # run checkfile script
    $checkpatch_result = `perl scripts/checkpatch.pl --git --terse --showfile --summary-file --show-types @ARGV`;
} elsif ($report_file) {
    # must be run like `perl scripts/checkpatch.pl --git --terse --showfile --summary-file --show-types <git commits>
    open(DATA, '<', @ARGV) or die $!;
}

my $csv_file_name = "report.tsv";

open(FH, '>', $csv_file_name) or die $!;

# add headers
print FH "Commit Hash\tSeverity\tType\tFilename\tLine Number\tError Message\n";

my @report_per_commit;

sub analyse_line {
    my ($line) = @_;
    # say "line => ", $line;
    if ($line =~ /^([0-9a-fA-F]{40,40}) (.*)$/) {  # summary
        my ($commit_sha, $summary) = split(' ', $line);
        # print to file
        foreach my $report_line (@report_per_commit) {
            # limit split to 5 pieces only
            my ($file_name, $line_number, $severity, $type, $error_message) = split(':', $report_line, 5);
            if ($file_name eq "") {
                $file_name = "COMMIT_MESSAGE";
            }
            $error_message = trim($error_message);
            $severity = trim($severity);
            print FH $commit_sha, "\t", $severity, "\t", $type, "\t", $file_name, "\t", $line_number, "\t", $error_message, "\n";
        }
        @report_per_commit = ();  # clear array
    } else {
        push(@report_per_commit, $line);
    }
}

if ($git) {
    foreach my $line (split(/\n/, $checkpatch_result)) {
        analyse_line($line);
    }
}

if ($report_file) {
    while(my $line = <DATA>){
        chomp $line;
        analyse_line($line);
    }
    close(DATA);
}

close(FH);
