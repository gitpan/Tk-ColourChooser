package Tk::ColourChooser ;    # Documented at the __END__.

# $Id: ColourChooser.pm,v 1.22 1999/09/04 17:51:52 root Exp root $

require 5.004 ;

use strict ;

use Tk ;
use Carp ;

require Tk::Toplevel ;

use vars qw( $VERSION @ISA ) ;

$VERSION = '1.17' ;

@ISA = qw( Tk::Toplevel ) ;

Construct Tk::Widget 'ColourChooser' ;


#############################
sub Populate { 
    my( $win, $args ) = @_ ;

    $args->{-title}  = 'Colour Chooser' unless defined $args->{-title} ;
    my $hexonly      = delete $args->{-hexonly} ;
    $win->{HEX_ONLY} = defined $hexonly and $hexonly ? 1 : 0 ;
    my $transparent  = delete $args->{-transparent} ;
    my $colour       = delete $args->{-colour} ;

    $win->SUPER::Populate( $args ) ;

    $win->withdraw ;
    $win->iconname( $args->{-title} ) ;
    $win->protocol( 'WM_DELETE_WINDOW' => sub { } ) ;
    $win->transient( $win->toplevel ) ;
    
    &_read_rgb( $win ) ;
    
    # Create listbox.
    my $Frame     = $win->Frame()->pack( -fill => 'x' ) ;
    $win->{COLOUR_FRAME} = $Frame ; 
    my $scrollbar = $Frame->Scrollbar->pack( -side => 'right', -fill => 'y' ) ;
    my $list      = $Frame->Listbox(
        -height          => 1,
        -selectmode      => 'single',
        -background      => 'white',
        -exportselection => 0,
        )->pack( -expand => 'ns', -fill => 'x', -pady => 20, -padx => 10 ) ;
    $list->configure( 
        -yscrollcommand => [ \&_listbox_scroll, $scrollbar, $list, $win ] ) ;
    $scrollbar->configure( -command => [ $list => 'yview' ] ) ;

    {
        my %cache ; # Memoise sort.
        $list->insert( 'end', sort {
                ( $cache{$a} ||= &_canonical_colour( $a ) ) cmp
                ( $cache{$b} ||= &_canonical_colour( $b ) ) 
            } keys %{$win->{NAME}} ) ;
    }

    $list->bind( '<Down>', [ \&_set_colour_from_list, $win ] ) ;
    $list->bind( '<Up>',   [ \&_set_colour_from_list, $win ] ) ;
    $list->bind( '<1>',    [ \&_set_colour_from_list, $win ] ) ;

    $win->{COLOUR_LIST} = $list ;

    &_set_list( $win, 0 ) ;

    # Colour sliders.
    foreach my $scale_name ( 'Red', 'Green', 'Blue' ) {
        my $scale = $win->Scale(
            -orient       => 'horizontal',
            -from         => 0,
            -to           => 255,
            -tickinterval => 25,
            -label        => $scale_name,
            -fg           => 'dark' . lc $scale_name,
            '-length'     => 300,
            )->pack( -fill => 'x' ) ;
        $win->{'-' . lc $scale_name} = 0 ;
        $scale->configure( 
            -variable => \$win->{'-' . lc $scale_name}, 
            -command  => [ \&_set_colour, $win ],
            ) ;
    }
 
    # Create buttons.
    $Frame  = $win->Frame()->pack() ;
    my $column = 0 ;
    foreach my $button ( 'OK', 'Transparent', 'Cancel' ) {
        next if $button eq 'Transparent' and 
                defined $transparent and
                        $transparent == 0 ;

        my $Button = $Frame->Button(
            -text      => $button,
            -underline => 0,
            -width     => 10,
            -command   => [ \&_close, $win, $button ],
            )->grid( -row => 0, -column => $column++, -pady => 5 ) ;
            
        my $char = lc substr( $button, 0, 1 ) ;

        $win->bind( "<Control-${char}>", [ \&_close, $win, $button ] ) ;
        $win->bind( "<Alt-${char}>",     [ \&_close, $win, $button ] ) ;
        $win->bind( "<${char}>",         [ \&_close, $win, $button ] ) ;
    }

    $win->bind( "<Return>", [ \&_close, $win, 'OK' ] ) ;
    $win->bind( "<Escape>", [ \&_close, $win, 'Cancel' ] ) ;

    # Set initial colour if given.
    if( defined $colour ) {
        if( $colour =~ 
            /^#?([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$/o ) {
            $win->{-red}   = hex $1 ; 
            $win->{-green} = hex $2 ; 
            $win->{-blue}  = hex $3 ;
        }
        else {
            my $hex = &_name2hex( $win, $colour ) ;
            $win->{-red}   = hex substr( $hex, 0, 2 ) ; 
            $win->{-green} = hex substr( $hex, 2, 2 ) ; 
            $win->{-blue}  = hex substr( $hex, 4, 2 ) ;
        }   
        &_set_colour( $win ) ; 
    }
 
    $win->{-colour} = undef ;
}


#############################
sub _canonical_colour {
    local $_ = lc shift ; 

    # We try to get similar colours to sort together.
    s/pale//o ;
    s/light//o ;
    s/medium//o ;
    s/dark//o ;
    s/deep//o ;
    s/grey/gray/o ;
    s/(\D)(\d)$/${1}0$2/o ;

    $_ ; 
}


#############################
sub _name2hex {

    my $win    = shift ;
    my $colour = shift ;

    my @colour ;
    # Valid colour names come in a variety so we try to find the one
    # intended...
    foreach my $i ( 0..9 ) {
        $colour[$i] = $colour ;      # Colour name 
    }
    $colour[1] =~ s/\s+//go ;        # Colourname
    $colour[2] = lc $colour ;        # colour name
    $colour[3] = $colour[2] ;
    $colour[3] =~ s/\b(\w)/\u$1/go ; # Colour Name
    $colour[4] = $colour[3] ;
    $colour[4] =~ s/\s+//go ;        # ColourName
    for my $i ( 5..9 ) {
        $colour[$i] =~ s/\d+$//o ;   # Remove trailing digits
    }

    my $hex ;

    foreach my $colour1 ( @colour ) {
        my $colour2 = $colour1 ;

        if( $colour1 =~ /[Gg]ray/o ) {
           $colour2 =~ s/([Gg])ray/${1}rey/go ; 
        }
        if( $colour1 =~ /[Gg]rey/o ) {
           $colour2 =~ s/([Gg])rey/${1}ray/go ; 
        }

        if( exists $win->{NAME}{$colour1} ) {
            $hex = $win->{NAME}{$colour1} ;
        }
        elsif( exists $win->{NAME}{$colour2} ) {
            $hex = $win->{NAME}{$colour2} ;
        }

        last if defined $hex ;
    }

    $hex or '000000' ;
}


#############################
sub _find_rgb {

    foreach my $file (
        '/usr/local/lib/X11/rgb.txt',       '/usr/lib/X11/rgb.txt', 
        '/usr/local/X11R5/lib/X11/rgb.txt', '/X11/R5/lib/X11/rgb.txt',
        '/X11/R4/lib/rgb/rgb.txt',          '/usr/openwin/lib/X11/rgb.txt',
        '/usr/X11R6/lib/X11/rgb.txt',
        ) {
        return $file if -e $file ;
    }
    carp "Failed to find an rgb.txt file" ;

    undef ;
}


#############################
sub _read_rgb {
    my $win = shift ;

    my $file = &_find_rgb ;

    if( defined $file ) {
        open RGB, $file or croak $! ;
        local $_ ;
        while( <RGB> ) {
            chomp ;
            my @array = split ; 
            if( scalar @array == 4 ) {
                my $hex = sprintf "%02X%02X%02X", @array[0..2] ;
                # We only use the first name for a given colour.
                if( not exists $win->{HEX}{$hex} ) {
                    $win->{HEX}{$hex}       = $array[3] ;
                    $win->{NAME}{$array[3]} = $hex ;
                }
            }
        }
        close RGB ;
    }

    $win->{NAME}{' Unnamed'} = '0000000' ;
}


#############################
sub _listbox_scroll {
    my( $scrollbar, $list, $win, @args ) = @_ ;

    $scrollbar->set( @args ) ;
    my $index = int( $list->size * $args[0] ) ;
    $list->activate( $index ) ;
    $list->selectionSet( $index ) ;
}


#############################
sub _set_colour {
    my $win = shift ;

    my $hex = sprintf "%02X%02X%02X", 
                $win->{-red}, $win->{-green}, $win->{-blue} ;

    my $index = 0 ;
    if( exists $win->{HEX}{$hex} ) {
        my $list = $win->{COLOUR_LIST} ;
        for( $index = 0 ; $index < $list->size ; $index++ ) {
            last if $list->get( $index ) eq $win->{HEX}{$hex} ;
        }                    
    }
    &_set_list( $win, $index ) ;

    $win->{COLOUR_FRAME}->configure( -bg => "#$hex" ) ;
}


#############################
sub _set_colour_from_list {
    my( $list, $win ) = @_ ;

    $list->selectionSet( 'active' ) ;
    my $colour     = $list->get( 'active' ) ;
    my $hex        = $win->{NAME}{$colour} ;
    $win->{-red}   = hex( substr( $hex, 0, 2 ) ) ; 
    $win->{-green} = hex( substr( $hex, 2, 2 ) ) ; 
    $win->{-blue}  = hex( substr( $hex, 4, 2 ) ) ; 

    $win->{COLOUR_FRAME}->configure( -bg => "#$hex" ) ;
}


#############################
sub _set_list {
    my( $win, $index ) = @_ ;

    my $list = $win->{COLOUR_LIST} ;
    $list->activate( $index ) ;
    $list->see( $index ) ;
    $list->selectionSet( $index ) ;
}


#############################
sub Show {
    my( $win ) = @_ ;

    croak "ColourChooser Show requires at least 1 argument" if scalar @_ < 1 ;

    my $old_focus = $win->focusSave ;
    my $old_grab  = $win->grabSave ;

    $win->Popup() ; 
    $win->grab ;
    $win->waitVisibility ;
    $win->update ;

    my $list = $win->{COLOUR_LIST} ;
    $list->focus ;

    $win->waitVariable( \$win->{-colour} ) ;

    $win->grabRelease ;
    $win->withdraw ;

    &$old_focus ;
    &$old_grab ;

    $win->{-colour} ;
}


#############################
sub _close {

    my $win ;
    while( ref $_[0] ) {
        $win = shift ;
        last if ref $win =~ /ColourChooser/o ;
    }
    my $button = shift ;

    if( $button eq 'Transparent' ) {
        $win->{-colour} = 'None' ;
    }
    elsif( $button eq 'Cancel' ) {
        $win->{-colour} = '' ;
    }
    else {
        my $hex = sprintf "%02X%02X%02X", 
                    $win->{-red}, $win->{-green}, $win->{-blue} ;
        if( exists $win->{HEX}{$hex} and not $win->{HEX_ONLY} ) {
            $win->{-colour} = $win->{HEX}{$hex} ;
        }
        else {
            $win->{-colour} = "#$hex" ;
        }
    }

    $win->{-colour} ;
}


1 ;


__END__

=head1 NAME

ColourChooser - Perl/Tk module providing a Colour selection dialogue box.

=head1 SYNOPSIS

    use Tk::ColourChooser ; 

    my $col_dialog = $Window->ColourChooser ;
    my $colour     = $col_dialog->Show ;
    if( $colour ) {
        # They pressed OK and the colour chosen is in $colour - could be
        # transparent which is 'None' unless -transparent is set.
    }
    else {
        # They cancelled.
    }

    # May optionally have the colour initialised.
    my $col_dialog = $Window->ColourChooser( -colour => 'green' ) ;
    my $col_dialog = $Window->ColourChooser( -colour => '#0A057C' ) ;

    # The title may also be overridden; and we can insist that only hex values
    # are returned rather than colour names. We can disallow transparent.
    my $col_dialog = $Window->ColourChooser( 
                        -title       => 'Select a colour',
                        -colour      => '0A057C',
                        -transparent => 0,
                        -hexonly     => 1,
                        ) ;

=head1 DESCRIPTION

ColourChooser is a dialogue box which allows the user to pick a colour from
the list in rgb.txt (supplied with X Windows), or to create a colour by
setting RGB (red, green, blue) values with slider controls.

You can scroll through all the named colours by using the <Down> and <Up>
arrow keys on the keyboard or by clicking the mouse on the scrollbar and then
clicking the colour list.

=head2 Options

=over 4
=item C<-title>  
This is optional and allows you to set the title. Default is 'Colour Chooser'.

=item C<-colour> 
This is optional and allows you to specify the colour that is shown when the
dialogue is invoked. It may be specified as a colour name from rgb.txt or as a
six digit hex number with an optional leading hash, i.e. as 'HHHHHH' or
'#HHHHHH'. Default is 'black'.

=item C<-hexonly>
This is optional. If set to 1 it forces the ColourChooser to only return
colours as hex numbers in Tk format ('#HHHHHH'); if set to 0 it returns
colours as names if they are named in rgb.txt, and as hex numbers if they have
no name. Transparent is always returned as 'None' however. Default is 0.

=item C<-transparent>
This is optional. If set to 0 it stops ColourChooser offering the Transparent
button so that only valid colours may be chosen - or cancel. Default is 1.
=back

The user has three options: 

=head2 OK

Pressing OK will return the selected colour, as a name if it has one or as an
RGB value if it doesn't. (Colours which do not have names are listed as
'Unnamed' in the colour list box.) If the C<-hexonly> option has been specified
the colour is always returned as a Tk colour hex value, i.e. in the form
'#HHHHHH' except if Transparent is chosen in which case 'None' is returned.

OK is pressed by a mouse click or <Return> or <o> or <Control-o> or <Alt-o>.

=head2 Transparent

Pressing Transparent will return the string 'None' which is xpm's name for
transparent.

Transparent is pressed by a mouse click or <t> or <Control-t> or <Alt-t>.

=head2 Cancel

Pressing Cancel will return an empty string.

Cancel is pressed by a mouse click or <Escape> or <c> or <Control-c> or <Alt-c>.

=head1 INSTALLATION

ColourChooser.pm should be placed in any Tk directory in any lib directory in
Perl's %INC path, for example, '/usr/lib/perl5/Tk'.

ColourChooser looks for the file rgb.txt on your system - if it can't find it
you will only be able to specify colours by RGB value.

=head1 BUGS

ColourChooser does almost no error checking.

ColourChooser can be slow to load because rgb.txt is large.

=head1 CHANGES

1999/01/29  First version.

1999/02/15  Improved handling of initial colour so that it copes better with
            the variety of valid colour name inputs.

1999/02/17  If a colour is given as lowercase hex it is now properly
            recognised.

1999/02/23  Should now be Windows compatible.

1999/03/02  Now when you scroll with the scrollbar both the colourname and the
            colour shown are updated (the same as when you move up and down
            with the arrow keys).

1999/04/21  Updating the colour when you move the scrollbar with the mouse 
            is buggy -- can't figure out why so have reverted.

1999/08/05  Just changed the files to make them more CPAN friendly.

1999/08/08  Changed licence to LGPL.

1999/08/29  Minor code changes.

1999/09/01  Added Makefile.PL.

1999/09/04  Removed ColourChooser.t - it was only a simple example but being
            interactive messes up CPAN's automatic testing. Plus tiny fixes.


=head1 AUTHOR

Mark Summerfield. I can be contacted as <summer@chest.ac.uk> -
please include the word 'colourchooser' in the subject line.

The code draws from Stephen O. Lidie's work.

=head1 COPYRIGHT

Copyright (c) Mark Summerfield 1999. All Rights Reserved.

This module may be used/distributed/modified under the LGPL. 

=cut


