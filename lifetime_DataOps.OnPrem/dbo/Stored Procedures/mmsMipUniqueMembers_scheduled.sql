
-- =============================================
-- Object:			mmsMipUniqueMembers_scheduled
-- Author:			Greg Burdick
-- Create date: 	11/25/2008, released 11/26/2008 dbcr_3885a
-- Description:		
-- Modified date:	
-- Exec mmsMipUniqueMembers_scheduled
-- =============================================

CREATE PROC [dbo].[mmsMipUniqueMembers_scheduled]

AS
BEGIN

	SET XACT_ABORT ON
	SET NOCOUNT ON


	--Report Logging
	DECLARE @Identity AS INT
	INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
	SET @Identity = @@IDENTITY

	DECLARE @FirstOfCurrentMonth DATETIME
	DECLARE @Yesterday DATETIME

	SET @FirstOfCurrentMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, GETDATE(), 112),1, 6) + '01', 112)
	SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))+ ' 11:59 PM'

--	SELECT @FirstOfCurrentMonth, @Yesterday
	EXEC dbo.mmsMipUniqueMembers 'All', @FirstOfCurrentMonth, @Yesterday

	-- Report Logging
	UPDATE HyperionReportLog
	SET EndDateTime = getdate()
	WHERE ReportLogID = @Identity

END
