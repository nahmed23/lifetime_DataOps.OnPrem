
-- =============================================
-- Object:			mmsDeferredNonDeferredRevenue_Scheduled
-- Author:			Greg Burdick
-- Create date: 	8/13/2008
-- Description:		
-- Modified date:	
-- Exec mmsDeferredNonDeferredRevenue_Scheduled
-- =============================================

CREATE PROC [dbo].[mmsDeferredNonDeferredRevenue_Scheduled]

AS
BEGIN

	SET XACT_ABORT ON
	SET NOCOUNT ON


	--Report Logging
	DECLARE @Identity AS INT
	INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
	SET @Identity = @@IDENTITY

	DECLARE @FirstOfPreviousMonth DATETIME
	DECLARE @PreviousMonthYear INT
	DECLARE @PreviousMonth INT

	SET @FirstOfPreviousMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, DATEADD(month, -1, GETDATE()), 112),1, 6) + '01', 112)
	SET @PreviousMonthYear  =  YEAR(@FirstOfPreviousMonth)
	SET @PreviousMonth = MONTH(@FirstOfPreviousMonth)

--	SELECT @FirstOfPreviousMonth FirstOfPreviousMonth, @PreviousMonthYear PrevMonthYear, @PreviousMonth PrevMonth
	EXEC dbo.mmsDeferredNonDeferredRevenue 'All', @PreviousMonthYear, @PreviousMonth

	-- Report Logging
	UPDATE HyperionReportLog
	SET EndDateTime = getdate()
	WHERE ReportLogID = @Identity

END
