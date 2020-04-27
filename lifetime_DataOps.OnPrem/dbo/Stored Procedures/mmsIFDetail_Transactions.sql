






---- Returns Initiation Fee Transaction data for 2 weeks prior to 1 week after a selected date range
---- The selected date range can not be prior to the 1st of the prior month, so this query is also limited to
---- 2 weeks prior to the 1st of the prior month 
---- This helps to ensure that all membership fee transactions are returned for the selected join date range.

CREATE      PROC dbo.mmsIFDetail_Transactions(
	@StartDate SMALLDATETIME,
	@EndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @FirstOfMonth DATETIME
DECLARE @FirstOfLastMonth DATETIME

SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,GETDATE(),112),1,6) + '01', 112)
SET @FirstOfLastMonth = DATEADD(mm, -1,@FirstOfMonth)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT C.ClubName AS TransactionClubName, MT.MembershipID, P.Description AS ProductDescription, 
TI.ItemAmount, MT.PostDateTime, VTT.Description AS TranTypeDescription 
FROM dbo.vClub C
 JOIN dbo.vMMSTran MT
   ON C.ClubID=MT.ClubID
 JOIN dbo.vMembership MS
   ON MT.MembershipID = MS.MembershipID
 JOIN dbo.vMember M
   ON MS.MembershipID = M.MembershipID
 JOIN dbo.vTranItem TI
   ON MT.MMSTranID=TI.MMSTranID
 JOIN dbo.vProduct P
   ON P.ProductID=TI.ProductID
 JOIN dbo.vValTranType VTT 
   ON MT.ValTranTypeID=VTT.ValTranTypeID
WHERE 
  P.ProductID = 88 AND  ----- Initiation Fee 
  MT.TranVoidedID IS NULL AND 
  M.ValMemberTypeID = 1 AND
  VTT.ValTranTypeID IN (1,3,4) AND ---- Charge, Sale and Adjustment
  M.JoinDate >= @StartDate AND 
  M.JoinDate <= @EndDate  AND  
  M.JoinDate >= @FirstOfLastMonth    
  
-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








