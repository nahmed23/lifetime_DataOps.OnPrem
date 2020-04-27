

---------------------------  mmsDeferredRevenueDept_SingleMonthsAllocation_MTD_AllDepts  ---------------------------
CREATE     PROC [dbo].[mmsDeferredRevenueDept_SingleMonthsAllocation_MTD_AllDepts]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	============================================================================
	Object:			dbo.mmsDeferredRevenueDept_SingleMonthsAllocation_MTD_AllDepts
	Author:			Greg Burdick
	Create Date:	3/2/2010
	Description:	This stored procedure returns revenue allocated to the current reporting month for
					all programs/product groups passed to the main stored procedure
	Modified:		

	EXEC mmsDeferredRevenueDept_SingleMonthsAllocation_MTD_AllDepts 
    1/24/2011 BSD Replaced Aquatics|Basketball|Birthday Parties|Camps|Dance|Martial Arts|Mixed Combat Arts|Events|Pro Shop|Rockwall|Squash - Racquetball|Tennis|Yoga|Youth Fitness
                  paramter with 'All' - new code in called stored procedure
    6/22/2010 MLL Replaced "Dance and Martial Arts" with "Dance", "Martial Arts" and "Mixed Combat Arts" 
                  on parameter call
	============================================================================	*/


  DECLARE @Yesterday DATETIME
  DECLARE @YearMonth INT

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @YearMonth  =  SUBSTRING(CONVERT(VARCHAR,@Yesterday,112),1,6)
  
-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsDeferredRevenueDept_SingleMonthsAllocation @YearMonth,'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
