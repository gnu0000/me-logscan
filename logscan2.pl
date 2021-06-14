#!perl
#
#
#my $t1 = "2016-06-12T20:01:21.006269Z    2 Query	SELECT text FROM questionText WHERE questionId = 11616 AND languageId = 1804 AND current = 1";

use warnings;
use strict;
use Gnu::SimpleDB;
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

my $QUERIES = {};
my $TYPES   = {};
my $COUNTS  = {lines    => 0,
               queries  => 0,
               selects  => 0,
               inserts  => 0,
               deletes  => 0,
               updates  => 0,
               replaces => 0};

my $PREV = {%{$COUNTS}};

my $SELECT_COUNT = 0;

MAIN:
   ArgBuild("*^all *^new ^help ^debug");
   ArgParse(@ARGV) || die ArgGetError();
   ArgAddConfig()  || die ArgGetError();
   Usage() unless ArgIs();
   LoadState();
   Scan(ArgGet());
   Show();
   SaveState();
   exit(0);

sub Scan
   {
   my ($filespec) = @_;

   open (my $filehandle, "<", $filespec) or return "Cant read $filespec";
   
   print "===============================================================\n" if (ArgIs("new"));
   print "new queries since last scan                                    \n" if (ArgIs("new"));
   print "===============================================================\n" if (ArgIs("new"));

   while (my $line = <$filehandle>)
      {
      chomp $line;
      $COUNTS->{lines}++;

      my ($time,$id,$query) = $line =~ /^([0-9TZ\-\:\.]*)\s*(\d*)\s*Query\s*(.*)$/;
      next unless $query;

      next if $query =~ /^(SHOW|SET)/i; # skip crap
      next if $query =~ /^\/\*/i;       # skip crap

      if (ArgIs("new") && $COUNTS->{lines} > $PREV->{lines})
         {
         print "$query\n";
         }

      $COUNTS->{queries}++;
      $COUNTS->{selects }++ if $query =~ /^select/i;
      $COUNTS->{inserts }++ if $query =~ /^insert/i;
      $COUNTS->{deletes }++ if $query =~ /^delete/i;
      $COUNTS->{updates }++ if $query =~ /^update/i;
      $COUNTS->{replaces}++ if $query =~ /^replace/i;

      #store all unique queries and get counts
      #$QUERIES->{$query}=0 unless defined $QUERIES->{$query};
      #$QUERIES->{$query}++;

      next if (ArgIs("new") && $COUNTS->{lines} <= $PREV->{lines});

      my ($pert) = $query =~ /^(SELECT.*(WHERE|LEFT|JOIN))/i;
      next unless $pert;

      # store all select query types and get counts
      $TYPES->{$pert}=0 unless defined $TYPES->{$pert};
      $TYPES->{$pert}++;
      }
   close $filehandle;
   }

sub Show
   {
   $COUNTS->{uniq_count} = scalar keys %{$QUERIES};
   $COUNTS->{type_count} = scalar keys %{$TYPES};

   my $ns = ArgIs("new") ? " new" : "";
   my $as = ArgIs("all") ? "all" : "top 20";

   print "===============================================================\n";
   print "Total queries   : " . pval("queries" ) . " ($COUNTS->{uniq_count} unique, $COUNTS->{type_count} types)\n";
   print "Total selects   : " . pval("selects" ) . "\n";
   print "Total inserts   : " . pval("inserts" ) . "\n";
   print "Total deletes   : " . pval("deletes" ) . "\n";
   print "Total updates   : " . pval("updates" ) . "\n";
   print "Total replaces  : " . pval("replaces") . "\n";
   print "===============================================================\n";
   print "$as$ns query Types by count:                                \n";
   print "===============================================================\n";

   my @t = map{{count=>$TYPES->{$_}, type=>$_}} keys %{$TYPES};
   my @sorted = sort {$b->{count} <=> $a->{count}} @t;

   my $i=20;
   foreach my $type (@sorted)
      {
      last unless --$i || ArgIs("all");
      print sprintf("%5.5d %s\n", $type->{count}, substr($type->{type}, 0, 160));
      }
   }

sub pval
   {
   my ($name) = @_;

   my $str = sprintf ("%6d", $COUNTS->{$name});
   return $str unless $PREV->{$name};
   return $str . " (+" . ($COUNTS->{$name} - $PREV->{$name}) . ")";
   }


sub LoadState
   {
   open (my $filehandle, "<", "logscan.dat") or return {};
   while (my $line = <$filehandle>)
      {
      chomp $line;
      my ($name, $ct) = split("=", $line);
      $PREV->{$name} = $ct;
      }
   close $filehandle;
   }


sub SaveState
   {
   open (my $filehandle, ">", "logscan.dat") or return;
   map {print $filehandle "$_=$COUNTS->{$_}\n"} keys %{$COUNTS};
   close $filehandle;
   }

sub Usage
   {
   my $message = <<'END_MESSAGE';

logscan - Scan mysql logs (for trivox queries)

usage: logscan.exe [options] logfile

where: [options] are 0 or more of
         -new ... Display all queries added to the log since last scan
         -all ... Display all query types (default is top 20)

       logfile is the mysql query log. ie: c:\util\mysql\logs\mysql.log

example: logscan c:\util\mysql\logs\mysql.log

note:  your my.ini file should have something like this:
        # General logging.
       log-output=FILE
       general-log=1
       general_log_file="C:/util/mysql/logs/mysql.log"
END_MESSAGE

   print $message;
   exit(0);
   }