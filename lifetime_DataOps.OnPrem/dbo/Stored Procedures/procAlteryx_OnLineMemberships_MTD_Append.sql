


CREATE PROC [dbo].[procAlteryx_OnLineMemberships_MTD_Append] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

--- This stored procedure is executed by Alteryx which inserts the resulting records
--- into the Sandbox table "[rep].[OnLineMemberships]"


DECLARE @ReportRunDateTime DATETIME
SET @ReportRunDateTime = GetDate()


 ----- Table will continue to retrieve the prior month's data for 3 days into the new month
DECLARE @ReportMonthFourDigitYearDashTwoDigitMonth Varchar(7)
SET @ReportMonthFourDigitYearDashTwoDigitMonth = (SELECT FourDigitYearDashTwoDigitMonth FROM vReportDimDate WHERE CalendarDate = Cast(DateAdd(Day,-3,@ReportRunDateTime) as Date))



Select Membership.MembershipID,
       Membership.CreatedDateTime AS MembershipCreatedDateTime,
	   DimDate.FourDigitYearDashTwoDigitMonth AS MembershipCreatedMonth,
       MembershipAttribute.AttributeValue AS SourceSystemTransactionID
FROM vMembership Membership
 JOIN vReportDimDate DimDate
   ON Cast(Membership.CreatedDateTime as Date) = DimDate.CalendarDate
 LEFT JOIN vMembershipAttribute MembershipAttribute
   ON MembershipAttribute.MembershipID = Membership.MembershipID
   AND MembershipAttribute.ValMembershipAttributeTypeID = 9   ----- "Source Transaction ID"
 WHERE Membership.ValMembershipSourceID = 8   ----- "From Internet-OMS"
   AND DimDate.FourDigitYearDashTwoDigitMonth = @ReportMonthFourDigitYearDashTwoDigitMonth
 Order by Membership.CreatedDateTime

END
