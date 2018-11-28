#!/usr/bin/perl
#
# genero_textos.pl


use strict;
use POSIX;

sub trim($) ;
sub max($$) ;
sub genero_texto($$$$$;$;$$) ;


$::debug=0;


#############################
## cupos de los liceos
##

my %cupos;
open(CUPOS,"cupos.csv");
while(<CUPOS>) {
	next if (/^#/);
	next if (/^\s*$/);
	#if (/,/) {
	#	print "load_cupos: Se encontraron comas en el archivo cupos.csv y las cifras decimales hay que separarlas por puntos\n";
	#	exit(1);
	#}
	s/"//g;
	chop();
	@_ = split(',');

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
## turnos de los liceos
##

my %turnos;
open(GPT,"gpt_20181101.csv");
while(<GPT>) {
	next if (/^DEPENDID/);
	chop();
	@_ = split(',');

	$_[3] =~ s/E//;

	$turnos{$_[1]}{$_[3]} = 1;
}
close(GPT);

my @orden;
#open(ORDEN,"orden.txt");
#while(<ORDEN>) {
#	chop();
#	push @orden, $_;
#}
#close(ORDEN);

#############################
## resultado de la distribución
##

my (%tipodoc, %paisdoc, %destino, %alumnos);
open(DIST,"distribucionCCDD.csv");
while(<DIST>) {
	next if (/^(\xEF\xBB\xBF)?"?[dD]ocumento/);
	chop();
	@_ = split(',');

	for (my $i=0; $i<=$#_; $i++) {
		$_[$i] =~ s/^ *"(.*)" *$/$1/;
	}

	if (defined($destino{$_[0]})) {
		print STDERR "ERROR: El documento $_[0] está repetido y este script no lo soporta\n";
		exit(1);
	}

	$tipodoc{$_[0]} = $_[1];
	$paisdoc{$_[0]} = $_[2];
	$destino{$_[0]} = $_[3];

	$_[3] =~ s/-49$//;
	
	$alumnos{$_[3]}{$_[0]} = 1;

	# uso el orden definido en este archivo
	push @orden, $_[0];
}
close(DIST);

# planes: día turno/alt frecuencia horario
my @planes = (
	{ dia =>  5, 2 => {desde => '14:00', hasta => '17:45', frecuencia=>2},
	             3 => {desde => '16:00', hasta => '18:00', frecuencia=>2},
	             1 => {desde => '08:00', hasta => '11:45', frecuencia=>2} },
	{ dia =>  6, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3},
	             3 => {desde => '16:00', hasta => '20:00', frecuencia=>3} },
	{ dia =>  7, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
	{ dia => 10, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
	{ dia => 12, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
	{ dia => 13, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
);


my %horarios;
foreach my $dependid (sort {$a <=> $b} keys %alumnos) {

	if (!defined($cupos{$dependid}) || !defined($cupos{$dependid}{grupos})) {
		print STDERR "ERROR: El liceo $dependid no tiene cupos\n";
		exit(1);
	}

	my $alumnos = scalar(keys %{$alumnos{$dependid}});
	($::debug>2) and print STDERR "$dependid: ".$alumnos." grupos=".$cupos{$dependid}{grupos}." apg=".int($alumnos/$cupos{$dependid}{grupos})."\n";

	if ($::debug && !defined($turnos{$dependid}{1})) {
		print STDERR "$dependid no tiene turno 1\n";
	}
	if ($::debug && !defined($turnos{$dependid}{2})) {
		print STDERR "$dependid no tiene turno 2\n";
	}

	# Recorro los alumnos en orden predefinido
	my @alumnos;
	for $_ (@orden) {
		(defined($alumnos{$dependid}{$_})) and push @alumnos, $_;
	}

	for my $plan (@planes) {
		last if ($#alumnos < 0);

		my $dia = $plan->{dia};
		my $encontre_turno = 0;

		foreach my $turnobase (1,2,3,'alt') {
			my $turno = $turnobase;
			last if ($#alumnos < 0);
			next if (!defined($plan->{$turno}));
			next if (!defined($turnos{$dependid}{$turno}) && !(!$encontre_turno && $turno eq 'alt'));

			$encontre_turno = defined($turnos{$dependid}{$turno});

			$plan->{$turno}{desde} =~ /(\d\d):(\d\d)/;
			my $hora = $1;
			my $minuto = $2;
			my $puesto = 1;
			(defined($horarios{$dependid}{$dia}{desde})) or $horarios{$dependid}{$dia}{desde} = sprintf "%02d:%02d",$hora,$minuto;
			$horarios{$dependid}{$dia}{$turno}{frecuencia} += $plan->{$turno}{frecuencia};

			while (my $cedula = shift @alumnos) {

				($horarios{$dependid}{$dia}{hasta} > sprintf "%02d:%02d",$hora,$minuto) or $horarios{$dependid}{$dia}{hasta} = sprintf "%02d:%02d",$hora,$minuto;

				if (floor($dependid/100) == 10 || floor($dependid/100) == 2 || floor($dependid/100) == 9) {
					# MONTEVIDEO, CANELONES Y MALDONADO

					genero_texto(\%direcciones,$cedula,$tipodoc{$cedula},$paisdoc{$cedula},$dependid,$dia,$hora,$minuto);

				} else {
					# INTERIOR
					genero_texto(\%direcciones,$cedula,$tipodoc{$cedula},$paisdoc{$cedula},$dependid,$dia);

					$horarios{$dependid}{$dia}{cantidad}++;
				}

				$puesto ++;
				if ($puesto > $plan->{$turno}{frecuencia}) {
					$puesto = 1;
					$minuto += 15;
					if ($minuto == 60) {
						$minuto = 0;
						$hora ++;
					}
					last if ($plan->{$turno}{hasta} lt sprintf "%02d:%02d",$hora,$minuto);
				}
			}
		}
	}
}

foreach my $dependid (sort {$a <=> $b} keys %horarios) {
	foreach my $dia (sort {$a <=> $b} keys %{$horarios{$dependid}}) {
		if (floor($dependid/100) == 10 || floor($dependid/100) == 2 || floor($dependid/100) == 9) {
			# MONTEVIDEO, CANELONES Y MALDONADO
			printf STDERR "%d\t%s\t%s",$dependid,$direcciones{$dependid}{DeptoNombre},$direcciones{$dependid}{DependDesc};
			printf STDERR "\tdía %s","$dia/12 desde $horarios{$dependid}{$dia}{desde} hasta $horarios{$dependid}{$dia}{hasta} con ".max(max($horarios{$dependid}{$dia}{1}{frecuencia},$horarios{$dependid}{$dia}{2}{frecuencia}),$horarios{$dependid}{$dia}{alt}{frecuencia})." alumnos cada 15 minutos";
		} else {
			# INTERIOR
			printf STDERR "%d\t%s\t%s",$dependid,$direcciones{$dependid}{DeptoNombre},$direcciones{$dependid}{DependDesc};
			printf STDERR "\tdía %s con %d alumno(s), usar %d puestos","$dia/12",$horarios{$dependid}{$dia}{cantidad},max(max($horarios{$dependid}{$dia}{1}{frecuencia},$horarios{$dependid}{$dia}{2}{frecuencia}),$horarios{$dependid}{$dia}{alt}{frecuencia});
		}
		print STDERR "\n";
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

sub max($$) {
	return ($_[0] >= $_[1] ? $_[0] : $_[1]);
}

sub genero_texto($$$$$;$;$$) {
	my ($rdirecciones,$documento,$tipodoc,$paisdoc,$dependid,$dia,$hora,$minuto) = @_;

	if (!defined($direcciones{$dependid}{LugarDireccion})) {
		print STDERR "ERROR: No está definida la dirección para la dependencia $dependid\n";
		exit(1);

	}

	if (defined($hora) && !defined($minuto)) {
		print STDERR "ERROR: genero_texto: hora=$hora minuto=$minuto\n";
		exit(1);
	}

	my $inicio = "Para la inscripción 2019 debe ir al";
	my $complemento = "\n- Cédula de Identidad y Carné de Salud Adolescente del alumno\n- Cédula del adulto responsable de la inscripción\n\nConsejo de Educación Secundaria";

	if (defined($dia) && defined($hora) && defined($minuto)) {

		if ($dependid>1000 && $dependid<1100) {
			printf '"%s","%s","%s","%s Liceo Nº %2d (%s) el %d de diciembre a las %02d:%02d llevando:%s"',$documento,$tipodoc,$paisdoc,$inicio,$dependid%100,$rdirecciones->{$dependid}{LugarDireccion},$dia,$hora,$minuto,$complemento;
		} else {
			printf '"%s","%s","%s","%s Liceo de %s (%s) el %d de diciembre a las %02d:%02d llevando:%s"',$documento,$tipodoc,$paisdoc,$inicio,$direcciones{$dependid}{DependDesc},$direcciones{$dependid}{LugarDireccion},$dia,$hora,$minuto,$complemento;
		}

	} elsif (defined($dia)) {
		printf '"%s","%s","%s","%s Liceo de %s (%s) el %d de diciembre llevando:%s"',$documento,$tipodoc,$paisdoc,$inicio,$direcciones{$dependid}{DependDesc},$direcciones{$dependid}{LugarDireccion},$dia,$complemento;

	} else {
		printf '"%s","%s","%s","%s Liceo de %s (%s) llevando:%s"',$documento,$tipodoc,$paisdoc,$inicio,$direcciones{$dependid}{DependDesc},$direcciones{$dependid}{LugarDireccion},$complemento;
	}
	print "\n";
}
