package MT::Plugin::Revision::OMV::RevisionTagSupplement;
# RevisionTagSupplement (C) 2012 Piroli YUKARINOMIYA (Open MagicVox.net)
# This program is distributed under the terms of the GNU Lesser General Public License, version 3.
# $Id$

use strict;
use warnings;
use MT 5;

use vars qw( $VENDOR $MYNAME $FULLNAME $VERSION );
$FULLNAME = join '::',
        (($VENDOR, $MYNAME) = (split /::/, __PACKAGE__)[-2, -1]);
(my $revision = '$Rev$') =~ s/\D//g;
$VERSION = 'v0.12'. ($revision ? ".$revision" : '392');

use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new ({
    id => $FULLNAME,
    key => $FULLNAME,
    name => $MYNAME,
    version => $VERSION,
    author_name => 'Open MagicVox.net',
    author_link => 'http://www.magicvox.net/',
    plugin_link => 'http://www.magicvox.net/archive/2012/11201631/', # Blog
    doc_link => 'http://lab.magicvox.net/trac/mt-plugins/wiki/RevisionTagSupplement', # tracWiki
    description => <<'HTMLHEREDOC',
<__trans phrase="Supply template tags to retrieve the revision history of entry and webpage.">
HTMLHEREDOC
    l10n_class => "${FULLNAME}::L10N",
    registry => {
        tags => {
            help_url => 'http://lab.magicvox.net/trac/mt-plugins/wiki/RevisionTagSupplement#tag-%t',
            block => {
                'HasRevs?' => "${FULLNAME}::Tags::Revisions",
                'Revisions' => "${FULLNAME}::Tags::Revisions",

                'HasRevEntries?' => "${FULLNAME}::Tags::RevEntries",
                'RevEntries' => "${FULLNAME}::Tags::RevEntries",
                'HasRevPages?' => "${FULLNAME}::Tags::RevEntries",
                'RevPages' => "${FULLNAME}::Tags::RevEntries",

                'RevIfChanged?' => "${FULLNAME}::Tags::RevIfChanged",
            },
            function => {
                'RevCount' => "${FULLNAME}::Tags::Revisions",
                'RevEntryCount' => "${FULLNAME}::Tags::RevEntries",
                'RevPageCount' => "${FULLNAME}::Tags::RevEntries",

                'RevDate' => "${FULLNAME}::Tags::RevDate",
                'RevDescription' => "${FULLNAME}::Tags::RevDescription",
                'RevNum' => "${FULLNAME}::Tags::RevNum",
            },
        },
    },
});
MT->add_plugin ($plugin);

sub instance { $plugin; }

1;