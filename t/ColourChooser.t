#!/usr/bin/perl -w

use strict ;

use Tk ;
use Tk::ColourChooser ;

my $Win = MainWindow->new ;

my $colour = 'white' ;
while( 1 ) {
    my $col_dialog = $Win->ColourChooser( -colour => $colour, ) ;
    $colour        = $col_dialog->Show ;
    print STDERR "[$colour]\n" ;
    exit unless $colour ;
}

MainLoop ;
