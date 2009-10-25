#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $verbose             = 0;
my @standard_path_specs = qw( /etc/paths /etc/paths.d/ /etc/manpaths /etc/manpaths.d/ );

# determine the shell type by looking at the parent process
my $parent_pid          = getppid();
my $parent              = qx{ps -p $parent_pid};
my ( $shell )           = ( $parent =~ /((:?t?c|ba|k|z)?sh)\b/ );   # look for tcsh, csh, bash, ksh, zsh or sh in the parent process' name

# if no shell name could be found in the parent process, try the (unreliable) environment
$shell = $ENV{'SHELL'}  unless $shell;

# let the user decide which shell is to be used
GetOptions(
        'csh'     => sub { $shell = 'csh'   },
        'sh'      => sub { $shell = 'bash'  },
        'verbose' => \$verbose,
        ) or die "USAGE: $0 [-c] [-s] [-v] [<path files>...]\n";

die 'Unable to determine the type of shell you are using. Please specify -c or -s.' unless $shell;

my $command_format = ( $shell =~ /csh/ ) ? "setenv %s %s\n" : "export %s=%s\n";

# turn the list of files and directories into just a list of files which can be opened and read
my %have_seen  = ();
my @path_specs = ();
foreach ( @ARGV, @standard_path_specs )
    {
    my $path_spec = $_;     # COPY each value because @ARGV is read-only and we're about to do a s///
    $path_spec =~ s!/+!/!;
    $path_spec =~ s!/$!!;

    next if $have_seen{$path_spec}++;

    if( -f $path_spec )
        {
        push( @path_specs, $path_spec );
        next;
        }

    if( not opendir( PATH_SPEC, $path_spec ) )
        {
        printf STDERR "$0 Unable to open directory $path_spec: $!\n"                if $verbose;
        next;
        }

    foreach my $file ( readdir( PATH_SPEC ) )
        {
        next unless $file =~ /^\w/;
        push( @path_specs, "$path_spec/$file" );
        }

    closedir( PATH_SPEC );
    }

# actually read each path specification file
my @path    = ();
my @manpath = ();
foreach my $path_spec ( @path_specs )
    {
    if( not open( PATH_SPEC, "<", $path_spec ) )
        {
        printf STDERR "$0 Unable to read $path_spec: $!\n"                          if $verbose;
        next;
        }

    printf STDERR "$0 %s ...\n", $path_spec                                         if $verbose;

    while( my $dir = <PATH_SPEC> )
        {
        chomp( $dir );
        next if $dir =~ /^\s*(#.*)?$/;  # skip blank lines and comments

        while( $dir =~ s/\${?([^}:\/]+)}?/$ENV{$1}/g ) {};    # just keep doing the substitute until it fails

        if( not -d $dir )
            {
            printf STDERR "$0    Skipped $dir: directory not found\n"               if $verbose;
            next;
            }

        # only add to the normal PATH if the current directory was NOT
        # specified in a manpath file or looks like a man path.
        if( $path_spec !~ /manpath/ and $dir !~ /\bman\b/ )
            {
            if( $have_seen{$dir}++ )
                {
                printf STDERR "$0    Skipped duplicate path: $dir\n"                if $verbose;
                next;
                }

            printf STDERR "$0    adding path: $dir\n"                               if $verbose;
            push( @path, $dir );
            }

        # try deriving man paths from each $PATH directory
        # the first derivation is to do nothing - in case it was set in a manpath file.
        foreach my $suffix ( '', qw( man share/man ) )
            {
            $dir =~ s!/+[^/]+/*$!/$suffix!  if $suffix;

            if( not -d $dir )
                {
                printf STDERR "$0    Skipped $dir: man directory not found\n"       if $verbose and $path_spec =~ /manpath/ and not $suffix;
                next;
                }

            # side effect: since we have already added the 'bin' directories,
            # they wont be accidentally re-added to the manpath as well because
            # $have_seen{$dir} will be set
            if( $have_seen{$dir}++ )
                {
                printf STDERR "$0    Skipped duplicate man path: $dir\n"            if $verbose and $path_spec =~ /manpath/ and not $suffix;
                next;
                }

            printf STDERR "$0    adding man path: $dir\n"                           if $verbose;
            push( @manpath, $dir );
            }
        }

    close( PATH_SPEC );
    }

# add the existing PATH and MANPATH's to their respective paths
push( @path,    grep( ( not $have_seen{$_}++ and -d $_ ), split( ':', $ENV{'PATH'}    ) ) )     if $ENV{'PATH'};
push( @manpath, grep( ( not $have_seen{$_}++ and -d $_ ), split( ':', $ENV{'MANPATH'} ) ) )     if $ENV{'MANPATH'};

# print out the paths for evaluation by the shell
printf $command_format, 'PATH',     join( ':', @path )      if @path;
printf $command_format, 'MANPATH',  join( ':', @manpath )   if @manpath;

exit( 0 );

=head1 NAME

path_helper.pl - improvement on Apple's /usr/libexec/path_helper

=head1 SYNOPSIS

path_helper.pl [-c] [-s] [-v] [<path file>...]

=head1 DESCRIPTION

With Mac OS X 10.5 (Leopard), Apple introduced a program to help people set up
their PATH environment variable. Sadly, the program from Apple is very limited.

This perl script adds the ability to specify the names of files and the order
in which they should be read in addition to Apple's standard directories:
C</etc/paths.d> and C</etc/manpaths.d>

As with all PATH settings, care should be taken to ensure that 'important'
paths are specified first. Also, you should B<NEVER> have C<.> (the current
directory) in your path $PATH - it I<WILL> bite you one day if you do!

=head2 Features:

=over

* automatic shell detection

* removal of duplicate paths

* removal of non-existing paths

* automatic detection of related man paths

* inclusion of existing PATH and MANPATH variables

=back

=head1 USAGE

=head2 For sh, bash, ksh and zsh users:

    if [ -x /path/to/path_helper.pl ]
    then
        eval `/path/to/path_helper.pl`    # use -s if you get an error
    fi

=head2 For csh and tcsh users:

    if( -x /path/to/path_helper.pl ) then
        eval `/path/to/path_helper.pl`   # add -c if you get an error
    endif

=head1 OPTIONS

=over

=item -c

Produce c-shell style C<setenv> commands.

=item -s

Produce sh style C<export> commands.

=item -v

Be verbose when removing duplicate and/or non-existent paths.

=back

=head1 COPYRIGHT

Copyright 2009, Stephen Riehm, Munich, Germany

=head1 AUTHOR

Stephen Riehm <mgprot@opensauce.de>
