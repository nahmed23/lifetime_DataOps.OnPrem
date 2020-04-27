
CREATE VIEW [dbo].[vDrawer] AS SELECT DrawerID,ClubID,LockedFlag,Description,StartingCashAmount 
FROM MMS.dbo.Drawer With (NOLOCK)
