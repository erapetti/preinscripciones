SELECT DependId,DeptoId,DeptoNombre,LugarId,LugarDesc,LocId,LocNombre,concat(DirViaNom,if(DirNroPuerta is null,'',concat(' ',DirNroPuerta)),if(DirKm is null,'',concat(' Km. ',DirKm)),if(DirViaNom1 is null,'',if(DirViaNom2 is null,concat(' esq. ',DirViaNom1),concat(' entre ',DirViaNom1,if(DirViaNom2 like 'i%' or DirViaNom2 like 'hi%',' e ',' y '),DirViaNom2)))) LugarDireccion,DependDesc       FROM DEPENDENCIAS d       JOIN DEPENDLUGAR USING (DependId)       JOIN LUGARES l USING (LugarId)       JOIN DEPARTAMENTO USING (DeptoId)       JOIN LOCALIDAD USING (DeptoId,LocId)       JOIN Direcciones.DIRECCIONES       ON LugarDirId=DirId       WHERE dependtipid=2 and dependsubtipid=1       AND d.StatusId=1       AND l.StatusId=1       AND DependLugarStatusId=1 and dependid=lugarid;

