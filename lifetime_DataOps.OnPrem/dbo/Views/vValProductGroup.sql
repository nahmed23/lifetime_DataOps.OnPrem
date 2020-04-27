
CREATE VIEW [dbo].[vValProductGroup] AS
SELECT ValProductGroupID,
Description,
SortOrder,
MemberActivitiesSortOrder,
TennisSortOrder,
AquaticsSortOrder,
RevenueReportingDepartment,
RevenueReportingRegionType
FROM Report_MMS.dbo.ValProductGroup WITH(NOLOCK)
