use IO::Socket::Async::SSL;

unit class IRC::Client::Server;

has         @.channels where .all ~~ Str|Pair;
has         @.nick     where .all ~~ Str;
has         @.alias    where .all ~~ Str|Regex;
has Int     $.port     where 0 <= $_ <= 65535;
has Bool    $.ssl;
has Str     $.ca-file;
has Str     $.label;
has Str     $.host;
has Str     $.password;
has Str     $.username;
has Str     $.userhost;
has Str     $.userreal;
has Str     $.current-nick     is rw;
has Bool    $.is-connected     is rw;
has Bool    $.has-quit         is rw;
has $.socket is rw where $_ ~~ IO::Socket::Async|IO::Socket::Async::SSL;

method Str { $!label }
