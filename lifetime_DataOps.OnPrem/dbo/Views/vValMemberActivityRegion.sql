CREATE VIEW dbo.vValMemberActivityRegion AS 
SELECT ValMemberActivityRegionID,Description,SortOrder
FROM MMS.dbo.ValMemberActivityRegion WITH(NOLOCK)
