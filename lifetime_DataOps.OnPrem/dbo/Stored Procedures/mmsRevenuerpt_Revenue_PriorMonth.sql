

-- =============================================
-- Object:			dbo.mmsRevenuerpt_Revenue_PriorMonth
-- Author:			Greg Burdick
-- Create date: 	3/3/2008
-- Description:		This proc runs dbo.mmsRevenuerpt_Revenue for the prior month
-- 
-- Parameters:		date range and 'All' for All Clubs with a Department of Mind Body
-- Modified date:	
-- 
-- EXEC mmsRevenuerpt_Revenue_PriorMonth
--
-- =============================================

CREATE           PROC [dbo].[mmsRevenuerpt_Revenue_PriorMonth]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @FirstOfPriorMonth SMALLDATETIME
DECLARE @LastOfPriorMonth SMALLDATETIME

SET @FirstOfPriorMonth = DATEADD(mm, -1, CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,GETDATE(),112),1,6) + '01', 112))
SET @LastOfPriorMonth = DATEADD(dd, -1, CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,GETDATE(),112),1,6) + '01', 112)) + '11:59 PM'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsRevenuerpt_Revenue @FirstofPriorMonth, @LastOfPriorMonth,
	'All', 'Merchandise', 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
