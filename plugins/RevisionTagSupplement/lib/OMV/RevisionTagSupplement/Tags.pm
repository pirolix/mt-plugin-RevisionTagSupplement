package OMV::RevisionTagSupplement::Tags;
# RevisionTagSupplement (C) 2012 Piroli YUKARINOMIYA (Open MagicVox.net)
# This program is distributed under the terms of the GNU Lesser General Public License, version 3.
# $Id$

use strict;
use warnings;
use MT;
use MT::Entry;

sub instance { MT->component((__PACKAGE__ =~ /^(\w+::\w+)/g)[0]); }



### mt:HasRevs conditional tag
### mt:Revisions block tag
### mt:RevCount functional tag
#   include_empty   [0]|1
#   lastn           [0]..N
#   offset          [0]..N
#   order           ascend|[descend]
sub Revisions {
    my ($ctx, $args, $cond) = @_;

    my $entry = $ctx->stash ('entry')
        or return $ctx->_no_entry_error;
    my $datasource = $entry->datasource;
    my $rev_class  = MT->model ($datasource. ':revision');
    my $_terms = {
        $datasource. '_id' => $entry->id,
        $args->{include_empty}
                ? ()
                : (description => { op => '!=', value => '' }),
    };
    my $_args = {
        defined $args->{lastn} && 0 < $args->{lastn}
                ? (limit => $args->{lastn})
                : (),
        defined $args->{offset} && 0 < $args->{offset}
                ? (offset => $args->{offset})
                : (),
    };

    # mt:RevCount
    return $rev_class->count ($_terms, $_args)
        if 'mtrevcount' eq $ctx->this_tag;
    # mt:HasRevs?
    return $rev_class->count ($_terms, $_args)
        if 'mthasrevs' eq $ctx->this_tag;

    # mt:Revisions
    $_args = { %$_args,
        sort => 'created_on',
        defined $args->{order} && $args->{order} eq 'ascend'
                ? (direction => 'ascend')
                : (direction => 'descend'),
    };
    my $rev_iter = $rev_class->load_iter ($_terms, $_args);

    my $block_out;
    my $token = $ctx->stash ('tokens');
    my $builder = $ctx->stash ('builder');
    my $vars = $ctx->{__stash}{vars} ||= {};
    my $rev = $rev_iter->();
    my $rev_next;
    my $i = 0;
    while ($rev) {
        $rev_next = $rev_iter->();
BUILD:
        local $ctx->{__stash}{revision} = $rev;

        my $rev_entry = MT->model($datasource)->new->object_from_revision ($rev);
        # [ $rev_obj, \@changed, $rev->rev_number ]
        local $ctx->{__stash}{entry}  = $rev_entry->[0];
        local $vars->{__revchanged__} = $rev_entry->[1];

        local $vars->{__first__}    = !$i;
        local $vars->{__last__}     = !$rev_next;
        local $vars->{__odd__}      = !($i % 2); # $i is 0 origin
        local $vars->{__even__}     =  ($i % 2);
        local $vars->{__counter__}  =   $i + 1;
        local $ctx->{__stash}{revision} = $rev;
        defined(my $out = $builder->build ($ctx, $token, {
                %$cond,
                RevisionsHeader => !$i,
                RevisionsFooter => !$rev_next,
        })) or return $ctx->error ($builder->errstr);
        $block_out .= $out;
        $rev = $rev_next;
        $i++;
    } continue {
        $rev = $rev_next;
    }
    return $block_out;
}

### mt:Rev{Entries|Pages} block tag
### mt:Rev{Entry|Page}Count conditional tag
### mt:HasRev{Entries|Pages} functional tag
#   include_empty   [0]|1
#   lastn           [0]..N
#   offset          [0]..N
#   order           ascend|[descend]
#   unique          0|[1]
sub RevEntries {
    my ($ctx, $args, $cond) = @_;

    my $model = $ctx->this_tag =~ /(entry|entries)/
        ? 'entry'
        : $ctx->this_tag =~ /pages?/
            ? 'page'
            : undef
        or return $ctx->error (MT->translate ('Error in [_1] [_2]: [_3]', __PACKAGE__, __LINE__));

    my $class = MT->model($model)
        or return $ctx->error (MT->translate ('Error in [_1] [_2]: [_3]', __PACKAGE__, __LINE__));
    my $datasource = $class->datasource
        or return $ctx->error (MT->translate ('Error in [_1] [_2]: [_3]', __PACKAGE__, __LINE__));
    my $rev_class = MT->model ($datasource. ':revision')
        or return $ctx->error (MT->translate ('Error in [_1] [_2]: [_3]', __PACKAGE__, __LINE__));

    my $blog = $ctx->stash ('blog')
        or return $ctx->error (MT->translate ('record does not exist.'));

    my $unique = !defined $args->{unique} || $args->{unique};
    my $_terms = {
        $args->{include_empty}
                ? ()
                : (description => { op => '!=', value => '' }),
    };
    my $_args = {
        sort => 'created_on',
        defined $args->{order} && $args->{order} eq 'ascend'
                ? (direction => 'ascend')
                : (direction => 'descend'),
        join => $class->join_on (undef, {
            class => $model,
            blog_id => $blog->id,
            status => 2,
            id => \'= entry_rev_entry_id',
        }, {
            $unique
                ? (unique => 'entry_id')
                : (),
        }),
    };

    # mt:RevEntryCount
    return $rev_class->count ($_terms, $_args)
        if $ctx->this_tag =~ /^mtrev\w+count$/;
    # mt:HasRevEntries?
    return $rev_class->count ($_terms, $_args)
        if $ctx->this_tag =~ /^mthasrev\w+$/;
    delete $_args->{join}[3]->{unique};

    # mt:RevEntries
    $args->{lastn} = defined $args->{lastn}
        ? $args->{lastn}
        : $blog->entries_on_index;

    my $block_out;
    my %uniq_eid;
    my $token = $ctx->stash ('tokens');
    my $builder = $ctx->stash ('builder');
    my $vars = $ctx->{__stash}{vars} ||= {};

    my $rev_iter = $rev_class->load_iter ($_terms, $_args);
    my $rev = $rev_iter->();
    my $rev_next;
    my $i = 0;
    while ($rev) {
        $rev_next = $rev_iter->();

        my $rev_obj = $class->new->object_from_revision ($rev);
        # [ $rev_obj, \@changed, $rev->rev_number ]
        next        if $rev_obj->[0]->status != 2;  # Skip when revised entry not be published
        goto BUILD  if !$unique;                    # Always build becaus of no needing the duplications.
        next        if $uniq_eid{$rev->entry_id};   # Skip because already has been build

        $uniq_eid{$rev->entry_id}++;                # Set a mark of build
        next        if defined $args->{offset}      # No building untill not reaching to offset
                && keys %uniq_eid <= $args->{offset};
        last        if defined $args->{lastn}       # Exit when specified number of biild are done
                && $args->{lastn} && $args->{lastn} <= $i;

BUILD:
        local $ctx->{__stash}{revision} = $rev;
        local $ctx->{__stash}{entry}  = $rev_obj->[0];
        local $vars->{__revchanged__} = $rev_obj->[1];

        local $vars->{__first__}    = !$i;
        local $vars->{__last__}     = !$rev_next;
        local $vars->{__odd__}      = !($i % 2); # $i is 0 origin
        local $vars->{__even__}     =  ($i % 2);
        local $vars->{__counter__}  =   $i + 1;
        defined(my $out = $builder->build ($ctx, $token, {
                %$cond,
                EntriesHeader => !$i,
                EntriesFooter => !$rev_next,
                PagesHeader   => !$i,
                PagesFooter   => !$rev_next,
        })) or return $ctx->error ($builder->errstr);
        $block_out .= $out;
        $i++;
    } continue {
        $rev = $rev_next;
    }
    return $block_out;
}

### mt:RevIfChanged conditional tag
#   column
sub RevIfChanged {
    my ($ctx, $args) = @_;

    my $__revchanged__ = $ctx->{__stash}{vars}{__revchanged__}
        or return $ctx->error (MT->translate ('You used an [_1] tag outside of the proper context.', $ctx->stash ('tag')));
    if (defined (my $column = $args->{column})) {
        foreach (@$__revchanged__) {
            return 1 if lc $_ eq lc $column;
        }
        return 0;
    }
    return scalar @$__revchanged__;
}

### mt:RevDate functional tag
sub RevDate {
    my ($ctx, $args) = @_;

    my $rev = $ctx->stash ('revision')
        or return $ctx->error (MT->translate ('You used an [_1] tag outside of the proper context.', $ctx->stash ('tag')));
    $args->{ts} = $rev->created_on;
    return $ctx->build_date ($args);
}

### mt:RevDescription functional tag
sub RevDescription {
    my ($ctx, $args) = @_;

    my $rev = $ctx->stash ('revision')
        or return $ctx->error (MT->translate ('You used an [_1] tag outside of the proper context.', $ctx->stash ('tag')));
    return $rev->description || '';
}

### mt:RevNum functional tag
sub RevNum {
    my ($ctx, $args) = @_;

    my $rev = $ctx->stash ('revision')
        or return $ctx->error (MT->translate ('You used an [_1] tag outside of the proper context.', $ctx->stash ('tag')));
    return $rev->rev_number;
}

1;