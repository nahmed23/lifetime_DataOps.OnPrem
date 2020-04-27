
CREATE PROCEDURE [dbo].[mmsMemberActivities_RevenueAllocation_Scheduled] AS
BEGIN
	-- Report Logging
	DECLARE @Identity AS INT
	INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
	SET @Identity = @@IDENTITY

	DECLARE @Year as int
	-- January 1st
	IF (DAY(GETDATE()) = 1 and MONTH(GETDATE())=1)  
		SET @Year = YEAR(GETDATE()-1)	
	ELSE
		SET @Year = YEAR(GETDATE())	

	EXEC dbo.mmsDeferredRevenueDept_AnnualAllocation @Year,'Member Activities' ---- modified 9/10/08 srm

	-- Report Logging
	UPDATE HyperionReportLog
	SET EndDateTime = getdate()
	WHERE ReportLogID = @Identity
END
