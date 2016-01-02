use v6;
use IRC::Parser; # parse-irc
use IRC::Client::Plugin::PingPong;
use IRC::Client::Plugin;
unit class IRC::Client:ver<2.002001>;

has Bool:D $.debug                          = False;
has Str:D  $.host                           = 'localhost';
has Str    $.password;
has Int:D  $.port where 0 <= $_ <= 65535    = 6667;
has Str:D  $.nick                           = 'Perl6IRC';
has Str:D  $.username                       = 'Perl6IRC';
has Str:D  $.userhost                       = 'localhost';
has Str:D  $.userreal                       = 'Perl6 IRC Client';
has Str:D  @.channels                       = ['#perl6bot'];
has IO::Socket::Async   $.sock;
has @.plugins           = [];
has @.plugins-essential = [
    IRC::Client::Plugin::PingPong.new
];
has @!plugs             = [|@!plugins-essential, |@!plugins];

method run {
    .irc-start-up: self for @!plugs.grep(*.^can: 'irc-start-up');

    await IO::Socket::Async.connect( $!host, $!port ).then({
        $!sock = .result;
        $.ssay("PASS $!password\n") if $!password.defined;
        $.ssay("NICK $!nick\n");
        $.ssay("USER $!username $!username $!host :$!userreal\n");
        $.ssay("JOIN {@!channels[]}\n");

        .irc-connected: self for @!plugs.grep(*.^can: 'irc-connected');

        # my $left-overs = '';
        react {
            whenever $!sock.Supply :bin -> $buf is copy {
                my $str = try $buf.decode: 'utf8';
                $str or $str = $buf.decode: 'latin-1';
                # $str ~= $left-overs;
                $!debug and "[server {DateTime.now}] {$str}".put;
                my $events = parse-irc $str;
                for @$events -> $e {
                    self.handle-event: $e;
                    CATCH { warn .backtrace }
                }
            }

            CATCH { warn .backtrace }
        }

        say "Closing connection";
        $!sock.close;

        # CATCH { warn .backtrace }
    });
}

method ssay (Str:D $msg) {
    $!debug and "{plug-name}$msg".put;
    $!sock.print("$msg\n");
    self;
}

method privmsg (Str $who, Str $what) {
    my $msg = "PRIVMSG $who :$what\n";
    $!debug and "{plug-name}$msg".put;
    $!sock.print("$msg\n");
    self;
}

method handle-event ($e) {
    $e<pipe>    = {};

    for @!plugs.grep(*.^can: 'irc-all-events') -> $p {
        my $res = $p.irc-all-events(self, $e);
        return unless $res === IRC_NOT_HANDLED;
    }

    if ( $e<command> eq 'PRIVMSG' and $e<params>[0] eq $!nick ) {
        for @!plugs.grep(*.^can: 'irc-privmsg-me') -> $p {
            my $res = $p.irc-privmsg-me(self, $e);
            return unless $res === IRC_NOT_HANDLED;
        }
    }

    if ( $e<command> eq 'NOTICE' and $e<params>[0] eq $!nick ) {
        for @!plugs.grep(*.^can: 'irc-notice-me') -> $p {
            my $res = $p.irc-notice-me(self, $e);
            return unless $res === IRC_NOT_HANDLED;
        }
    }

    if (   ( $e<command> eq 'PRIVMSG' and $e<params>[0] eq $!nick )
        or ( $e<command> eq 'NOTICE'  and $e<params>[0] eq $!nick )
        or ( $e<command> eq 'PRIVMSG'
                and $e<params>[1] ~~ /:i ^ "$.nick" <[,:]> \s+/
        )
    ) {
        for @!plugs.grep(*.^can: 'irc-addressed') -> $p {
            my $res = $p.irc-notice-me(self, $e);
            return unless $res === IRC_NOT_HANDLED;
        }
    }

    my $cmd = 'irc-' ~ $e<command>.lc;
    for @!plugs.grep(*.^can: $cmd) -> $p {
        my $res = $p."$cmd"(self, $e);
        return unless $res === IRC_NOT_HANDLED;
    }

    for @!plugs.grep(*.^can: 'irc-unhandled') -> $p {
        my $res = $p.irc-unhandled(self, $e);
        return unless $res === IRC_NOT_HANDLED;
    }
}

sub plug-name {
    my $plug = callframe(3).file;
    my $cur = $?FILE;
    return '[core] ' if $plug eq $cur;
    $cur ~~ s/'.pm6'$//;
    $plug ~~ s:g/^ $cur '/' | '.pm6'$//;
    $plug ~~ s/'/'/::/;
    return "[$plug] ";
}