
-- =============================================
-- Object:			dbo.mmsAutomatedRefunds_Check_Refunds_scheduled
-- Author:			Greg Burdick
-- Create date: 	2/19/2009 dbcr_4171 deploying 2/25/09
-- Description:		This procedure calls the on-demand version of the same name 
--					supplying data for MMS661, Member Relations Check Refund Log Report (scheduled version)
-- Modified date:	
-- Exec mmsAutomatedRefunds_Check_Refunds_scheduled '1', 'All', '2/11/2009 02:00 PM', '2/18/2009 02:00 PM'
-- =============================================

CREATE        PROC [dbo].[mmsAutomatedRefunds_Check_Refunds_scheduled]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @PreviousWed DATETIME
DECLARE @CurrentWed DATETIME

SET @CurrentWed  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE() + (4 - (DATEPART(dw, GETDATE()))), 102), 102) + '2:00 PM'
SET @PreviousWed  =  DATEADD(week, -1, @CurrentWed)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsAutomatedRefunds_Check_Refunds  '1', 'All' , @PreviousWed, @CurrentWed

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
