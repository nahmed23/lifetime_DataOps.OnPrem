



CREATE VIEW dbo.vServerName
	(srvid
	,ServerName 
	)
AS  
 SELECT  srvid,srvname
 from master.dbo.sysservers
   where srvid = 0



