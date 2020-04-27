CREATE VIEW dbo.vValGuestAccessMethod AS 
SELECT ValGuestAccessMethodID,Description,SortOrder
FROM MMS.dbo.ValGuestAccessMethod WITH(NOLOCK)
