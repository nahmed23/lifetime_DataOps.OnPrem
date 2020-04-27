
--
-- Purpose:	Used by a scheduled job to return all the Aquatics revenue allocated to the current reporting month
-- Author:	Ruslan Condratiuc (12/11/2009)
-- 
-- 

CREATE     PROC [dbo].[mmsDeferredRevenueDept_SingleMonthsAllocation_MTD_Aquatics_Obsolete]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @YearMonth INT

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @YearMonth  =  SUBSTRING(CONVERT(VARCHAR,@Yesterday,112),1,6)
  
-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsDeferredRevenueDept_SingleMonthsAllocation @YearMonth,'Aquatics'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
