use ExtUtils::MakeMaker ;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'         => 'Tk::ColourChooser',
    'VERSION_FROM' => 'ColourChooser.pm', # finds $VERSION
    'DISTNAME'     => 'TK-ColourChooser',
    ($] >= 5.005 ?
        (
            ABSTRACT => 'Dialogue for choosing colour by name or RGB value',
            AUTHOR   => 'Mark Summerfield <summer@chest.ac.uk>',
        ) : () ),
    'LIBS'         => [''],   # e.g., '-lm'
    'DEFINE'       => '',     # e.g., '-DHAVE_SOMETHING'
    'INC'          => '',     # e.g., '-I/usr/include/other'
    'dist'         => { COMPRESS => "gzip -9", SUFFIX => "gz" }
) ;
