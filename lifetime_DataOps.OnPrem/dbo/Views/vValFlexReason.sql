CREATE VIEW dbo.vValFlexReason AS 
SELECT ValFlexReasonID,Description,SortOrder
FROM MMS.dbo.ValFlexReason WITH(NOLOCK)
