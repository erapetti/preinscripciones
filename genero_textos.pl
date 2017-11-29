#!/usr/bin/perl
#
# genero_textos.pl


use strict;

#############################
## cupos de los liceos
##

my %cupos;
open(CUPOS,"cupos.csv");
while(<CUPOS>) {
	next if (/^#/);
	next if (/^\s*$/);
	if (/,/) {
		print "load_cupos: Se encontraron comas en el archivo cupos.csv y las cifras decimales hay que separarlas por puntos\n";
		exit(1);
	}

	s/"//g;
	chop();
	@_ = split('\t');

	if (!defined($cupos{$_[0]})) {
		# primera vez que aparece este centro en el archivo
		$cupos{$_[0]} = {apg=>$_[1], grupos=>$_[2], cupo=>$_[1]*$_[2], reserva=>0, total=>$_[1]*$_[2]};
	} elsif ($_[2] > 0) {
		# acumulo los valores con lo que ya tenía
		$cupos{$_[0]}{grupos} += $_[2];
		$cupos{$_[0]}{cupo} += $_[1]*$_[2];
		$cupos{$_[0]}{apg} = $cupos{$_[0]}{cupo} / $cupos{$_[0]}{grupos};
		$cupos{$_[0]}{reserva} = 0; # nop
		$cupos{$_[0]}{total}  = $cupos{$_[0]}{cupo} - 0;
	}
}
close(CUPOS);

# redondeo los decimales
foreach $_ (keys %cupos) {
	$cupos{$_}{cupo} = int($cupos{$_}{cupo});
}


#############################
## direcciones de los liceos
##

my %direcciones;
open(DIRECCIONES,"direcciones.csv");
while(<DIRECCIONES>) {
	chop();
	s/  +/ /g;
	s/ ?, ?/,/g;
	s/ $//;
	@_ = split(',');

	$direcciones{$_[0]} = {DeptoId=>$_[1],DeptoNombre=>$_[2],LugarId=>$_[3],LugarDesc=>$_[4],LocId=>$_[5],LocNombre=>$_[6],LugarDireccion=>$_[7],DependDesc=>$_[8]};
}
close(DIRECCIONES);


#############################
## resultado de la distribución
##

my %destino;
my %alumnos;
open(DIST,"distribucionCCDD.csv");
while(<DIST>) {
	next if (/^Documento/);
	chop();
	@_ = split(',');


	$destino{$_[0]} = $_[1];

	$_[1] =~ s/-49$//;
	
	$alumnos{$_[1]}{$_[0]} = 1;
}
close(DIST);


foreach my $dependid (sort {$a <=> $b} keys %alumnos) {

	if (!defined($cupos{$dependid}) || !defined($cupos{$dependid}{grupos})) {
		print STDERR "ERROR: El liceo $dependid no tiene cupos\n";
		exit(1);
	}
	print STDERR "$dependid: ".scalar(keys %{$alumnos{$dependid}})." grupos=".$cupos{$dependid}{grupos}." apg=".int(scalar(keys %{$alumnos{$dependid}})/$cupos{$dependid}{grupos})."\n";

	my $dia = 12;
	my $hora = 13;
	my $minuto = 45;
	my $puesto = 0;
	foreach my $cedula (keys $alumnos{$dependid}) {

		if ($dependid>1000 && $dependid<1100) {
			# MONTEVIDEO
			printf "%s,%sPara la inscripción 2018 debe ir al Liceo Nº %2d (%s) el %d de diciembre a las %02d:%02d llevando:\n- Cédula de Identidad y Carné de Salud Adolescente del alumno\n- Cédula del adulto responsable de la inscripción\n\nConsejo de Educación Secundaria%s\n",$cedula,'"',$dependid%100,$direcciones{$dependid}{LugarDireccion},$dia,$hora,$minuto,'"';
		} else {
			# INTERIOR
			printf "%s,%sPara la inscripción 2018 debe ir al Liceo de %s (%s) el %d de diciembre llevando:\n- Cédula de Identidad y Carné de Salud Adolescente del alumno\n- Cédula del adulto responsable de la inscripción\n\nConsejo de Educación Secundaria%s\n",$cedula,'"',$direcciones{$dependid}{DependDesc},$direcciones{$dependid}{LugarDireccion},$dia,'"';
		}

		$puesto ++;
		if ($puesto == 4 || ($puesto == 3 && scalar(keys %{$alumnos{$dependid}}) < 280) || ($puesto == 2 && $dia == 12)) {
			$puesto = 0;
			$minuto += 15;
			if ($minuto == 60) {
				$minuto = 0;
				$hora++;
				if ($hora == 12) {
					$hora = 13;
					$minuto = 45;
				} elsif ($hora == 17) {
					$hora = 8;
					$dia++;
					if ($dia == 16) {
						print STDERR "ERROR: Se terminó el período de inscripción para $dependid y aún quedan alumnos\n";
						exit (1);
					}
				}
			}
		}
	}
}

exit(0);

######################################################################


sub trim($) {
	my ($texto) = @_;

	$texto =~ s/^ +//;
	$texto =~ s/ +$//;

	return $texto;
}
