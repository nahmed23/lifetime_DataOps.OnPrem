

-- =============================================
-- Object:			dbo.mmsPT_PRWorksheet_FromExtractTable
-- Author:			Susan Myrick
-- Create date: 	4/16/2009
-- Release date:	4/22/2009 dbcr_4445
-- Description:		Returns recordset from PT Payroll Worksheet Extract source table
-- Parameters:		To be used by a scheduled report job. Calculated to return the current pay period
--					 
-- 
-- =============================================

CREATE  PROC [dbo].[mmsPT_PRWorksheet_FromExtractTable]
AS
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


Select PGR.ClubID, C.ClubName, R.Description as RCLRegion,PGR.ValPTProductGroupID,
PG.Description,PGR.EmployeeID, E.FirstName, E.LastName,PGR.PayPeriod,
PGR.SalesRevenueTotal, PGR.ServiceRevenueTotal,PG.SortOrder,
Convert(DATETIME,(Convert(Varchar,GETDATE()-1,112)+' 23:59:00')) AS Yesterday,
CASE WHEN Substring(PGR.PayPeriod,7,1) = 1
	 THEN Convert(DATETIME,Substring(PGR.PayPeriod,1,6)+'01',110)
	 ELSE Convert(DATETIME,Substring(PGR.PayPeriod,1,6)+'16',110)
	 END PeriodStartDate
from vPTProductGroupRevenue PGR
JOIN vClub C
On PGR.ClubID = C.ClubID
Join vValPTRCLArea R
On R.ValPTRCLAreaID = C.ValPTRCLAreaID
JOIN vvalptproductgroup PG
ON PG.ValPTProductGroupID = PGR.ValPTProductGroupID
JOIN vEmployee E
on E.EmployeeID = PGR.EmployeeID
Where  PGR.PayPeriod = (CASE WHEN SubString(CONVERT(VARCHAR,DATEADD(day,-1,CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)),112),7,2) < 16
       THEN Substring(CONVERT(VARCHAR,DATEADD(day,-1,CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)),112),1,6)+ '1' --- Payperiod 1
       ELSE Substring(CONVERT(VARCHAR,DATEADD(day,-1,CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)),112),1,6)+ '2' --- Payperiod 2
       END)
 AND ( SalesRevenueTotal + ServiceRevenueTotal <> 0 )
Order by R.Description,C.ClubName,PG.Description



-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
