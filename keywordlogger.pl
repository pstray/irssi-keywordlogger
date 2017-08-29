use warnings;
use strict;
use Irssi;
use Irssi::Irc;
use POSIX qw/strftime/;

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
    $config{path} = Irssi::settings_get_str('kwl_path');
    $config{path} =~ s/^~([^\/]*)/(getpwnam($1 || $user))[7]/e;

    # #channel net net/#channel
    $config{targets} = {};
    my $elements = Irssi::settings_get_str('kwl_targets');
    for my $element (split " ", $elements) {
	my($netchan,$words) = split ":", $element;
	my($net,$channel) = split "/", $netchan;
	if ($net =~ /^[\#!@&]/ && $channel eq "") {
	    $channel = $net;
	    $net = "*";
	}
	$net = "*" if $net eq "";
	$channel = "*" if $channel eq "";
	$config{targets}{$net}{$channel} = [ split ",", $words ];
    }
    
}
Irssi::signal_add('setup changed' => 'update_config');

# settings_add_str(section, key, def)
# settings_add_bool(section, key, def)
# settings_add_level(section, key, def)
  
Irssi::settings_add_str('keywordlogger', 'kwl_targets', '');
Irssi::settings_add_str('keywordlogger', 'kwl_path', '~/.irssi/kwl/$0');
Irssi::settings_add_str('keywordlogger', 'kwl_timestamp', '%F %T');

sub log_msg {
    my ($net, $target, $nick, $msg) = @_;
    my $date = strftime(Irssi::settings_get_str('kwl_timestamp'), localtime);

    

}

Irssi::signal_add_last 'message public', sub {
    my($server, $msg, $nick, $address, $target) = @_;
    my $net = $server->{chatnet};
    
    log_msg($net, $target, $nick, $msg);
};

Irssi::signal_add_last 'message own_public', sub {
    my($server, $msg, $target) = @_;
    my $net = $server->{chatnet};
    my $nick = $server->{nick};
    
    log_msg($net, $target, $nick, $msg);
};
