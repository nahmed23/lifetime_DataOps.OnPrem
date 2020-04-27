







--
-- This procedure returns all of the Polar product sales for yesterday's month for all clubs
-- This takes the same transactions collected for the DSSR and displays them in a way more 
-- useful to the people directly involved with Polar HRM product sales.
--


CREATE          PROCEDURE dbo.mmsPolarSales_Detail 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME

  SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT DSSR.ProductID, DSSR.ProductDescription, DSSR.PostDateTime, DSSR.ItemAmount, DSSR.TranClubName, 
 DSSR.TranClubID, VTT.Description AS TranTypeDescription, @Yesterday As ReportDate
FROM dbo.vDSSRSummary  DSSR
 JOIN dbo.vMMSTran T
   ON T.MMSTranID=DSSR.MMSTranID
 JOIN dbo.vValTranType VTT
   ON T.ValTranTypeID = VTT.ValTranTypeID
WHERE DSSR.ProductDescription LIKE '%Polar%' AND 
   DSSR.PostDateTime>= @FirstOfMonth AND 
   DSSR.PostDateTime< @ToDay 

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END







