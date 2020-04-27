

CREATE                 PROCEDURE mmsMindBody_OldBusiness
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--THIS PROCEDURE RETURNS UNIQUE MEMBER ID FOR SELECTED Mind Body PRODUCTS
--WHICH OCCURRED IN THE PAST 3 MONTHS
--07/20/2010 MLL Removed creation and population of temporary table #Results

DECLARE @FirstOf3MonthsPrior DATETIME
DECLARE @EndOfLastMonth DATETIME

SET @FirstOf3MonthsPrior = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-3, GETDATE() - DAY(GETDATE()-1)),110),110)
SET @EndOfLastMonth = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(mi,-1,GETDATE() - DAY(GETDATE()-1)),110),110)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


EXEC dbo.mmsRevenuerpt_Revenue @FirstOf3MonthsPrior, @EndOfLastMonth, 'All', 'Mind Body', 'All' 

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
