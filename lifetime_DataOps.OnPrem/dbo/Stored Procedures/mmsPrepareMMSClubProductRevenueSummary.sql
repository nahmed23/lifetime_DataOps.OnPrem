




--THIS PROCEDURE INSERTED REVENUE DETAILS PRODUCTS SOLD AT EACH CLUB EACH DAY. 

CREATE    PROCEDURE dbo.mmsPrepareMMSClubProductRevenueSummary
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  DECLARE @PostDateTime DATETIME

  --PostDateTime IS SET BACK TO 3 DAYS JUST IN CASE IF A DRAWER WAS NOT CLOSED FOR A COUPLE OF DAYS.
  SET @PostDateTime  =  DATEADD(dd, -3, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))

  SELECT CONVERT(VARCHAR,PostDateTime,102) RevenueDate,
         CASE WHEN MT.clubID = 13 THEN M.ClubID ELSE MT.ClubID END ClubID,
         TI.ProductID,VTT.Description TranType,SUM(TI.ItemAmount) RevenueAmount,
         SUM(CASE WHEN TI.ItemAmount < 0 THEN (TI.Quantity * -1) ELSE TI.Quantity END) Quantity
  INTO #TmpRevenue
  FROM vMMSTran MT JOIN vTranItem TI ON MT.MMSTranID = TI.MMSTranID
                   JOIN vValTranType VTT ON MT.ValTranTypeID = VTT.ValTranTypeID
                   JOIN vMembership M ON M.MembershipID = MT.MembershipID
                   JOIN vDrawerActivity DA ON MT.DrawerActivityID = DA.DrawerActivityID
  WHERE MT.PostDateTime >= @PostDateTime AND MT.TranVoidedID IS NULL
        AND DA.ValDrawerStatusID = 3
  GROUP BY CONVERT(VARCHAR,PostDateTime,102),
           (CASE WHEN MT.clubID = 13 THEN M.ClubID ELSE MT.ClubID END),
           ProductID,VTT.Description
   
  UPDATE vMMSClubProductRevenueSummary
  SET RevenueAmount = TR.RevenueAmount,
      Quantity = TR.Quantity
  FROM vMMSClubProductRevenueSummary CPR JOIN #TmpRevenue TR ON TR.ClubID = CPR.ClubID
                                          AND TR.ProductID = CPR.ProductID 
                                          AND TR.RevenueDate = CPR.RevenueDate


  INSERT INTO vMMSClubProductRevenueSummary(RevenueDate,ClubID,ProductID,TranType,RevenueAmount,Quantity)
  SELECT TR.RevenueDate,TR.ClubID,TR.ProductID,TR.TranType,TR.RevenueAmount,TR.Quantity
  FROM #TmpRevenue TR LEFT JOIN vMMSClubProductRevenueSummary CPR ON TR.ClubID = CPR.ClubID
                            AND TR.ProductID = CPR.ProductID AND TR.RevenueDate = CPR.RevenueDate
  WHERE CPR.RevenueDate IS NULL


  --------
  -------
  
  DROP TABLE #TmpRevenue


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END












