use warnings;
use strict;
use Irssi;
use Irssi::Irc;
use POSIX qw(strftime);
use File::Path qw(make_path);

use Data::Dumper;

use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
	  authors     => "Peder Stray",
	  contact     => 'peder.stray@gmail.com',
	  name        => "keywordlogger",
	  description => "Logs lines matching keywords to files.",
	  license     => "GPLv3",
	  url         => "https://github.com/pstray/irssi_keywordlogger",
	 );

my %config;
my $user = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);

sub update_config {
    %config = ();

    $config{path} = Irssi::settings_get_str('kwl_path');
    for ($config{path}) {
	s/^~([^\/]*)/(getpwnam($1 || $user))[7]/e;
	s,/*$,,;
    }

    # #channel net net/#channel
    my $elements = Irssi::settings_get_str('kwl_targets');
    my $ext = Irssi::settings_get_str('kwl_ext');

    $elements =~ s/^\s*//;

    my($filename,@targets,$matches);

    while (length $elements) {
	if ($elements =~ s,^\{(.*?)}\s*,,) {
	    my($fn) = $1;
	    if ($config{targets} && !length $filename && !length $ext) {
		Irssi::print("kwl: %RError%N: matches before {file} block and no kwl_ext set will cause problems, logging disabled...", MSGLEVEL_CLIENTCRAP);
		$config{disabled}++;
	    }
	    $filename = $fn;
	}
	elsif ($elements =~ s,^/(.*?)/(i?)(?:\s+|$),,) {
	    my($match,$flags) = ($1,$2);
	    $matches++;
	    $flags = "(?$flags)" if $flags;
	    unless (@targets) {
		Irssi::print("kwl: %RError%N: no target defined for /$match/, logging disabled...", MSGLEVEL_CLIENTCRAP);
		$config{disabled}++;
		next;
	    }
	    for (@targets) {
		my($net,$target) = @$_;
		push @{$config{targets}{lc $net}{lc $target}}, [ qr{$flags$match}, $filename ];
	    }
	}
	elsif ($elements =~ s,^(\S+)(?:\s+|$),,) {
	    my($net,$target) = split "/", $1;
	    if ($net =~ /^[\#!@&]/ && ! length $target) {
		$target = $net;
		$net = "*";
	    }
	    $net = "*" unless length $net;
	    $target = "*" unless length $target;
	    if ($matches) {
		@targets = ();
		$matches = 0;
	    }
	    push @targets, [ $net, $target ];
	}
    }
}
Irssi::signal_add('setup changed' => 'update_config');

# settings_add_str(section, key, def)
# settings_add_bool(section, key, def)
# settings_add_level(section, key, def)
  
Irssi::settings_add_str('keywordlogger', 'kwl_targets', '');
Irssi::settings_add_str('keywordlogger', 'kwl_path', '~/.irssi/kwl/$0/$1');
Irssi::settings_add_str('keywordlogger', 'kwl_ext', '.log');
Irssi::settings_add_str('keywordlogger', 'kwl_prefix', '[%F %T] <$2> ');

update_config(); # to make sure tings are set up

sub log_msg {
    my($net, $target, $nick, $msg) = @_;
    my(%files);

    return if $config{disabled};

    for my $n (lc $net, "*") {
	my $targets = $config{targets}{$n};
	next unless $targets;

	for my $t (lc $target, "*") {
	    my $matches = $targets->{$t};
	    next unless $matches;

	    for my $m (@$matches) {
		my($match, $file) = @$m;

		if ($msg =~ $match) {
		    $file = strftime($file, localtime) if $file;
		    
		    $files{$file}++;
		}
	    }
	}
    }

    return unless %files;

    my $prefix = strftime(Irssi::settings_get_str('kwl_prefix'), localtime);
    my $path = strftime($config{path}, localtime);
    my $ext = Irssi::settings_get_str('kwl_ext');

    for ($prefix, $path) {
	s/\$0/$net/g;
	s/\$1/$target/g;
	s/\$2/$nick/g;
    }

    for my $file (keys %files) {
	my $fn = $path;
	$fn .= "/$file" if $file;
	$fn .= $ext;

	for ($fn) {
	    s/\$0/$net/g;
	    s/\$1/$target/g;
	    s/\$2/$nick/g;
	}

	my($path) = $fn =~ m,^(.*)/,,;

	make_path($path);
	open my $fh, ">>:utf8", $fn;
	print $fh "$prefix$msg\n";
	close $fh;
    }

}

Irssi::signal_add 'message public', sub {
    my($server, $msg, $nick, $address, $target) = @_;
    my $net = $server->{chatnet};
    
    log_msg($net, $target, $nick, $msg);
};

Irssi::signal_add 'message own_public', sub {
    my($server, $msg, $target) = @_;
    my $net = $server->{chatnet};
    my $nick = $server->{nick};
    
    log_msg($net, $target, $nick, $msg);
};
