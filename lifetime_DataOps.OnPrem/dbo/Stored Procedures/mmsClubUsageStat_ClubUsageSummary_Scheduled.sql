
-- =============================================
-- Object:			mmsClubUsageStat_ClubUsageSummary_Scheduled
-- Author:			
-- Create date: 	
-- Description:		Club Usage Sammry: all clubs MTD
-- Modified date:	8/1/2008 GRB; added conditional logic to handle first of month situation

-- Exec mmsClubUsageStat_ClubUsageSummary_Scheduled
-- =============================================

CREATE PROC [dbo].[mmsClubUsageStat_ClubUsageSummary_Scheduled]

AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON


  --Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  DECLARE @FirstOfMonth DATETIME
  DECLARE @Today DATETIME

  IF DAY(GETDATE()) = 1
	BEGIN
		SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, DATEADD(month, -1, GETDATE()), 112),1, 8), 112)
								-- '7/1/08'
	END
  ELSE  
	BEGIN
--		SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, @Today, 112),1,6) + '01', 112)	8/1/2008 GRB
		SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, GETDATE(), 112),1,6) + '01', 112)
	END

  		SET @Today  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)


  EXEC dbo.mmsClubUsageStat_ClubUsageSummary 'All', @FirstOfMonth, @Today 

  -- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
