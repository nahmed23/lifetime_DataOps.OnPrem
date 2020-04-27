﻿



CREATE    PROC [dbo].[mmsRevenueglposting_Revenue_ByRegion](
             @RegionIDList VARCHAR(1000))
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types includes Adjustment, Charge, and Refund.
--             Takes a "|" separated list of RegionIDs 
----           also, the transactions are only coming from closed drawers.
-- 04/12/2010 ML Added 10 new output columns, populating and updating temporary table #RevenueGLPosting prior to select
-- 05/12/2010 ML Modified Reconciliation_Psoting_Sub_Account for Automated Refunds
-- 07/07/2010 ML Incorporate Discounts - RR 422
-- 01/18/2011 BSD: Updated for new ClubID = 9999 business rule to use TranItem.ClubID
-- 05/25/2011 BSD: Reorganized much of the stored procedure due to a massive performance hit from E-Commerce support and Foreign Currency
--                 QC# 7109
-- 10/27/2011 EDW 11-2011: Add new column MembershipActivationDate
-- 12/28/2011 BSD: added LFF Acquisition logic

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList(StringField INT)
EXEC procParseIntegerList @RegionIDList

	DECLARE @PostDateStart DATETIME
	DECLARE @PostDateEND DATETIME
	DECLARE @FirstOfMonth DATETIME

	
	SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,GETDATE()),112),1,6) + '01', 112)
	SET @PostDateStart  =  dateadd(mm,-1,@firstofmonth)
	SET @PostDateEnd  =  dateadd(ss,-1,@firstofmonth)
	
--LFF Acquisition changes begin
SELECT ms.MembershipID,
	CASE WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 160 THEN 220 --Cary
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 159 THEN 219 --Dublin
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 40 THEN 218  --Easton
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 30 THEN 214  --Indianapolis
		 ELSE ms.ClubID END ClubID,
	ms.ActivationDate
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = ms.MembershipTypeID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition
 
 CREATE INDEX IX_MembershipID ON #Membership(MembershipID)
 CREATE INDEX IX_ClubID ON #Membership(ClubID)


SELECT distinct mt.MMSTranID, 
		CASE WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 160 THEN 220 --Cary
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 159 THEN 219 --Dublin
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 40  THEN 218 --Easton
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 30  THEN 214 --Indianapolis
			 ELSE mt.ClubID END ClubID,
	   mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.ComputerName, mt.IPAddress,
	   mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID
INTO #MMSTranNonArchive
FROM vMMSTranNonArchive mt WITH (NOLOCK)
JOIN #Membership ms
  ON ms.MembershipID = mt.MembershipID
LEFT JOIN vTranItem ti WITH (NOLOCK)
  ON ti.MMSTranID = mt.MMSTranID
 AND mt.ValTranTypeID IN (1,4)
 AND mt.ClubID IN (30,40,159,160)
 AND (ti.ProductID IN (1497,3100)
		OR ti.ProductID IN (SELECT mta.MembershipTypeID 
							FROM vMembershipTypeAttribute mta WITH (NOLOCK)
							WHERE mta.ValMembershipTypeAttributeID = 28) --Acquisition
	 )
WHERE DATEDIFF(month,mt.PostDateTime,GETDATE()) = 1
  AND mt.TranVoidedID is null
  
  CREATE INDEX IX_ClubID ON #MMSTranNonArchive(ClubID)
--LFF Acquisition changes end

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C  
  JOIN #tmpList ON C.ValRegionID = #tmpList.StringField
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #MonthlyPlanRate (MonthlyAverageExchangeRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), FirstOfMonthDate datetime, EndOfMonthDate datetime)
INSERT INTO #MonthlyPlanRate
SELECT MonthlyAverageExchangeRate, FromCurrencyCode, FirstOfMonthDate, EndOfMonthDate
FROM MonthlyAverageExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode
  AND FirstOfMonthDate = @PostDateStart

CREATE TABLE #ToUSDMonthlyPlanRate (MonthlyAverageExchangeRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), FirstOfMonthDate datetime, EndOfMonthDate datetime)
INSERT INTO #ToUSDMonthlyPlanRate
SELECT MonthlyAverageExchangeRate, FromCurrencyCode, FirstOfMonthDate, EndOfMonthDate
FROM MonthlyAverageExchangeRate
WHERE ToCurrencyCode = 'USD'
  AND FirstOfMonthDate = @PostDateStart
/***************************************/

-- returns data on all unvoided automated refund transactions from closed drawers, 
-- posted in the prior month 
SELECT MMSTR.MMSTranRefundID,
	   MMST.MMSTranID as RefundMMSTranID,
	   MMST.ReasonCodeID as RefundReasonCodeID ,
	   MS.ClubID as MembershipClubID
INTO #RefundTranIDs
FROM vMMSTranRefund MMSTR
JOIN #MMSTranNonArchive MMST ON MMST.MMSTranID = MMSTR.MMSTranID
JOIN #Membership MS ON MS.MembershipID = MMST.MembershipID
JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
WHERE MMST.TranVoidedID is null -- exclude voided transactions
  AND DA.ValDrawerStatusID = 3 -- closed drawers only
  AND MMST.PostDateTime >= @PostDateStart 
  AND MMST.PostDateTime <= @PostDateEnd


--More LFF Acquisition - with some performance improvements
SELECT distinct mt.MMSTranID, 
		CASE WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 160 THEN 220 --Cary
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 159 THEN 219 --Dublin
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 40  THEN 218 --Easton
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 30  THEN 214 --Indianapolis
			 ELSE mt.ClubID END ClubID,
       RTID.MembershipClubID,
       RTID.RefundMMSTranID,
       RTID.RefundReasonCodeID
INTO #MMSTran
FROM vMMSTran mt WITH (NOLOCK)
JOIN #Membership ms
  ON ms.MembershipID = mt.MembershipID
LEFT JOIN vTranItem ti WITH (NOLOCK)
  ON ti.MMSTranID = mt.MMSTranID
 AND mt.ValTranTypeID IN (1,4)
 AND mt.ClubID IN (30,40,159,160)
 AND (ti.ProductID IN (1497,3100)
		OR ti.ProductID IN (SELECT mta.MembershipTypeID 
							FROM vMembershipTypeAttribute mta WITH (NOLOCK)
							WHERE mta.ValMembershipTypeAttributeID = 28) --Acquisition
	 )
JOIN vMMSTranRefundMMSTran MMSTRT 
  ON MMSTRT.OriginalMMSTranID = mt.MMSTranID
JOIN #RefundTranIDs RTID
  ON MMSTRT.MMSTranRefundID = RTID.MMSTranRefundID
JOIN #MMSTranNonArchive MMSTNA 
  ON RTID.RefundMMSTranID = MMSTNA.MMSTranID
WHERE mt.TranVoidedID is null
  AND DATEDIFF(month,MMSTNA.PostDateTime,GETDATE()) = 1
  AND MMSTNA.TranVoidedID IS NULL
--End More LFF Acquisition


-- This query returns original MMSTran transaction data and current membership club data gathered in #RefundTranIDs
-- to determine the club where transaction will be assigned
SELECT #MMSTran.RefundMMSTranID,
	   CASE WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
            WHEN #MMSTran.RefundReasonCodeID = 108 or TranClub.ClubID in(13)THEN #MMSTran.MembershipClubID ELSE TranClub.ClubID 
       END AS PostingMMSClubID -- 1/18/2011 BSD
INTO #ReportRefunds
FROM #MMSTran
JOIN vClub MembershipClub ON #MMSTran.MembershipClubID = MembershipClub.ClubID
JOIN vClub TranClub ON #MMSTran.ClubID = TranClub.ClubID
LEFT JOIN vTranItem TI ON #MMSTran.MMSTranID = TI.MMSTranID
LEFT JOIN vClub TranItemClub ON TI.ClubID = TranItemClub.ClubID
WHERE CASE WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ValRegionID ELSE TranItemClub.ValRegionID END   --1/31/2011 BSD
           WHEN #MMSTran.RefundReasonCodeID = 108 or TranClub.ClubID in(13) THEN MembershipClub.ValRegionID 
           ELSE TranClub.ValRegionID 
      END IN (SELECT StringField FROM #tmpList)
GROUP BY #MMSTran.RefundMMSTranID,
	     CASE WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
              WHEN #MMSTran.RefundReasonCodeID = 108 or TranClub.ClubID in(13)THEN #MMSTran.MembershipClubID ELSE TranClub.ClubID 
         END -- 1/18/2011 BSD


--************************************************************************************

CREATE TABLE #RevenueGLPosting(
       ItemAmount MONEY,
       DeptDescription VARCHAR(50),
       ProductDescription VARCHAR(50),
       MembershipClubName VARCHAR(50),
       DrawerActivityID INT,
       PostDateTime DATETIME,
       TranDate DATETIME,
       ValTranTypeID INT,
       MemberID INT,
       ItemSalesTax MONEY,
       EmployeeID INT,
       MemberFirstName VARCHAR(50),
       MemberLastName VARCHAR(50),
       TranItemId INT,
       TranMemberJoinDate DATETIME,
       MembershipID INT,
       ValGLGroupID INT,
       GLAccountNumber VARCHAR(10),
       GLSubAccountNumber VARCHAR(10),
       GLOverRideClubID INT,
       ProductID INT,
       GLGroupIDDescription VARCHAR(50),
       Posting_MMSClubID INT,
       EmployeeFirstName VARCHAR(50),
       EmployeeLastName VARCHAR(50),
       TransactionDescrption VARCHAR(50),
       TranTypeDescription VARCHAR(50),
       Reconcilation_Sales MONEY,
       Reconciliation_Adjustment MONEY,
       Reconciliation_Refund MONEY,
       Reconciliation_DuesAssessCharge MONEY,
       Reconciliation_AllOtherCharges MONEY,
       Reconciliation_ReportMonthYear VARCHAR(20),
       Reconciliation_Posting_Sub_Account VARCHAR(20),
       Reconciliation_ReportHeader_TranType VARCHAR(50),
       Reconciliation_ReportLineGrouping VARCHAR(200),
       Reconciliation_Adj_GLAccountNumber VARCHAR(10),
       SortValGroupID INT,
       Adj_ValGroupID_Desc VARCHAR(200),
       ItemDiscountAmount Money,             ---------------------- new with RR 422
       DiscountGLAccount VARCHAR(5),         ---------------------- new with RR 422
       MembershipActivationDate DATETIME)        -- EDW 11-2011 QC#8037 


INSERT INTO #RevenueGLPosting

SELECT TI.ItemAmount, D.Description DeptDescription, RTRIM(P.Description) ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       TI.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, TI.TranItemID, M.JoinDate TranMemberJoinDate, 
       MMST.MembershipID, P.ValGLGroupID, P.GLAccountNumber, 
       P.GLSubAccountNumber, P.GLOverRideClubID, P.ProductID, 
       VGLG.Description GLGroupIDDescription, 
       C1.ClubID Posting_MMSClubID,
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription,
--New Columns 4/12/2010 ML
       CASE MMST.Valtrantypeid WHEN 3 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE P.GLOverRideClubID
            WHEN 0
                 THEN CAST(C1.GLClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
                 ELSE CAST(P.GLOverRideClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_ReportLineGrouping,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE
            WHEN P.ProductID = 1497 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
            WHEN P.ValGLGroupID = 12
                 THEN 998
            WHEN P.ValGLGroupID = 13
                 THEN 999
            WHEN P.ValGLGroupID = 1 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
                 ELSE P.ValGLGroupID
       END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       TI.ItemDiscountAmount,     ---------------------- new with RR 422
       GLA.DiscountGLAccount,      ---------------------- new with RR 422
       MS.ActivationDate MembershipActivationDate  -- EDW 11-2011 QC#8037
  FROM dbo.#MMSTranNonArchive MMST
  LEFT JOIN vMMSTranRefund MMSTR 
	   ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  JOIN dbo.vDepartment D
       ON D.DepartmentID = P.DepartmentID
  JOIN dbo.#Membership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vGLAccount GLA                           ---------------------- new with RR 422
       ON  P.GLAccountNumber = GLA.RevenueGLAccountNumber  ---------------------- new with RR 422
 WHERE VR.ValRegionID IN (SELECT StringField FROM #tmpList)AND
       DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 1 AND
       VTT.ValTranTypeID IN (1,3,4,5) AND  
       MMST.TranVoidedID IS NULL AND 
       DA.ValDrawerStatusID = 3 AND
       C1.ClubID not in(13,9999) AND -- 1/18/2011 BSD
	   MMSTR.MMSTranRefundID is NULL -- no automated refunds are returned
      
UNION

SELECT TI.ItemAmount, D.Description DeptDescription, RTRIM(P.Description) ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       TI.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, TI.TranItemID, M.JoinDate TranMemberJoinDate, 
       MMST.MembershipID, P.ValGLGroupID, P.GLAccountNumber, 
       P.GLSubAccountNumber, P.GLOverRideClubID, P.ProductID, 
       VGLG.Description GLGroupIDDescription,
       CASE WHEN TranItemClub.ClubID IS NULL THEN C1.ClubID
            ELSE TranItemClub.ClubID 
       END AS Posting_MMSClubID,
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription,
--New Columns 4/12/2010 ML
       CASE MMST.Valtrantypeid WHEN 3 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE P.GLOverRideClubID
            WHEN 0
                 THEN CAST(CASE WHEN TranItemClub.ClubID IS NULL THEN C1.GLClubID
                                ELSE TranItemClub.GLClubID 
                           END AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
                 ELSE CAST(P.GLOverRideClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_ReportLineGrouping,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE
            WHEN P.ProductID = 1497 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
            WHEN P.ValGLGroupID = 12
                 THEN 998
            WHEN P.ValGLGroupID = 13
                 THEN 999
            WHEN P.ValGLGroupID = 1 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
                 ELSE P.ValGLGroupID
       END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       TI.ItemDiscountAmount,     ---------------------- new with RR 422
       GLA.DiscountGLAccount,      ---------------------- new with RR 422
       MS.ActivationDate MembershipActivationDate  -- EDW 11-2011 QC#8037
  FROM dbo.#MMSTranNonArchive MMST
  LEFT JOIN vMMSTranRefund MMSTR 
	   ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  LEFT JOIN dbo.vClub TranItemClub --1/18/2011 BSD
       ON TI.ClubID = TranItemClub.ClubID --1/18/2011 BSD
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  JOIN dbo.vDepartment D
       ON D.DepartmentID = P.DepartmentID
  JOIN dbo.#Membership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vGLAccount GLA                           ---------------------- new with RR 422
       ON  P.GLAccountNumber = GLA.RevenueGLAccountNumber  ---------------------- new with RR 422
 WHERE CASE WHEN TranItemClub.ClubID IS NULL THEN C1.ValRegionID
            ELSE TranItemClub.ValRegionID 
       END IN (SELECT StringField FROM #tmpList)AND
       DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 1 AND
       VTT.ValTranTypeID IN (1,3,4,5) AND  
       MMST.TranVoidedID IS NULL AND 
       DA.ValDrawerStatusID = 3 AND
       C1.ClubID = 9999 AND -- 1/18/2011 BSD
	   MMSTR.MMSTranRefundID is NULL -- no automated refunds are returned

UNION

SELECT TI.ItemAmount, D.Description DeptDescription, RTRIM(P.Description) ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       TI.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, TI.TranItemID, M.JoinDate TranMemberJoinDate, 
       MMST.MembershipID, P.ValGLGroupID, P.GLAccountNumber, 
       P.GLSubAccountNumber, P.GLOverRideClubID, P.ProductID, 
       VGLG.Description GLGroupIDDescription,
       C2.ClubID Posting_MMSClubid, 
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       RC.Description TransactionDescription, VTT.Description TranTypeDescription,
       CASE MMST.Valtrantypeid WHEN 3 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE P.GLOverRideClubID
            WHEN 0
                 THEN CAST(C2.GLClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
                 ELSE CAST(P.GLOverRideClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,

       '' AS Reconciliation_ReportLineGrouping,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE
            WHEN P.ProductID = 1497 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
            WHEN P.ValGLGroupID = 12
                 THEN 998
            WHEN P.ValGLGroupID = 13
                 THEN 999
            WHEN P.ValGLGroupID = 1 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
                 ELSE P.ValGLGroupID
       END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       TI.ItemDiscountAmount,      ---------------------- new with RR 422
       GLA.DiscountGLAccount,       ---------------------- new with RR 422
       MS.ActivationDate MembershipActivationDate  -- EDW 11-2011 QC#8037
  FROM dbo.#MMSTranNonArchive MMST
  LEFT JOIN vMMSTranRefund MMSTR 
	   ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  JOIN dbo.vDepartment D
       ON D.DepartmentID = P.DepartmentID
  JOIN dbo.#Membership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR
       ON C2.ValRegionID = VR.ValRegionID
  JOIN dbo.vValCurrencyCode VCC
       ON C2.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode RC
       ON RC.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vGLAccount GLA                            ---------------------- new with RR 422
       ON P.GLAccountNumber = GLA.REvenueGLAccountNumber   ---------------------- new with RR 422
 WHERE C1.ClubID = 13 AND  -- 1/18/2011 BSD
       VR.ValRegionID IN (SELECT StringField FROM #tmpList)AND
       VTT.ValTranTypeID IN (1,3,4,5) AND 
       MMST.TranVoidedID IS NULL AND 
       DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 1 AND 
       DA.ValDrawerStatusID = 3 AND
	   MMSTR.MMSTranRefundID is NULL  -- no automated refunds are returned

UNION  

-- Automated Refunds 
SELECT TI.ItemAmount, D.Description DeptDescription, RTRIM(P.Description) ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       TI.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, TI.TranItemID, M.JoinDate TranMemberJoinDate, 
       MMST.MembershipID, P.ValGLGroupID, GLA.RefundGLAccountNumber AS GLAccountNumber, 
       P.GLSubAccountNumber, P.GLOverRideClubID, P.ProductID, 
       VGLG.Description GLGroupIDDescription, 
	   #RR.PostingMMSClubID AS Posting_MMSClubid, 
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, --VTT.Description TranTypeDescription 
	   'Automated Refund' AS TranTypeDescription,
       CASE MMST.Valtrantypeid WHEN 3 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN TI.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE P.GLOverRideClubID
            WHEN 0
                 THEN CAST(MembershipClub.GLClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber -- 5/12/2010 MLL Modified
                 ELSE CAST(P.GLOverRideClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       'Refund' AS Reconciliation_ReportHeader_TranType,


       '' AS Reconciliation_ReportLineGrouping,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE
            WHEN P.ProductID = 1497 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
            WHEN P.ValGLGroupID = 12
                 THEN 998
            WHEN P.ValGLGroupID = 13
                 THEN 999
            WHEN P.ValGLGroupID = 1 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN TI.Itemamount ELSE 0 END = 0
                 THEN 2
                 ELSE P.ValGLGroupID
       END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       TI.ItemDiscountAmount,            ---------------------- new with RR 422
       GLA.DiscountGLAccount,             ---------------------- new with RR 422
       MS.ActivationDate MembershipActivationDate  -- EDW 11-2011 QC#8037
  FROM dbo.#MMSTranNonArchive MMST
  JOIN  #ReportRefunds #RR
	   ON #RR.RefundMMSTranID = MMST.MMSTranID
  JOIN dbo.vClub MembershipClub
       ON #RR.PostingMMSClubID = MembershipClub.ClubID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  LEFT JOIN vGLAccount GLA                                   ---------------------- join change with RR 422
	   ON P.GLAccountNumber = GLA.RevenueGLAccountNumber     ---------------------- join change with RR 422
  JOIN dbo.vDepartment D
       ON D.DepartmentID = P.DepartmentID
  JOIN dbo.#Membership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
 WHERE DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 1 AND 
       VTT.Description IN ('Adjustment', 'Charge', 'Refund', 'Sale') AND 
       MMST.TranVoidedID IS NULL AND 
       DA.ValDrawerStatusID = 3 

UPDATE #RevenueGLPosting
   SET Adj_ValGroupID_Desc = 
  CASE 
       WHEN SortValGroupID = 2 AND TranTypeDescription = 'Automated Refund'
            THEN 'Membership Dues - Refund'
       WHEN SortValGroupID = 2 AND TranTypeDescription = 'Adjustment'
            THEN 'Current Month Dues - Adjustment'
       WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge')
            THEN 'Current Month Dues'
       WHEN SortValGroupID IN (998, 999) AND TranTypeDescription = 'Automated Refund'
            THEN ProductDescription + ' - Refund'
       WHEN ProductID IN (3504,4280) AND TranTypeDescription = 'Adjustment'
            THEN ProductDescription + ' - Adjustment'
       WHEN SortValGroupID IN (998, 999) 
            THEN ProductDescription
       WHEN TranTypeDescription = 'Automated Refund'
            THEN GLGroupIDDescription + ' - Refund'
            ELSE GLGroupIDDescription
       END

UPDATE #RevenueGLPosting
   SET Reconciliation_Adj_GLAccountNumber = 
  CASE 
       WHEN Adj_ValGroupID_Desc = 'Current Month Dues - Adjustment'
            THEN '4008'
       WHEN Adj_ValGroupID_Desc = 'Current Month Dues'
            THEN '4003'
       WHEN ProductID IN (3504, 4280) AND TranTypeDescription = 'Adjustment'
            THEN '4008'
       ELSE GLAccountNumber
   END

UPDATE #RevenueGLPosting
   SET Reconciliation_ReportLineGrouping = 
       Adj_ValGroupID_Desc + Reconciliation_Adj_GLAccountNumber + GLSubAccountNumber


SELECT ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate as ItemAmount,
	   ItemAmount as LocalCurrency_ItemAmount,
	   ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_ItemAmount,
       ISNULL((ItemDiscountAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate),0) AS ItemDiscountAmount,                         ---------------------- new with RR 422
	   ISNULL(ItemDiscountAmount,0) AS LocalCurrency_ItemDiscountAmount, 
	   ISNULL((ItemDiscountAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate),0) AS USD_ItemDiscountAmount, 		
       (ISNULL((ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate) ,0) + ISNULL((ItemDiscountAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate),0)) as GLPostingAmount,    ---------------------- new with RR 422
	   (ISNULL(ItemAmount,0) + ISNULL(ItemDiscountAmount,0)) as LocalCurrency_GLPostingAmount, 
	   (ISNULL((ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate),0) + ISNULL((ItemDiscountAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate),0)) as USD_GLPostingAmount,   
       DeptDescription,
       ProductDescription,
       MembershipClubName,
       DrawerActivityID,
       PostDateTime as PostDateTime_Sort,
	   Replace(Substring(convert(varchar,PostDateTime,100),1,6)+', '+Substring(convert(varchar,PostDateTime,100),8,10)+' '+Substring(convert(varchar,PostDateTime,100),18,2),'  ',' ') as PostDateTime,
       TranDate,
       ValTranTypeID,
       MemberID,
       ItemSalesTax * #MonthlyPlanRate.MonthlyAverageExchangeRate ItemSalesTax,
       ItemSalesTax LocalCurrency_ItemSalesTax,
       ItemSalesTax * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate USD_ItemSalesTax,
       EmployeeID,
       MemberFirstName,
       MemberLastName,
       TranItemId,
       TranMemberJoinDate,
       MembershipID,
       ValGLGroupID,
       GLAccountNumber,
       GLSubAccountNumber,
       GLOverRideClubID,
       ProductID,
       GLGroupIDDescription,
       C.GLTaxID,
       C.GLClubID Posting_GLClubID,
       VR.Description Posting_RegionDescription,
       C.ClubName Posting_ClubName,
       Posting_MMSClubID,
       EmployeeFirstName,
       EmployeeLastName,
       TransactionDescrption,
       TranTypeDescription,
       Adj_ValGroupID_Desc as Reconciliation_Adj_ValGroupID_Desc,  ---------------------- new with RR 422
       Reconcilation_Sales * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconcilation_Sales,
	   Reconcilation_Sales as LocalCurrency_Reconcilation_Sales,
	   Reconcilation_Sales * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconcilation_Sales,
       Reconciliation_Adjustment * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_Adjustment,
	   Reconciliation_Adjustment as LocalCurrency_Reconciliation_Adjustment,
	   Reconciliation_Adjustment * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_Adjustment,
       Reconciliation_Refund * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_Refund,
	   Reconciliation_Refund as LocalCurrency_Reconciliation_Refund,
	   Reconciliation_Refund * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_Refund,
       Reconciliation_DuesAssessCharge * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_DuesAssessCharge,
	   Reconciliation_DuesAssessCharge as LocalCurrency_Reconciliation_DuesAssessCharge,
	   Reconciliation_DuesAssessCharge * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_DuesAssessCharge,
       Reconciliation_AllOtherCharges * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_AllOtherCharges,
	   Reconciliation_AllOtherCharges as LocalCurrency_Reconciliation_AllOtherCharges,
	   Reconciliation_AllOtherCharges * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_AllOtherCharges,
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,
       'Positive = Credit Entry and Negative = Debit Entry' AS PostingInstruction,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MembershipActivationDate   -- EDW 11-2011 QC#8037  
/***************************************/
  FROM #RevenueGLPosting RevGLPost
/********** Foreign Currency Stuff **********/
  JOIN vClub C ON RevGLPost.Posting_MMSClubID = C.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  JOIN #MonthlyPlanRate
       ON VCC.CurrencyCode = #MonthlyPlanRate.FromCurrencyCode
      AND PostDateTime >= #MonthlyPlanRate.FirstOfMonthDate
	  AND Convert(Datetime,Convert(Varchar,PostDateTime,101),101) <= #MonthlyPlanRate.EndOfMonthDate
  JOIN #ToUSDMonthlyPlanRate
       ON VCC.CurrencyCode = #ToUSDMonthlyPlanRate.FromCurrencyCode
      AND PostDateTime >= #ToUSDMonthlyPlanRate.FirstOfMonthDate
	  AND Convert(Datetime,Convert(Varchar,PostDateTime,101),101) <= #ToUSDMonthlyPlanRate.EndOfMonthDate
/*******************************************/

UNION    ---------------------- new with RR 422

SELECT ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate as ItemAmount,
	   ItemAmount as LocalCurrency_ItemAmount,
	   ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_ItemAmount,
       ISNULL((ItemDiscountAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate),0) AS ItemDiscountAmount,
	   ISNULL(ItemDiscountAmount,0) AS LocalCurrency_ItemDiscountAmount,
	   ISNULL((ItemDiscountAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate),0) AS USD_ItemDiscountAmount,
       ISNULL((ItemDiscountAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate),0) as GLPostingAmount,
	   ISNULL(ItemDiscountAmount,0) as LocalCurrency_GLPostingAmount,
	   ISNULL((ItemDiscountAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate),0) as USD_GLPostingAmount,
       DeptDescription,
       ProductDescription,
       MembershipClubName,
       DrawerActivityID,
       PostDateTime as PostDateTime_Sort,
	   Replace(Substring(convert(varchar,PostDateTime,100),1,6)+', '+Substring(convert(varchar,PostDateTime,100),8,10)+' '+Substring(convert(varchar,PostDateTime,100),18,2),'  ',' ') as PostDateTime,
       TranDate,
       ValTranTypeID,
       MemberID,
       0 as ItemSalesTax,
       0 LocalCurrency_ItemSalesTax,
       0 USD_ItemSalesTax,
       EmployeeID,
       MemberFirstName,
       MemberLastName,
       TranItemId,
       TranMemberJoinDate,
       MembershipID,
       ValGLGroupID,
       DiscountGLAccount as GLAccountNumber,
       GLSubAccountNumber,
       GLOverRideClubID,
       ProductID,
       GLGroupIDDescription,
       C.GLTaxID,
       C.GLClubID Posting_GLClubID,
       VR.Description Posting_RegionDescription,
       C.ClubName Posting_ClubName,
       Posting_MMSClubID,
       EmployeeFirstName,
       EmployeeLastName,
       TransactionDescrption,
       TranTypeDescription,
       Case
         WHEN Adj_ValGroupID_Desc LIKE '%- Refund%'
              THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund')
         ELSE Adj_ValGroupID_Desc + ' - Discount'
         END Reconciliation_Adj_ValGroupID_Desc,
       Reconcilation_Sales * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconcilation_Sales,
	   Reconcilation_Sales as LocalCurrency_Reconcilation_Sales,
	   Reconcilation_Sales * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconcilation_Sales,
       Reconciliation_Adjustment * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_Adjustment,
	   Reconciliation_Adjustment as LocalCurrency_Reconciliation_Adjustment,
	   Reconciliation_Adjustment * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_Adjustment,
       Reconciliation_Refund * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_Refund,
	   Reconciliation_Refund as LocalCurrency_Reconciliation_Refund,
	   Reconciliation_Refund * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_Refund,
       Reconciliation_DuesAssessCharge * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_DuesAssessCharge,
	   Reconciliation_DuesAssessCharge as LocalCurrency_Reconciliation_DuesAssessCharge,
	   Reconciliation_DuesAssessCharge * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_DuesAssessCharge,
       Reconciliation_AllOtherCharges * #MonthlyPlanRate.MonthlyAverageExchangeRate as Reconciliation_AllOtherCharges,
	   Reconciliation_AllOtherCharges as LocalCurrency_Reconciliation_AllOtherCharges,
	   Reconciliation_AllOtherCharges * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate as USD_Reconciliation_AllOtherCharges,
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       CASE 
         WHEN Adj_ValGroupID_Desc LIKE '%- Refund%'
              THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund') + COALESCE(DiscountGLAccount, 'NULL') + GLSubAccountNumber  
         ELSE Adj_ValGroupID_Desc + '- Discount' + COALESCE(DiscountGLAccount, 'NULL') + GLSubAccountNumber
         End Reconciliation_ReportLineGrouping,
       DiscountGLAccount as Reconciliation_Adj_GLAccountNumber,
	'Positive = Debit Entry and Negative = Credit Entry' AS PostingInstruction,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MembershipActivationDate  -- EDW 11-2011 QC#8037  
  FROM #RevenueGLPosting RevGLPost
/********** Foreign Currency Stuff **********/
  JOIN vClub C ON RevGLPost.Posting_MMSClubID = C.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  JOIN #MonthlyPlanRate
       ON VCC.CurrencyCode = #MonthlyPlanRate.FromCurrencyCode
      AND PostDateTime >= #MonthlyPlanRate.FirstOfMonthDate
	  AND Convert(Datetime,Convert(Varchar,PostDateTime,101),101) <= #MonthlyPlanRate.EndOfMonthDate
  JOIN #ToUSDMonthlyPlanRate
       ON VCC.CurrencyCode = #ToUSDMonthlyPlanRate.FromCurrencyCode
      AND PostDateTime >= #ToUSDMonthlyPlanRate.FirstOfMonthDate
	  AND Convert(Datetime,Convert(Varchar,PostDateTime,101),101) <= #ToUSDMonthlyPlanRate.EndOfMonthDate
/*******************************************/
  Where ItemDiscountAmount <> 0
    AND ItemDiscountAmount Is Not Null
Order by Posting_GLClubID, Adj_ValGroupID_Desc

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

DROP TABLE #tmpList
DROP TABLE #RefundTranIDs 
DROP TABLE #ReportRefunds 
DROP TABLE #RevenueGLPosting

END

