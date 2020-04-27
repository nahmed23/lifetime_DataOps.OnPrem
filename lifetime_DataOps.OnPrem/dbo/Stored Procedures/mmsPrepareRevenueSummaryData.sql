







CREATE  PROC [dbo].[mmsPrepareRevenueSummaryData]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- This procedure will prepare Revenue Summary data for Revenue reports
/******* Amounts returned are in LocalCurrencyCode ******/

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @SevenMonths DATETIME

  --Caluclate Yesterday's Date
  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  --Calculate the first of the month for Yesterday's date
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@Yesterday,112),1,6) + '01', 112)
  --Calculate the the date for seven months ago
  SET @SevenMonths = DATEADD(m,-7,Convert(DateTime,Convert(Varchar(11),GetDate())))


-- returns data on all unvoided automated refund transactions 
-- posted in the month
CREATE TABLE #RefundTranIDs (
       MMSTranRefundID INT,
       RefundMMSTranID INT,
       RefundReasonCodeID INT,
       MembershipClubID INT,
       MembershipClubName NVARCHAR(50),
       MembershipRegionID INT,
       MembershipGLClubID INT,
       MembershipGLTaxID INT,
       MembershipRegionDescription NVARCHAR(50),
       MembershipClubValCurrencyCodeID INT)

INSERT INTO #RefundTranIDs
SELECT MMSTR.MMSTranRefundID,
       MMST.MMSTranID,
       MMST.ReasonCodeID,
       MS.ClubID,
       C.ClubName,
       R.ValRegionID,
       C.GLClubID,
       C.GLTaxID,
       R.Description,
       C.ValCurrencyCodeID
  FROM vMMSTranRefund MMSTR
  JOIN vMMSTran MMST
    ON MMST.MMSTranID = MMSTR.MMSTranID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub C
    ON C.ClubID = MS.ClubID
  JOIN vValRegion R
    ON R.ValRegionID = C.ValRegionID
 WHERE MMST.TranVoidedID IS NULL
   AND MMST.PostDateTime >= @FirstOfMonth
   AND MMST.PostDateTime < GetDate()

-- This query returns original MMSTran transaction data and current membership -- club data for transactions gathered in #RefundTranIDs
-- to determine the club where transaction will be assigned
CREATE TABLE #ReportRefunds (
       RefundMMSTranID INT,
       PostingGLTaxID INT,
       PostingGLClubID INT,
       PostingRegionDescription NVARCHAR(50),
       PostingClubName NVARCHAR(50),
       PostingMMSClubID INT,
       PostingValCurrencyCodeID INT)

INSERT INTO #ReportRefunds
SELECT RTID.RefundMMSTranID,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLTaxID ELSE TranItemClub.GLTaxID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipGLTaxID
            ELSE TranClub.GLTaxID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLClubID ELSE TranItemClub.GLClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipGLClubID
            ELSE TranClub.GLClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranRegion.Description ELSE TranItemRegion.Description END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipRegionDescription
            ELSE TranRegion.Description
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubName ELSE TranItemClub.ClubName END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipClubName
            ELSE TranClub.ClubName
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipClubID
            ELSE TranClub.ClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ValCurrencyCodeID ELSE TranItemClub.ValCurrencyCodeID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipClubValCurrencyCodeID
            ELSE TranClub.ValCurrencyCodeID
       END
  FROM #RefundTranIDs  RTID
  JOIN vMMSTranRefundMMSTran  MMSTRT
    ON MMSTRT.MMSTranRefundID = RTID.MMSTranRefundID
  JOIN vMMSTran  MMST
    ON MMST.MMSTranID = MMSTRT.OriginalMMSTranID
  JOIN vClub TranClub
    ON TranClub.ClubID = MMST.ClubID
  JOIN vValRegion  TranRegion
    ON TranRegion.ValRegionID = TranClub.ValRegionID
  LEFT JOIN vTranItem TI   --1/31/2011 BSD
    ON MMST.MMSTranID = TI.MMSTranID   --1/31/2011 BSD
  LEFT JOIN vClub TranItemClub   --1/31/2011 BSD
    ON TI.ClubID = TranItemClub.ClubID   --1/31/2011 BSD
  LEFT JOIN vValRegion TranItemRegion   --1/31/2011 BSD
    ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID   --1/31/2011 BSD
  GROUP BY RTID.RefundMMSTranID,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLTaxID ELSE TranItemClub.GLTaxID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipGLTaxID
            ELSE TranClub.GLTaxID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLClubID ELSE TranItemClub.GLClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipGLClubID
            ELSE TranClub.GLClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranRegion.Description ELSE TranItemRegion.Description END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipRegionDescription
            ELSE TranRegion.Description
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubName ELSE TranItemClub.ClubName END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipClubName
            ELSE TranClub.ClubName
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipClubID
            ELSE TranClub.ClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ValCurrencyCodeID ELSE TranItemClub.ValCurrencyCodeID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 or TranClub.ClubID in(13)
                 THEN RTID.MembershipClubValCurrencyCodeID
            ELSE TranClub.ValCurrencyCodeID
       END


--- This query gathers discount data for all tranitem records in the month 
--- which have discount data
CREATE TABLE #TMPDiscount (
       TranItemID INT,
       ItemAmount MONEY,
       TotalDiscountAmount MONEY,
       ReceiptText1 VARCHAR(50),
       AppliedDiscountAmount1 MONEY,
       ReceiptText2 VARCHAR(50),
       AppliedDiscountAmount2 MONEY,
       ReceiptText3 VARCHAR(50),
       AppliedDiscountAmount3 MONEY,
       ReceiptText4 VARCHAR(50),
       AppliedDiscountAmount4 MONEY,
       ReceiptText5 VARCHAR(50),
       AppliedDiscountAmount5 MONEY)

DECLARE @TranItemID INT,
        @ItemAmount MONEY,
        @TotalDiscountAmount MONEY,
        @ReceiptText VARCHAR(50),
        @AppliedDiscountAmount MONEY,
        @HOLDTranItemID INT,
        @Counter INT

SET @HOLDTranItemID = -1
SET @Counter = 1


DECLARE Discount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT TI.TranItemID, TI.ItemAmount, TI.ItemDiscountAmount as TotalDiscountAmount,SP.ReceiptText,TID.AppliedDiscountAmount
  FROM vMMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vValTranType VTT
    ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN vTranItemDiscount TID
    ON TID.TranItemID = TI.TranItemID
  JOIN vPricingDiscount PD
    ON PD.PricingDiscountID = TID.PricingDiscountID
  JOIN vSalesPromotion SP
    ON PD.SalesPromotionID = SP.SalesPromotionID
 WHERE MMST.PostDateTime >= @FirstOfMonth
   AND MMST.PostDateTime <= GETDATE()
   AND MMST.TranVoidedID IS NULL
 ORDER BY TI.TranItemID, PD.SalesPromotionID

OPEN Discount_Cursor
FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
WHILE (@@FETCH_STATUS = 0)
    BEGIN

        IF @TranItemID != @HOLDTranItemID
            BEGIN
                INSERT INTO #TMPDiscount
                   (TranItemID, ItemAmount, TotalDiscountAmount, ReceiptText1, AppliedDiscountAmount1)
                VALUES (@TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount)
                SET @HOLDTranItemID = @TranItemID
                SET @Counter = 1
            END
        ELSE
            BEGIN
                SET @Counter = @Counter + 1
                IF @Counter = 2
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText2 = @ReceiptText, AppliedDiscountAmount2 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 3
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText3 = @ReceiptText, AppliedDiscountAmount3 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 4
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText4 = @ReceiptText, AppliedDiscountAmount4 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 5
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText5 = @ReceiptText, AppliedDiscountAmount5 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                SET @HOLDTranItemID = @TranItemID
            END

    FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
    END

CLOSE Discount_Cursor
DEALLOCATE Discount_Cursor 


  DELETE MMSRevenueReportSummary
  WHERE PostDateTime < @SevenMonths --get rid of seven month old data
     --The following 2 conditions prevent Prior month transactions of ProductID 5234,6759,11341 that have had their postdatetime deferred to August 1,2014, from deletion.  
     --See D6979
	 OR (PostDateTime >= @FirstOfMonth AND TranDate >= @FirstOfMonth)
     OR (PostDateTime >= @FirstOfMonth AND ProductID not in(5234,6759,11341))

--Re-populate summary table with month's data
 INSERT INTO MMSRevenueReportSummary(PostingClubName, 
             ItemAmount, DeptDescription, 
             ProductDescription,MembershipClubname,PostingClubid, 
             DrawerActivityID, PostDateTime, TranDate, 
             TranTypeDescription, ValTranTypeID, MemberID, 
             ItemSalesTax, EmployeeID, PostingRegionDescription, 
             MemberFirstname,MemberLastname,EmployeeFirstname, 
             EmployeeLastname,ReasonCodeDescription,TranItemID, 
             TranMemberJoinDate,MembershipID, ProductID, TranClubid, Quantity, DepartmentID,ItemDiscountAmount,
             DiscountAmount1, DiscountAmount2, DiscountAmount3, DiscountAmount4, DiscountAmount5,
             Discount1, Discount2, Discount3, Discount4, Discount5,LocalCurrencyCode)

SELECT CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubName ELSE TranItemClub.ClubName END ELSE C.ClubName END AS PostingClubName,
       TI.ItemAmount * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                           ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                            ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS ItemAmount, 
       D.Description DeptDescription, 
       P.Description ProductDescription, C2.ClubName MembershipClubname, 
       CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubID ELSE TranItemClub.ClubID END ELSE C.ClubID END AS PostingClubid,
       MMST.DrawerActivityID, 
       MMST.PostDateTime, --Active when 90 Day Challenge is NOT being deferred
       --CASE WHEN P.ProductID IN(5234,6759,11341) THEN 'Feb 1, 2015' ELSE MMST.PostDateTime END PostDateTime, --Active when 90 Day Challenge is being deferred
       MMST.TranDate, 
       VTT.Description TranTypeDescription, MMST.ValTranTypeID, MMST.MemberID, 
       TI.ItemSalesTax * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                             ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                              ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS ItemSalesTax, 
       MMST.EmployeeID,  
       CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN VR.Description ELSE TranItemRegion.Description END ELSE VR.Description END AS PostingRegionDescription,
       M.FirstName MemberFirstname, M.LastName MemberLastname, E.FirstName EmployeeFirstname, 
       E.LastName EmployeeLastname, RC.Description ReasonCodeDescription, TI.TranItemID, 
       M.JoinDate TranMemberJoinDate, MMST.MembershipID, P.ProductID, 
       CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubID ELSE TranItemClub.ClubID END ELSE C.ClubID END AS TranClubid,
       TI.Quantity, D.DepartmentID, 
       TI.ItemDiscountAmount * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                                   ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                                   ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS ItemDiscountAmount,
       #TMP.AppliedDiscountAmount1 * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                                         ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                                          ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS DiscountAmount1,
       #TMP.AppliedDiscountAmount2 * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                                         ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                                          ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS DiscountAmount2,
       #TMP.AppliedDiscountAmount3 * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                                         ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                                          ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS DiscountAmount3,
       #TMP.AppliedDiscountAmount4 * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                                         ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                                          ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS DiscountAmount4,
       #TMP.AppliedDiscountAmount5 * CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyPlanExchangeRate.PlanExchangeRate
                                                                         ELSE TranItemLocalCurrencyPlanExchangeRate.PlanExchangeRate END
                                          ELSE TranLocalCurrencyPlanExchangeRate.PlanExchangeRate END AS DiscountAmount5,
       #TMP.ReceiptText1 AS Discount1,
       #TMP.ReceiptText2 AS Discount2,
       #TMP.ReceiptText3 AS Discount3,
       #TMP.ReceiptText4 AS Discount4,
       #TMP.ReceiptText5 AS Discount5,
       CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranLocalCurrencyCode.CurrencyCode
                                           ELSE TranItemLocalCurrencyCode.CurrencyCode  END
            ELSE TranLocalCurrencyCode.CurrencyCode
       END as LocalCurrencyCode
    FROM dbo.vMMSTran MMST 
    JOIN dbo.vClub C
         ON C.ClubID = MMST.ClubID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vTranItem TI
         ON TI.MMSTranID = MMST.MMSTranID
    LEFT JOIN dbo.vClub TranItemClub
         ON TI.ClubID = TranItemClub.ClubID
    LEFT JOIN dbo.vValRegion TranItemRegion
         ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID
    JOIN dbo.vProduct P
         ON P.ProductID = TI.ProductID
    JOIN dbo.vDepartment D
         ON D.DepartmentID = P.DepartmentID
    JOIN dbo.vMembership MS
         ON MS.MembershipID = MMST.MembershipID
    JOIN dbo.vClub C2
         ON MS.ClubID = C2.ClubID
    JOIN dbo.vValTranType VTT
         ON MMST.ValTranTypeID = VTT.ValTranTypeID
    JOIN dbo.vMember M
         ON M.MemberID = MMST.MemberID
    JOIN dbo.vReasonCode RC
         ON RC.ReasonCodeID = MMST.ReasonCodeID
    LEFT OUTER JOIN dbo.vEmployee E 
         ON MMST.EmployeeID = E.EmployeeID
    LEFT JOIN #TMPDiscount #TMP
         ON TI.TranItemID = #TMP.TranItemID
    LEFT JOIN vMMSTranRefund MTR
         ON MMST.MMSTranID = MTR.MMSTranID
/**** Foreign Currency ******/
    JOIN vValCurrencyCode OriginalCurrencyCode
         ON ISNULL(MMST.ValCurrencyCodeID,1) = OriginalCurrencyCode.ValCurrencyCodeID
    JOIN vValCurrencyCode TranLocalCurrencyCode
         ON C.ValCurrencyCodeID = TranLocalCurrencyCode.ValCurrencyCodeID
    LEFT JOIN vValCurrencyCode TranItemLocalCurrencyCode
         ON TranItemClub.ValCurrencyCodeID = TranItemLocalCurrencyCode.ValCurrencyCodeID
    JOIN vPlanExchangeRate TranLocalCurrencyPlanExchangeRate
         ON OriginalCurrencyCode.CurrencyCode = TranLocalCurrencyPlanExchangeRate.FromCurrencyCode
        AND TranLocalCurrencyCode.CurrencyCode = TranLocalCurrencyPlanExchangeRate.ToCurrencyCode
        AND YEAR(MMST.PostDateTime) = TranLocalCurrencyPlanExchangeRate.PlanYear
    LEFT JOIN vPlanExchangeRate TranItemLocalCurrencyPlanExchangeRate
         ON OriginalCurrencyCode.CurrencyCode = TranItemLocalCurrencyPlanExchangeRate.FromCurrencyCode
        AND TranItemLocalCurrencyCode.CurrencyCode = TranItemLocalCurrencyPlanExchangeRate.ToCurrencyCode
        AND YEAR(MMST.PostDateTime) = TranItemLocalCurrencyPlanExchangeRate.PlanYear
   WHERE MMST.PostDateTime >= @FirstOfMonth 
         AND MMST.PostDateTime < GETDATE() 
         AND MMST.TranVoidedID IS NULL 
         AND VTT.ValTranTypeID IN (1, 3, 4, 5) 
         AND C.ClubID not in(13)
         AND MTR.MMSTranRefundID IS NULL

  UNION ALL

  SELECT C2.ClubName as PostingClubName,    
         TI.ItemAmount * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate as ItemAmount, 
         D.Description DeptDescription, 
         P.Description ProductDescription, C2.ClubName MembershipClubname, 
         C2.ClubID as PostingClubID,	
         MMST.DrawerActivityID, 
         MMST.PostDateTime,  --Active when 90 Day Challenge is NOT being deferred
         --CASE WHEN P.ProductID IN(5234,6759,11341) THEN 'Feb 1, 2015' ELSE MMST.PostDateTime END PostDateTime, --Active when 90 Day Challenge is being deferred
         MMST.TranDate, VTT.Description TranTypeDescription, 
         MMST.ValTranTypeID, M.MemberID, 
         TI.ItemSalesTax  * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate as ItemSalesTax, 
         MMST.EmployeeID,
         C2VR.Description as PostingRegionDescription,   
         M.FirstName MemberFirstname, M.LastName MemberLastname, 
         E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, RC.Description ReasonCodeDescription, 
         TI.TranItemID, M.JoinDate TranMemberJoinDate, MMST.MembershipID, 
         P.ProductID, MMST.ClubID TranClubid,TI.Quantity, D.DepartmentID, 
         TI.ItemDiscountAmount * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS ItemDiscountAmount,
         #TMP.AppliedDiscountAmount1 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS DiscountAmount1,
         #TMP.AppliedDiscountAmount2 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS DiscountAmount2,
         #TMP.AppliedDiscountAmount3 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS DiscountAmount3,
         #TMP.AppliedDiscountAmount4 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS DiscountAmount4,
         #TMP.AppliedDiscountAmount5 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS DiscountAmount5,
         #TMP.ReceiptText1 AS Discount1,
         #TMP.ReceiptText2 AS Discount2,
         #TMP.ReceiptText3 AS Discount3,
         #TMP.ReceiptText4 AS Discount4,
         #TMP.ReceiptText5 AS Discount5,
         TranLocalCurrencyCode.CurrencyCode as LocalCurrencyCode
    FROM dbo.vMMSTran MMST
    JOIN dbo.vClub C
         ON C.ClubID = MMST.ClubID
    JOIN dbo.vTranItem TI
         ON TI.MMSTranID = MMST.MMSTranID
    JOIN dbo.vProduct P
         ON P.ProductID = TI.ProductID
    JOIN dbo.vDepartment D
         ON D.DepartmentID = P.DepartmentID
    JOIN dbo.vMembership MS
         ON MS.MembershipID = MMST.MembershipID
    JOIN dbo.vClub C2
         ON MS.ClubID = C2.ClubID
    JOIN dbo.vValRegion C2VR
         ON C2.ValRegionID = C2VR.ValRegionID
    JOIN dbo.vValTranType VTT
         ON MMST.ValTranTypeID = VTT.ValTranTypeID
    JOIN dbo.vMember M
         ON M.MemberID = MMST.MemberID
    JOIN dbo.vReasonCode RC
         ON RC.ReasonCodeID = MMST.ReasonCodeID
    LEFT JOIN dbo.vMMSTranRefund MTR                                    
         ON MMST.MMSTranID = MTR.MMSTranID
    LEFT OUTER JOIN dbo.vEmployee E 
         ON MMST.EmployeeID = E.EmployeeID
    LEFT JOIN #TMPDiscount #TMP
      ON TI.TranItemID = #TMP.TranItemID
/**** Foreign Currency ******/
    JOIN vValCurrencyCode OriginalCurrencyCode
         ON ISNULL(MMST.ValCurrencyCodeID,1) = OriginalCurrencyCode.ValCurrencyCodeID
    JOIN vValCurrencyCode TranLocalCurrencyCode
         ON C2.ValCurrencyCodeID = TranLocalCurrencyCode.ValCurrencyCodeID
    JOIN vPlanExchangeRate TranLocalCurrencyPlanExchangeRate
         ON OriginalCurrencyCode.CurrencyCode = TranLocalCurrencyPlanExchangeRate.FromCurrencyCode
        AND TranLocalCurrencyCode.CurrencyCode = TranLocalCurrencyPlanExchangeRate.ToCurrencyCode
        AND YEAR(MMST.PostDateTime) = TranLocalCurrencyPlanExchangeRate.PlanYear
   WHERE C.ClubID in(13)
     AND MMST.PostDateTime >= @FirstOfMonth 
     AND MMST.PostDateTime < GETDATE() 
     AND VTT.ValTranTypeID IN (1, 3, 4, 5) 
     AND MMST.TranVoidedID IS NULL
     AND MTR.MMSTranRefundID IS NULL

  UNION ALL

SELECT #RR.PostingClubName,
       TI.ItemAmount * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS ItemAmount,
       D.Description as DeptDescription,
       P.Description as ProductDescription,
       C2.ClubName as MembershipClubname,
       #RR.PostingMMSClubID as PostingClubID,
       MMST.DrawerActivityID,
       MMST.PostDateTime, --Active when 90 Day Challenge is NOT being deferred
       --CASE WHEN P.ProductID in(5234,6759,11341) THEN 'Feb 1, 2015' ELSE MMST.PostDateTime END PostDateTime, --Active when 90 Day Challenge is being deferred
       MMST.TranDate,
       VTT.Description as TranTypeDescription,
       MMST.ValTranTypeID,
       MMST.MemberID,
       TI.ItemSalesTax * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS ItemSalesTax,
       MMST.EmployeeID,
       #RR.PostingRegionDescription as PostingRegionDescription,
       M.FirstName as MemberFirstname,
       M.LastName as MemberLastname,
       E.FirstName as EmployeeFirstname,
       E.LastName as EmployeeLastname,
       RC.Description as ReasonCodeDescription,
       TI.TranItemID,
       M.JoinDate as TranMemberJoinDate,
       MMST.MembershipID,
       P.ProductID,
       MMST.ClubID as TranClubid,
       TI.Quantity,
       D.DepartmentID,
       TI.ItemDiscountAmount * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate AS ItemDiscountAmount,
       #TMP.AppliedDiscountAmount1 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate as DiscountAmount1,
       #TMP.AppliedDiscountAmount2 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate as DiscountAmount2,
       #TMP.AppliedDiscountAmount3 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate as DiscountAmount3,
       #TMP.AppliedDiscountAmount4 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate as DiscountAmount4,
       #TMP.AppliedDiscountAmount5 * TranLocalCurrencyPlanExchangeRate.PlanExchangeRate as DiscountAmount5,
       #TMP.ReceiptText1 as Discount1,
       #TMP.ReceiptText2 as Discount2,
       #TMP.ReceiptText3 as Discount3,
       #TMP.ReceiptText4 as Discount4,
       #TMP.ReceiptText5 as Discount5,
       TranLocalCurrencyCode.CurrencyCode as LocalCurrencyCode
  FROM vMMSTran MMST
  JOIN #ReportRefunds #RR
    ON #RR.RefundMMSTranID = MMST.MMSTranID
  JOIN vTranItem  TI
    ON TI.MMSTranID = MMST.MMSTranID
  JOIN vProduct P
    ON P.ProductID = TI.ProductID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub  C2
    ON MS.ClubID = C2.ClubID
  JOIN vValTranType VTT
    ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN vMember M
    ON M.MemberID = MMST.MemberID
  JOIN vReasonCode  RC
    ON RC.reasonCodeID = MMST.ReasonCodeID
  LEFT JOIN vEmployee E
    ON MMST.EmployeeID = E.EmployeeID       
  LEFT JOIN #TMPDiscount #TMP
    ON TI.TranItemID = #TMP.TranItemID
/**** Foreign Currency ******/
    JOIN vValCurrencyCode OriginalCurrencyCode
         ON ISNULL(MMST.ValCurrencyCodeID,1) = OriginalCurrencyCode.ValCurrencyCodeID
    JOIN vValCurrencyCode TranLocalCurrencyCode
         ON #RR.PostingValCurrencyCodeID = TranLocalCurrencyCode.ValCurrencyCodeID
    JOIN vPlanExchangeRate TranLocalCurrencyPlanExchangeRate
         ON OriginalCurrencyCode.CurrencyCode = TranLocalCurrencyPlanExchangeRate.FromCurrencyCode
        AND TranLocalCurrencyCode.CurrencyCode = TranLocalCurrencyPlanExchangeRate.ToCurrencyCode
        AND YEAR(MMST.PostDateTime) = TranLocalCurrencyPlanExchangeRate.PlanYear
  
DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
DROP TABLE #TMPDiscount

END













