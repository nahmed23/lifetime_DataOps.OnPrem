
-- =============================================
-- Object:			dbo.mmsRevenuerpt_Revenue_MTD_Tennis
-- Author:			Greg Burdick
-- Create date: 	5/15/08
-- Description:		This proc calculates yesterday's date and 
--					what the first day of that Month is.

-- Parameters:		date range (@FirstOfMonth and @ToDay)
--					'All' for All Clubs
--					'Tennis' for Department
--					'All' for all products
-- Modified date:	
-- 	
-- EXEC mmsRevenuerpt_Revenue_MTD_Tennis
-- ==============================================

CREATE           PROC [dbo].[mmsRevenuerpt_Revenue_MTD_Tennis]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)
--
--   SET @FirstOfMonth  =  '07/01/07'
--   SET @ToDay  =  '07/31/07'
--

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsRevenuerpt_Revenue @FirstofMonth, @ToDay,
	'All', 'Tennis', 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
