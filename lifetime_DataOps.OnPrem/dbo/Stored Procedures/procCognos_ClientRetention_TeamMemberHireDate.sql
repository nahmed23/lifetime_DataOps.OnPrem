
CREATE PROC [dbo].[procCognos_ClientRetention_TeamMemberHireDate] (
@StartFourDigitYearDashTwoDigitMonth VARCHAR(7)											
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

----
---- sample execution:
---- Exec procCognos_ClientRetention_TeamMemberHireDate '2015-06'
----

DECLARE @OneYearPrior DateTime
SET @OneYearPrior = (SELECT MIN(PriorYearDate) 
                       FROM vReportDimDate 
					   WHERE FourDigitYearDashTwoDigitMonth = @StartFourDigitYearDashTwoDigitMonth)

Select EmployeeID,HireDate, TerminationDate
From vEmployee 
Where IsNull(TerminationDate,GetDate()) > @OneYearPrior
Order by EmployeeID


END
