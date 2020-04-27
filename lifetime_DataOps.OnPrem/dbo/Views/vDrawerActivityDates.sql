


CREATE VIEW dbo.vDrawerActivityDates         (DrawerActivityID
	 ,DrawerID
	 ,OpenDateTime
	 ,CloseDateTime
	 ,OpenEmployeeID
	 ,CloseEmployeeID
	 ,ValDrawerStatusID)
AS SELECT DrawerActivityID
	 ,DrawerID
	 ,CONVERT(CHAR(12),OpenDateTime,101)
	 ,CONVERT(CHAR(12),CloseDateTime,101)
	 ,OpenEmployeeID
	 ,CloseEmployeeID
	 ,ValDrawerStatusID
    FROM MMS.dbo.DrawerActivity WITH(NOLOCK)
   UNION
   SELECT -10
	,DrawerID
	,Null
	,Null
	,Null
	,Null
	,ValDrawerStatusID        
  FROM MMS.dbo.Drawer WITH(NOLOCK)
      ,MMS.dbo.ValDrawerStatus WITH(NOLOCK)


