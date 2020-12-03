#!/usr/bin/perl -w

use Getopt::Std;
use CGI qw /escapeHTML/;

our $app_path="/opt/logmon/adsl-link-up/";

our @regex0=();
our @regex1=();
our @regex2=();
our @regex3=();
our @regex4=();
our @regexR=();
our @regexX=();

our $LOGFILE="";

our $PREV_MOD_T;  # last modified time
our $PREV_LINES;  # number of lines read last time
our $PREV_HEAD_LINE; # first line of file (in case of over write)

our $log_line_count; # number of log lines read
our $new_head; # first line of the log file
our $current_mod_t;

our $www=0; # print www pages
our @alerts=();

our $DEBUG=0;

sub init() {
	@regex0=();
	@regex1=();
	@regex2=();
	@regex3=();
	@regex4=();
	@regexR=();
	@regexX=();

	$LOGFILE="";

	$PREV_MOD_T=0;  # last modified time
	$PREV_LINES=0;  # number of lines read last time
	$PREV_HEAD_LINE=""; # first line of file (in case of over write)

	$log_line_count=0; # number of log lines read
	$new_head=""; # first line of the log file
	$current_mod_t=0;
};

sub debug($) {
	if ($DEBUG == 1) {
		print "debug: $_[0]<br/>\n";
	};
};

sub mod_t($) {
	return (stat(shift))[9];
};

sub mod_t_as_string($) {
        my (@mod)=localtime(shift);
        return sprintf("%02d:%02d on %02d/%02d/%04d", $mod[2], $mod[1], $mod[3], $mod[4] + 1, 1900 + $mod[5]);
};

sub save_mod_t($$) {
	open(F,shift);
	print F shift;
	close(F);
};

sub read_prev_stats($) {
	if (! -f $_[0]) { return 1; };
	open(F,"<".$_[0]) || return 1;
	$PREV_MOD_T=<F>;
	chomp($PREV_MOD_T);
	$PREV_LINES=<F>;
	chomp($PREV_LINES);
	$PREV_HEAD_LINE=<F>;
	chomp($PREV_HEAD_LINE);
	close(F);

	return 0;
};

sub save_prev_stats($) {
	open(F,">".$_[0]) || return 1;
	print F "$current_mod_t\n";
	print F "$log_line_count\n";
	print F "$new_head\n";
	close(F);
	return 0;

};

sub read_conf($) {

	my $f=shift;

	if ($f!~/.cfg$/) { 
		debug("wrong file suffix - needs .cfg");
		return 1;
	};

	open(F,$f) || return 1;

	while(<F>) {
		chomp;

		debug("conf: $_");

		if (m|^LOGFILE\s+(\S+)|) { 
			$LOGFILE=$1; 
			debug("LOGFILE=$LOGFILE");
		} # log file name
		elsif (m|^([01234RX])\s*/(.*)/|) { # alert regex
			if ($1 eq "X") { push @regexX,$2 } # eXclude
			if ($1 eq "0") { push @regex0,$2 }
			if ($1 eq "1") { push @regex1,$2 }
			if ($1 eq "2") { push @regex2,$2 }
			if ($1 eq "3") { push @regex3,$2 }
			if ($1 eq "4") { push @regex4,$2 }
			if ($1 eq "R") { push @regexR,$2 } # reset
		 } else {
			debug("ignoring conf line $_");
		};
	};
	close(F);


};

sub alert_count($$) {

	if ($_[0] ne 'X') { # dont print excludes

		push @alerts, $_[0]. ":: ". $_[1];	

		#debug("Matched : $_[0] :: $_[1]");
	};
};

sub process_regex {
	
	my ($line,$alert_level,$aref)=@_;

	my (@arr)=@$aref; # de-reference the array

        foreach my $regex (@arr) {
                if ($line=~m/$regex/) {
                        alert_count($alert_level,$line);
			return 0;
                };
        };

	return 1;

};

sub process_record ($) {

	my $line=shift;

	# order by priority  X R 3 2 1

	# keep processing until we get a match of we have no more regexes
	
	if (process_regex($line,"X",\@regexX)==0) { return 0; }
	elsif (process_regex($line,"R",\@regexR)==0) { return 0; }
	elsif (process_regex($line,4,\@regex4)==0) { return 0; }
	elsif (process_regex($line,3,\@regex3)==0) { return 0; }
	elsif (process_regex($line,2,\@regex2)==0) { return 0; }
	elsif (process_regex($line,1,\@regex1)==0) { return 0; }
	elsif (process_regex($line,0,\@regex0)==0) { return 0; }

	return 1;

};

sub parse_lines($){

	if (!open(F,"<".$_[0])){
		debug("parse_lines: Can't open logfile");
		return 1;
	};

	debug("prev_lines = $PREV_LINES");
	
	$log_line_count=0;
	while(<F>) {

		$log_line_count++;
		if ($log_line_count > $PREV_LINES) {
	
			chomp;	

			#debug("read > $_");
			process_record($_); # returns 0=match, 1=no match

		};
	
	};

	close(F);

	#print "line count : $line_count\n";
	return 0;

};

sub process_log($) {

	my ($logconf)=shift;

	@alerts=(); # clear current alerts list

	# read config

	if (!read_conf($logconf)) { 
		debug("config read error");
		return 1
	};

	# create stats filename from config name
	my($logstats)=$logconf;
	$logstats=~s/\.cfg/\.stats/ig;

	#$logstats="\.$logstats";  # hide file

	debug("logstats: $logstats");

	# read prev stats

	if (read_prev_stats($logstats)!=0) {
	        $PREV_MOD_T=0;
	        $PREV_LINES=0;
        	$PREV_HEAD_LINE="";

		debug("No stats file found $logstats - using defaults");
	};

	# check modify times

	$current_mod_t = mod_t($LOGFILE);

	if ($current_mod_t == $PREV_MOD_T) {

		print("No update since ".mod_t_as_string($current_mod_t));
		return 1;
	};
	

	# check first line in case of overwrite

	if (!open(F,"<$LOGFILE")) { 
		print("Can't read first line of logfile"); 
		return 1; 
	};
	$new_head=<F>;
	close(F);
	chomp($new_head);

	debug("new head>".$new_head."<");

	if ($new_head ne $PREV_HEAD_LINE) {
		$PREV_LINES=0;

		debug("Log has been overwritten");
	};


	# parse lines

	if (parse_lines($LOGFILE)!=0) { 
		debug("Can't open logfile $LOGFILE");
		return 1 
	};


	# save stats

	if(save_prev_stats($logstats)!=0) {
		debug("Can't save previous stats");
	};


	return 0;
	
};

sub display_alerts($) {

	my ($lf) = shift;

	if ($www == 0) {
		print "+" x 80 ."\n\n$lf\n\n";
		foreach (@alerts) {
			s/</&lt;/g;
			s/>/&gt;/g;
			print $_."\n";
		};
	} else {


		print<<WWW;

<h2>$lf</h2>
<table cellspacing=0>
WWW


		foreach $line (@alerts) {

			my($lvl, $alrt) = split(/:: /,$line);	
			if ($lvl eq '0'){$color='lightgrey'}
			elsif ($lvl eq '1'){$color='dodgerblue'}
			elsif ($lvl eq '2'){$color='yellow'}
			elsif ($lvl eq '3'){$color='orange'}
			elsif ($lvl eq '4'){$color='red'}
			elsif ($lvl eq 'R'){$color='seagreen'};
			
			#$alrt=~s/</&lt;/g;
			#$alrt=~s/>/&gt;/g;
			$alrt = escapeHTML($alrt);		

			print "<tr class='rlvl'".$lvl."><td class='aclvl'".$lvl." bgcolor='$color' width='30px'>&nbsp;</td><td class='tclvl'".$lvl." width='100%'>$alrt</td></tr>\n";

		};



		print<<YYY;
</table>

YYY

	};
};


sub process_confs {

	@confs=<$app_path/conf/*.cfg>;

	debug("confs:".join(",\n",@confs));

if ($www==1) {
	print<<ZZZ;
Content-Type: text/html


<html>
<head>
        <title>logmon</title>
<link type="text/css" rel="stylesheet" href="style.css">
</head>
<body>

<h1>logmon</h1>
ZZZ
};
	foreach my $conf (@confs) {

		init(); # reset vars	
		if (process_log("$conf")!=0) {
			debug("We had an error processing the logfile $conf");
		} else {
			if (scalar @alerts>0) {
				display_alerts($LOGFILE);
			} else {
				print "New log lines but no alerts @ " . localtime();
			};
		};
		debug("-" x 80);
	};

if ($www==1) {
	print<<ZZZ;
</body>                                                                                                                            
</html>   
ZZZ
};
};

sub help() {

	print "-w , web output\n";
	exit 1;

};


#
# MAIN
#

my %options=();
getopts("hw", \%options);

help() if defined $options{h};
$www=1 if defined $options{w};

$www=1;
process_confs();
